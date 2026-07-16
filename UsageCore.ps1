# UsageCore.ps1 - Shared data layer + UI helpers for the widget and taskbar apps.
# Consumers set $script:Root, then dot-source this file:  . "$root\UsageCore.ps1"

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:CredPath = Join-Path $env:USERPROFILE '.claude\.credentials.json'
$script:UsageUrl = 'https://api.anthropic.com/api/oauth/usage'

# ---- App config (optional config.json next to the scripts) ----
$script:AppConfig = @{
    language       = 'auto'   # auto | tr | en
    refreshSeconds = 60
}
if ($script:Root) {
    $cfgPath = Join-Path $script:Root 'config.json'
    if (Test-Path $cfgPath) {
        try {
            $saved = Get-Content $cfgPath -Raw | ConvertFrom-Json
            foreach ($k in @('language', 'refreshSeconds')) {
                if ($saved.PSObject.Properties.Name -contains $k -and $saved.$k) {
                    $script:AppConfig[$k] = $saved.$k
                }
            }
        } catch { }
    }
}

# ---- Localization ----
$script:Strings = @{
    tr = @{
        SessionTitle   = 'Mevcut oturum'
        WeeklyAll      = "Haftalık · tüm modeller"
        WeeklyModel    = "Haftalık · {0}"
        WeeklyGeneric  = "Haftalık · model"
        PctFmt         = '%{0}'
        UsedWord       = "kullanıldı"
        UsedFmt        = "%{0} kullanıldı"
        LeftFmt        = "%{0} kaldı"
        ResetSessionH  = "Sıfırlanma: {0} sa {1} dk"
        ResetSessionM  = "Sıfırlanma: {0} dk"
        ResetShortH    = "{0} sa {1} dk"
        ResetShortM    = "{0} dk"
        ResetWeekly    = "Sıfırlanma: {0} {1}"
        ResetWeeklyToday    = "Sıfırlanma: bugün {0}"
        ResetWeeklyTomorrow = "Sıfırlanma: yarın {0}"
        Updated        = "Güncellendi"
        ErrorLbl       = 'Hata'
        UsageLimits    = "Kullanım limitleri"
        PillSession    = 'Oturum'
        PillWeek       = 'Hafta'
        Refresh        = 'Yenile'
        Quit           = 'Kapat'
        HidePanel      = 'Paneli gizle'
        AlwaysOnTop    = "Her zaman üstte"
        NoData         = "Limit verisi bulunamadı."
        Err401         = "Token geçersiz (401). Claude Code'u bir kez çalıştırın, token yenilensin."
        Err429         = "Hız sınırı (429) — sonraki yenilemede tekrar denenecek."
        ErrNoCred      = "Kimlik dosyası bulunamadı: {0}. Claude Code'a giriş yapın (claude login)."
        ErrNoToken     = "Claude Code OAuth token bulunamadı."
        Days           = @{ Monday = 'Pzt'; Tuesday = 'Sal'; Wednesday = "Çar"; Thursday = 'Per'; Friday = 'Cum'; Saturday = 'Cmt'; Sunday = 'Paz' }
    }
    en = @{
        SessionTitle   = 'Current session'
        WeeklyAll      = "Weekly · all models"
        WeeklyModel    = "Weekly · {0}"
        WeeklyGeneric  = "Weekly · model"
        PctFmt         = '{0}%'
        UsedWord       = 'used'
        UsedFmt        = '{0}% used'
        LeftFmt        = '{0}% left'
        ResetSessionH  = 'Resets in {0}h {1}m'
        ResetSessionM  = 'Resets in {0}m'
        ResetShortH    = '{0}h {1}m'
        ResetShortM    = '{0}m'
        ResetWeekly    = 'Resets {0} {1}'
        ResetWeeklyToday    = 'Resets today {0}'
        ResetWeeklyTomorrow = 'Resets tomorrow {0}'
        Updated        = 'Updated'
        ErrorLbl       = 'Error'
        UsageLimits    = 'Usage limits'
        PillSession    = 'Session'
        PillWeek       = 'Week'
        Refresh        = 'Refresh'
        Quit           = 'Quit'
        HidePanel      = 'Hide panel'
        AlwaysOnTop    = 'Always on top'
        NoData         = 'No limit data found.'
        Err401         = 'Token invalid (401). Run any claude command once to refresh it.'
        Err429         = 'Rate limited (429) — will retry on the next refresh.'
        ErrNoCred      = 'Credentials file not found: {0}. Log in to Claude Code first (claude login).'
        ErrNoToken     = 'Claude Code OAuth token not found.'
        Days           = @{ Monday = 'Mon'; Tuesday = 'Tue'; Wednesday = 'Wed'; Thursday = 'Thu'; Friday = 'Fri'; Saturday = 'Sat'; Sunday = 'Sun' }
    }
}

