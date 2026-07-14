# Generates README screenshots into assets/ by rendering the WPF visuals
# offscreen with sample data (no API calls). Run:
#   powershell -STA -File tools\make-screenshots.ps1

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:Root = $repo
. (Join-Path $repo 'UsageCore.ps1')

$assets = Join-Path $repo 'assets'
if (-not (Test-Path $assets)) { New-Item -ItemType Directory -Path $assets | Out-Null }

function Save-Png($element, [string]$path, [double]$width, [double]$scale = 2) {
    $element.Measure((New-Object System.Windows.Size($width, [double]::PositiveInfinity)))
    $h = $element.DesiredSize.Height
    $element.Arrange((New-Object System.Windows.Rect(0, 0, $width, $h)))
    $element.UpdateLayout()
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(
        [int]([math]::Ceiling($width * $scale)), [int]([math]::Ceiling($h * $scale)),
        (96 * $scale), (96 * $scale), [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($element)
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [IO.File]::Create($path)
    $enc.Save($fs)
    $fs.Close()
    Write-Host "Saved: $path"
}

function New-Backdrop($child, [double]$pad = 28) {
    $bg = New-Object System.Windows.Controls.Border
    $bg.Background = Get-Brush '#0D0F13'
    $bg.Padding = New-Object System.Windows.Thickness($pad)
    $bg.Child = $child
    return $bg
}

function New-SampleRows {
    $nextFriday = (Get-Date).Date.AddHours(11)
    while ($nextFriday.DayOfWeek -ne [DayOfWeek]::Friday -or $nextFriday -lt (Get-Date)) { $nextFriday = $nextFriday.AddDays(1) }
    @(
        [pscustomobject]@{ Title = $script:L.SessionTitle; Percent = 37; ResetsAt = (Get-Date).AddMinutes(84).ToString('o'); Group = 'session'; Kind = 'session'; Severity = 'normal' }
        [pscustomobject]@{ Title = $script:L.WeeklyAll; Percent = 8; ResetsAt = $nextFriday.ToString('o'); Group = 'weekly'; Kind = 'weekly_all'; Severity = 'normal' }
        [pscustomobject]@{ Title = ($script:L.WeeklyModel -f 'Fable'); Percent = 8; ResetsAt = $nextFriday.ToString('o'); Group = 'weekly'; Kind = 'weekly_scoped'; Severity = 'normal' }
    )
}

function New-Badge([string]$text, [double]$fontSize, [double]$radius) {
    $b = New-Object System.Windows.Controls.Border
    $b.Background = Get-Brush '#2E3138'
    $b.CornerRadius = New-Object System.Windows.CornerRadius($radius)
    $b.Padding = New-Object System.Windows.Thickness(8, 2, 8, 3)
    $b.Margin = New-Object System.Windows.Thickness(10, 0, 0, 0)
    $b.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $b.Child = New-Text $text $fontSize '#B9BEC7' 'SemiBold'
    return $b
}

function New-HeaderGrid([double]$titleSize, [double]$badgeSize) {
    $g = New-Object System.Windows.Controls.Grid
    $left = New-Object System.Windows.Controls.StackPanel
    $left.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    [void]$left.Children.Add((New-Text 'Claude Code' $titleSize $script:Colors.TextPrimary 'SemiBold'))
    [void]$left.Children.Add((New-Badge 'Max 20x' $badgeSize 5))
    $right = New-Object System.Windows.Controls.StackPanel
    $right.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $right.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    $right.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $r = New-Text ([char]0x21bb) ($titleSize) '#9AA0AA' 'Normal'
    $r.Margin = New-Object System.Windows.Thickness(0, 0, 14, 0)
    $x = New-Text ([char]0x2715) ($titleSize - 3) '#9AA0AA' 'Normal'
    [void]$right.Children.Add($r)
    [void]$right.Children.Add($x)
    [void]$g.Children.Add($left)
    [void]$g.Children.Add($right)
    return $g
}

function New-PanelVisual {
    $card = New-Object System.Windows.Controls.Border
    $card.CornerRadius = New-Object System.Windows.CornerRadius(16)
    $card.Background = Get-Brush '#F81B1D22'
    $card.BorderBrush = Get-Brush '#2EFFFFFF'
    $card.BorderThickness = New-Object System.Windows.Thickness(1)
    $card.Padding = New-Object System.Windows.Thickness(22, 18, 22, 14)

    $sp = New-Object System.Windows.Controls.StackPanel
    $head = New-HeaderGrid 17 11
    $head.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)
    [void]$sp.Children.Add($head)
    $sub = New-Text $script:L.UsageLimits 11.5 $script:Colors.TextSecondary 'Normal'
    $sub.Margin = New-Object System.Windows.Thickness(0, 0, 0, 14)
    [void]$sp.Children.Add($sub)
    foreach ($r in (New-SampleRows)) { [void]$sp.Children.Add((New-UsageRowElement $r -Large)) }
    [void]$sp.Children.Add((New-Text "$($script:L.Updated): 09:41:07" 11 '#6B7078' 'Normal'))
    $card.Child = $sp
    return $card
}

function New-WidgetVisual {
    $card = New-Object System.Windows.Controls.Border
    $card.CornerRadius = New-Object System.Windows.CornerRadius(14)
    $card.Background = Get-Brush '#F21B1D22'
    $card.BorderBrush = Get-Brush '#2EFFFFFF'
    $card.BorderThickness = New-Object System.Windows.Thickness(1)
    $card.Padding = New-Object System.Windows.Thickness(18, 14, 18, 10)

    $sp = New-Object System.Windows.Controls.StackPanel
    $head = New-HeaderGrid 14 10
    $head.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)
    [void]$sp.Children.Add($head)
    foreach ($r in (New-SampleRows)) { [void]$sp.Children.Add((New-UsageRowElement $r)) }
    [void]$sp.Children.Add((New-Text "$($script:L.Updated): 09:41:07" 10 '#6B7078' 'Normal'))
    $card.Child = $sp
    return $card
}

