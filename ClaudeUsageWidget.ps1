# Claude Usage Widget
# Claude Code oturum ve haftalik kullanim limitlerini gosteren masaustu karti.

param(
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $script:Root 'UsageCore.ps1')

$script:ConfigPath = Join-Path $script:Root 'widget-config.json'

# ---- Konsol penceresini gizle (dogrudan calistirilirsa) ----
if (-not $SelfTest) {
    Add-Type -Namespace Native -Name Win -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
    $consoleHwnd = [Native.Win]::GetConsoleWindow()
    if ($consoleHwnd -ne [IntPtr]::Zero) { [void][Native.Win]::ShowWindow($consoleHwnd, 0) }
}

# ---- Pencere durumu (konum vb.) ----
$script:Config = @{
    left    = $null
    top     = $null
    topmost = $true
}
if (Test-Path $script:ConfigPath) {
    try {
        $saved = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
        foreach ($k in @('left', 'top', 'topmost')) {
            if ($saved.PSObject.Properties.Name -contains $k -and $null -ne $saved.$k) {
                $script:Config[$k] = $saved.$k
            }
        }
    } catch { }
}

# ---- UI ----
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Claude Usage" Width="330" SizeToContent="Height"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize">
  <Border x:Name="Card" CornerRadius="14" Background="#F21B1D22"
          BorderBrush="#2EFFFFFF" BorderThickness="1" Padding="18,14,18,10">
    <StackPanel>
      <Grid Margin="0,0,0,12">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock Text="Claude Code" FontSize="14" FontWeight="SemiBold" Foreground="#F2F3F5"/>
          <Border x:Name="PlanBadge" Background="#2E3138" CornerRadius="4"
                  Padding="6,1,6,2" Margin="8,0,0,0" VerticalAlignment="Center" Visibility="Collapsed">
            <TextBlock x:Name="PlanText" FontSize="10" FontWeight="SemiBold" Foreground="#B9BEC7"/>
          </Border>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
          <TextBlock x:Name="BtnRefresh" Text="&#x21bb;" FontSize="15" Foreground="#9AA0AA"
                     Cursor="Hand" Margin="0,0,12,0"/>
          <TextBlock x:Name="BtnClose" Text="&#x2715;" FontSize="12" Foreground="#9AA0AA"
                     Cursor="Hand" VerticalAlignment="Center"/>
        </StackPanel>
      </Grid>
      <StackPanel x:Name="Rows"/>
      <TextBlock x:Name="StatusText" FontSize="10" Foreground="#6B7078" Margin="0,2,0,0"/>
    </StackPanel>
  </Border>
</Window>
'@

$script:Window = [Windows.Markup.XamlReader]::Parse($xaml)
$script:RowsPanel  = $script:Window.FindName('Rows')
$script:StatusText = $script:Window.FindName('StatusText')
$script:PlanBadge  = $script:Window.FindName('PlanBadge')
$script:PlanText   = $script:Window.FindName('PlanText')
$btnRefresh        = $script:Window.FindName('BtnRefresh')
$btnClose          = $script:Window.FindName('BtnClose')

$btnRefresh.ToolTip = $script:Loc.Refresh
$btnClose.ToolTip = $script:Loc.Quit

$script:BackoffUntil = [DateTime]::MinValue