function Resolve-UsageLanguage([string]$pref) {
    if ($pref -eq 'tr' -or $pref -eq 'en') { return $pref }
    if ([System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'tr') { return 'tr' }
    return 'en'
}

function Set-UsageLanguage([string]$lang) {
    $script:Lang = Resolve-UsageLanguage $lang
    $script:Loc = $script:Strings[$script:Lang]
}
Set-UsageLanguage "$($script:AppConfig.language)"

function Format-Pct([int]$n) { $script:Loc.PctFmt -f $n }

# ---- Colors ----
$script:Colors = @{
    TextPrimary   = '#F2F3F5'
    TextSecondary = '#9AA0AA'
    Track         = '#2C3038'
    FillNormal    = '#4C8DFF'
    FillWarning   = '#F5A524'
    FillCritical  = '#F0554A'
    Accent        = '#DA7756'
}
$script:BrushConv = New-Object System.Windows.Media.BrushConverter
function Get-Brush([string]$hex) { $script:BrushConv.ConvertFromString($hex) }

# ---- Data layer ----
function Get-AccessToken {
    if (-not (Test-Path $script:CredPath)) {
        throw ($script:Loc.ErrNoCred -f $script:CredPath)
    }
    $creds = Get-Content $script:CredPath -Raw | ConvertFrom-Json
    if (-not $creds.claudeAiOauth -or -not $creds.claudeAiOauth.accessToken) {
        throw $script:Loc.ErrNoToken
    }
    return $creds.claudeAiOauth
}

function Get-PlanLabel {
    try {
        $oauth = Get-AccessToken
        $tier = "$($oauth.rateLimitTier)"
        if ($tier -match '(\d+)x') { return "Max $($Matches[1])x" }
        $sub = "$($oauth.subscriptionType)"
        if ($sub) { return $sub.Substring(0,1).ToUpper() + $sub.Substring(1) }
    } catch { }
    return ''
}

function Get-UsageData {
    $oauth = Get-AccessToken
    $headers = @{
        'Authorization'  = "Bearer $($oauth.accessToken)"
        'anthropic-beta' = 'oauth-2025-04-20'
    }
    try {
        return Invoke-RestMethod -Uri $script:UsageUrl -Headers $headers -Method Get -TimeoutSec 15
    } catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        if ($status -eq 401) { throw $script:Loc.Err401 }
        throw
    }
}