function New-PillVisual {
    $pill = New-Object System.Windows.Controls.Border
    $pill.CornerRadius = New-Object System.Windows.CornerRadius(10)
    $pill.Background = Get-Brush '#F01B1D22'
    $pill.BorderBrush = Get-Brush '#2EFFFFFF'
    $pill.BorderThickness = New-Object System.Windows.Thickness(1)
    $pill.Padding = New-Object System.Windows.Thickness(14, 7, 14, 8)
    $pill.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $star = New-Text ([char]0x2733) 14 $script:Colors.Accent 'Normal'
    $star.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
    [void]$sp.Children.Add($star)

    $sLbl = New-Text $script:L.PillSession 12.5 '#9AA0AA' 'Normal'
    $sLbl.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
    [void]$sp.Children.Add($sLbl)
    [void]$sp.Children.Add((New-Text (Format-Pct 37) 14 $script:Colors.FillNormal 'SemiBold'))

    $clock = New-Text ([char]0xE823) 11.5 '#8A8F98' 'Normal'
    $clock.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe MDL2 Assets')
    $clock.Margin = New-Object System.Windows.Thickness(10, 1, 5, 0)
    $clock.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    [void]$sp.Children.Add($clock)
    [void]$sp.Children.Add((New-Text (Format-ResetShort ((Get-Date).AddMinutes(84).ToString('o'))) 12.5 '#B9BEC7' 'Normal'))

    $div = New-Object System.Windows.Controls.Border
    $div.Width = 1
    $div.Height = 15
    $div.Background = Get-Brush '#30FFFFFF'
    $div.Margin = New-Object System.Windows.Thickness(12, 1, 12, 0)
    $div.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    [void]$sp.Children.Add($div)

    $wLbl = New-Text $script:L.PillWeek 12.5 '#9AA0AA' 'Normal'
    $wLbl.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
    [void]$sp.Children.Add($wLbl)
    [void]$sp.Children.Add((New-Text (Format-Pct 8) 14 $script:Colors.FillNormal 'SemiBold'))

    foreach ($child in $sp.Children) {
        if ($child -is [System.Windows.Controls.TextBlock]) { $child.VerticalAlignment = [System.Windows.VerticalAlignment]::Center }
    }
    $pill.Child = $sp
    return $pill
}

# Wide promo card (for social/Reddit posts and the repo social preview)
function New-PromoVisual([string]$lang) {
    $grid = New-Object System.Windows.Controls.Grid
    $colLeft = New-Object System.Windows.Controls.ColumnDefinition
    $colLeft.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $colRight = New-Object System.Windows.Controls.ColumnDefinition
    $colRight.Width = [System.Windows.GridLength]::Auto
    [void]$grid.ColumnDefinitions.Add($colLeft)
    [void]$grid.ColumnDefinitions.Add($colRight)

    $left = New-Object System.Windows.Controls.StackPanel
    $left.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $left.Margin = New-Object System.Windows.Thickness(0, 0, 36, 0)

    $title = New-Text 'Claude Usage Widget' 30 $script:Colors.TextPrimary 'SemiBold'
    if ($lang -eq 'tr') {
        $subText = "Claude Code oturum ve haftalık limitleriniz" + [Environment]::NewLine + "her zaman görev çubuğunuzda"
        $bullets = @("Saf PowerShell + WPF — sıfır bağımlılık", "Tek satırla kurulum", "Veri yalnızca Anthropic API'sinden", "Açık kaynak · MIT")
    } else {
        $subText = 'Your Claude Code session & weekly limits' + [Environment]::NewLine + 'always visible in your Windows taskbar'
        $bullets = @('Pure PowerShell + WPF - zero dependencies', 'One-liner install', 'Talks only to the Anthropic API', 'Open source - MIT')
    }
    $sub = New-Text $subText 14.5 $script:Colors.TextSecondary 'Normal'
    $sub.Margin = New-Object System.Windows.Thickness(0, 8, 0, 22)

    [void]$left.Children.Add($title)
    [void]$left.Children.Add($sub)
    [void]$left.Children.Add((New-PillVisual))
    $spacer = New-Object System.Windows.Controls.Border
    $spacer.Height = 22
    [void]$left.Children.Add($spacer)
    foreach ($b in $bullets) {
        $line = New-Text ("$([char]0x2713)  $b") 13 '#B9BEC7' 'Normal'
        $line.Margin = New-Object System.Windows.Thickness(0, 0, 0, 7)
        [void]$left.Children.Add($line)
    }

    $panel = New-PanelVisual
    $panel.Width = 440
    [System.Windows.Controls.Grid]::SetColumn($panel, 1)

    [void]$grid.Children.Add($left)
    [void]$grid.Children.Add($panel)
    return $grid
}

foreach ($lang in @('en', 'tr')) {
    Set-UsageLanguage $lang
    Save-Png (New-Backdrop (New-PanelVisual)) (Join-Path $assets "panel-$lang.png") (440 + 56)
    Save-Png (New-Backdrop (New-WidgetVisual) 24) (Join-Path $assets "widget-$lang.png") (330 + 48)
    Save-Png (New-Backdrop (New-PillVisual) 16) (Join-Path $assets "pill-$lang.png") 430
    Save-Png (New-Backdrop (New-PromoVisual $lang) 44) (Join-Path $assets "promo-$lang.png") 980
}
Write-Host 'All screenshots generated.'