function Update-Usage([switch]$Force) {
    # 429 sonrasi bekleme penceresi; elle yenileme (Force) yine de dener
    if (-not $Force -and [DateTime]::Now -lt $script:BackoffUntil) { return }
    try {
        $data = Get-UsageData
        $rows = @(Get-LimitRows $data)
        $script:RowsPanel.Children.Clear()
        if ($rows.Count -eq 0) {
            $script:StatusText.Text = $script:Loc.NoData
            return
        }
        foreach ($r in $rows) { [void]$script:RowsPanel.Children.Add((New-UsageRowElement $r)) }
        $script:StatusText.Text = "$($script:Loc.Updated): $((Get-Date).ToString('HH:mm:ss'))"
        $script:StatusText.Foreground = Get-Brush '#6B7078'
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match '429') {
            $msg = $script:Loc.Err429
            # Elimizde hic veri yoksa kisa araliklarla dene, veri varsa uzun bekle
            $mins = 5
            if ($script:RowsPanel.Children.Count -eq 0) { $mins = 1 }
            $script:BackoffUntil = [DateTime]::Now.AddMinutes($mins)
        }
        $script:StatusText.Text = "$($script:Loc.ErrorLbl): $msg"
        $script:StatusText.Foreground = Get-Brush $script:Colors.FillCritical
    }
}

# ---- Etkilesim ----
$btnClose.Add_MouseLeftButtonDown({ param($s, $e) $e.Handled = $true; $script:Window.Close() })
$btnRefresh.Add_MouseLeftButtonDown({ param($s, $e) $e.Handled = $true; Update-Usage -Force })
$script:Window.Add_MouseLeftButtonDown({ try { $script:Window.DragMove() } catch { } })

# Sag tik menusu
$menu = New-Object System.Windows.Controls.ContextMenu
$miRefresh = New-Object System.Windows.Controls.MenuItem
$miRefresh.Header = $script:Loc.Refresh
$miRefresh.Add_Click({ Update-Usage -Force })
$miTopmost = New-Object System.Windows.Controls.MenuItem
$miTopmost.Header = $script:Loc.AlwaysOnTop
$miTopmost.IsCheckable = $true
$miTopmost.IsChecked = [bool]$script:Config.topmost
$miTopmost.Add_Click({
    $script:Window.Topmost = $miTopmost.IsChecked
    $script:Config.topmost = [bool]$miTopmost.IsChecked
})
$miClose = New-Object System.Windows.Controls.MenuItem
$miClose.Header = $script:Loc.Quit
$miClose.Add_Click({ $script:Window.Close() })
[void]$menu.Items.Add($miRefresh)
[void]$menu.Items.Add($miTopmost)
[void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))
[void]$menu.Items.Add($miClose)
$script:Window.ContextMenu = $menu

# ---- Konum ----
$script:Window.Topmost = [bool]$script:Config.topmost
if ($null -ne $script:Config.left -and $null -ne $script:Config.top) {
    $script:Window.Left = [double]$script:Config.left
    $script:Window.Top  = [double]$script:Config.top
} else {
    $wa = [System.Windows.SystemParameters]::WorkArea
    $script:Window.Left = $wa.Right - 330 - 24
    $script:Window.Top  = $wa.Top + 24
}

$script:Window.Add_Closing({
    try {
        $script:Config.left = $script:Window.Left
        $script:Config.top  = $script:Window.Top
        $script:Config | ConvertTo-Json | Set-Content -Path $script:ConfigPath -Encoding UTF8
    } catch { }
})

# ---- Plan rozeti ----
$plan = Get-PlanLabel
if ($plan) {
    $script:PlanText.Text = $plan
    $script:PlanBadge.Visibility = [System.Windows.Visibility]::Visible
}

# ---- Zamanlayici ----
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds([double]$script:AppConfig.refreshSeconds)
$timer.Add_Tick({ Update-Usage })

if ($SelfTest) {
    Write-Host "SelfTest: veri cekiliyor..."
    $data = Get-UsageData
    $rows = @(Get-LimitRows $data)
    foreach ($r in $rows) {
        Write-Host ("  {0,-28} %{1,-4} {2}" -f $r.Title, [math]::Round($r.Percent), (Format-ResetText $r.ResetsAt $r.Group))
    }
    Update-Usage
    Write-Host "SelfTest: satir sayisi = $($script:RowsPanel.Children.Count), durum = $($script:StatusText.Text)"
    Write-Host 'SelfTest: OK'
    exit 0
}

Update-Usage
$timer.Start()
[void]$script:Window.ShowDialog()