# Normalize the limits array; fall back to five_hour/seven_day fields when absent
function Get-LimitRows($data) {
    $rows = @()
    $limits = @()
    if ($data.PSObject.Properties.Name -contains 'limits' -and $data.limits) { $limits = @($data.limits) }

    if ($limits.Count -gt 0) {
        foreach ($l in $limits) {
            $title = switch ($l.kind) {
                'session'       { $script:Loc.SessionTitle }
                'weekly_all'    { $script:Loc.WeeklyAll }
                'weekly_scoped' {
                    $model = ''
                    if ($l.scope -and $l.scope.model) { $model = "$($l.scope.model.display_name)" }
                    if ($model) { $script:Loc.WeeklyModel -f $model } else { $script:Loc.WeeklyGeneric }
                }
                default         { "$($l.kind)" }
            }
            $rows += [pscustomobject]@{
                Title    = $title
                Percent  = [math]::Max(0, [math]::Min(100, [double]$l.percent))
                ResetsAt = $l.resets_at
                Group    = "$($l.group)"
                Kind     = "$($l.kind)"
                Severity = "$($l.severity)"
            }
        }
    } else {
        if ($data.five_hour) {
            $rows += [pscustomobject]@{
                Title = $script:Loc.SessionTitle; Percent = [math]::Round([double]$data.five_hour.utilization)
                ResetsAt = $data.five_hour.resets_at; Group = 'session'; Kind = 'session'; Severity = 'normal'
            }
        }
        if ($data.seven_day) {
            $rows += [pscustomobject]@{
                Title = $script:Loc.WeeklyAll; Percent = [math]::Round([double]$data.seven_day.utilization)
                ResetsAt = $data.seven_day.resets_at; Group = 'weekly'; Kind = 'weekly_all'; Severity = 'normal'
            }
        }
    }
    return $rows
}

function Format-ResetText([string]$resetsAt, [string]$group) {
    if (-not $resetsAt) { return '' }
    try {
        $local = [DateTimeOffset]::Parse($resetsAt).ToLocalTime()
    } catch { return '' }

    if ($group -eq 'session') {
        $ts = $local - [DateTimeOffset]::Now
        if ($ts.TotalSeconds -lt 0) { $ts = [TimeSpan]::Zero }
        $h = [math]::Floor($ts.TotalHours)
        if ($h -ge 1) { return $script:Loc.ResetSessionH -f $h, $ts.Minutes }
        return $script:Loc.ResetSessionM -f $ts.Minutes
    }

    # Bugun/yarin ise gun adi yerine acikca soyle — "Cum 11:00" karisikligini onler
    $daysAway = ($local.Date - (Get-Date).Date).Days
    if ($daysAway -le 0) { return $script:Loc.ResetWeeklyToday -f $local.ToString('HH:mm') }
    if ($daysAway -eq 1) { return $script:Loc.ResetWeeklyTomorrow -f $local.ToString('HH:mm') }
    $day = $script:Loc.Days["$($local.DayOfWeek)"]
    return $script:Loc.ResetWeekly -f $day, $local.ToString('HH:mm')
}

# Rozet gibi dar alanlar icin kompakt geri sayim: "1 sa 12 dk" / "1h 12m"
function Format-ResetShort([string]$resetsAt) {
    if (-not $resetsAt) { return '' }
    try {
        $local = [DateTimeOffset]::Parse($resetsAt).ToLocalTime()
    } catch { return '' }
    $ts = $local - [DateTimeOffset]::Now
    if ($ts.TotalSeconds -lt 0) { $ts = [TimeSpan]::Zero }
    $h = [math]::Floor($ts.TotalHours)
    if ($h -ge 1) { return $script:Loc.ResetShortH -f $h, $ts.Minutes }
    return $script:Loc.ResetShortM -f $ts.Minutes
}

function Get-FillColor([double]$percent, [string]$severity) {
    if ($percent -ge 90 -or $severity -match 'exceeded|critical|error') { return $script:Colors.FillCritical }
    if ($percent -ge 70 -or $severity -match 'warning|elevated')        { return $script:Colors.FillWarning }
    return $script:Colors.FillNormal
}

function New-Text([string]$text, [double]$size, [string]$color, [string]$weight) {
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $text
    $tb.FontSize = $size
    $tb.Foreground = Get-Brush $color
    if ($weight -eq 'SemiBold') { $tb.FontWeight = [System.Windows.FontWeights]::SemiBold }
    return $tb
}

# Visual block for a single limit row (title + bar + reset/left)
# -Large: wide variant for the flyout panel (sub-card, big percent, thicker bar)
function New-UsageRowElement($row, [switch]$Large) {
    $pct = [math]::Round($row.Percent)
    $fillColor = Get-FillColor $row.Percent $row.Severity

    if ($Large) {
        $titleSize = 13.5; $footSize = 11.5; $barHeight = 10; $barRadius = 5
        $barMargin = New-Object System.Windows.Thickness(0, 12, 0, 8)
    } else {
        $titleSize = 12.5; $footSize = 11; $barHeight = 8; $barRadius = 4
        $barMargin = New-Object System.Windows.Thickness(0, 6, 0, 5)
    }

    $inner = New-Object System.Windows.Controls.StackPanel

    $head = New-Object System.Windows.Controls.Grid
    $titleTb = New-Text $row.Title $titleSize $script:Colors.TextPrimary 'SemiBold'
    if ($Large) {
        $titleTb.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        $pctStack = New-Object System.Windows.Controls.StackPanel
        $pctStack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
        $pctTb = New-Text (Format-Pct $pct) 22 $fillColor 'SemiBold'
        $pctTb.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
        $capTb = New-Text $script:Loc.UsedWord 10 $script:Colors.TextSecondary 'Normal'
        $capTb.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
        $capTb.Margin = New-Object System.Windows.Thickness(0, -2, 0, 0)
        [void]$pctStack.Children.Add($pctTb)
        [void]$pctStack.Children.Add($capTb)
        $usedEl = $pctStack
    } else {
        $usedEl = New-Text ($script:Loc.UsedFmt -f $pct) 12 $script:Colors.TextSecondary 'Normal'
        $usedEl.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    }
    [void]$head.Children.Add($titleTb)
    [void]$head.Children.Add($usedEl)

    $track = New-Object System.Windows.Controls.Border
    $track.Height = $barHeight
    $track.CornerRadius = New-Object System.Windows.CornerRadius($barRadius)
    $track.Background = Get-Brush $script:Colors.Track
    $track.Margin = $barMargin

    $barGrid = New-Object System.Windows.Controls.Grid
    $colFill = New-Object System.Windows.Controls.ColumnDefinition
    $colFill.Width = New-Object System.Windows.GridLength($pct, [System.Windows.GridUnitType]::Star)
    $colRest = New-Object System.Windows.Controls.ColumnDefinition
    $colRest.Width = New-Object System.Windows.GridLength((100 - $pct), [System.Windows.GridUnitType]::Star)
    [void]$barGrid.ColumnDefinitions.Add($colFill)
    [void]$barGrid.ColumnDefinitions.Add($colRest)

    if ($pct -gt 0) {
        $fill = New-Object System.Windows.Controls.Border
        $fill.CornerRadius = New-Object System.Windows.CornerRadius($barRadius)
        $fill.Background = Get-Brush $fillColor
        [System.Windows.Controls.Grid]::SetColumn($fill, 0)
        [void]$barGrid.Children.Add($fill)
    }
    $track.Child = $barGrid

    $foot = New-Object System.Windows.Controls.Grid
    $resetTb = New-Text (Format-ResetText $row.ResetsAt $row.Group) $footSize $script:Colors.TextSecondary 'Normal'
    $leftTb = New-Text ($script:Loc.LeftFmt -f [math]::Round(100 - $pct)) $footSize $script:Colors.TextSecondary 'Normal'
    $leftTb.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    [void]$foot.Children.Add($resetTb)
    [void]$foot.Children.Add($leftTb)

    [void]$inner.Children.Add($head)
    [void]$inner.Children.Add($track)
    [void]$inner.Children.Add($foot)

    if ($Large) {
        $card = New-Object System.Windows.Controls.Border
        $card.Background = Get-Brush '#0FFFFFFF'
        $card.CornerRadius = New-Object System.Windows.CornerRadius(12)
        $card.Padding = New-Object System.Windows.Thickness(16, 12, 16, 13)
        $card.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
        $card.Child = $inner
        return $card
    }

    $inner.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)
    return $inner
}
