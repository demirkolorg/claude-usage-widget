# Claude Usage Taskbar
# Gorev cubugunun sol bosluguna yaslanan ozet rozet; tiklayinca ustunde detay paneli acilir.

param(
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $script:Root 'UsageCore.ps1')

$script:RefreshSeconds = [double]$script:AppConfig.refreshSeconds

# ---- Konsol penceresini gizle ----
Add-Type -Namespace Native -Name Win -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]   public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")]   public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
'@
if (-not $SelfTest) {
    $consoleHwnd = [Native.Win]::GetConsoleWindow()
    if ($consoleHwnd -ne [IntPtr]::Zero) { [void][Native.Win]::ShowWindow($consoleHwnd, 0) }
}

# ---- Rozet (pill) penceresi ----
$pillXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Claude Usage Pill" SizeToContent="WidthAndHeight"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize" ShowActivated="False">
  <Border x:Name="Pill" CornerRadius="10" Background="#F01B1D22"
          BorderBrush="#2EFFFFFF" BorderThickness="1" Padding="14,7,14,8" Cursor="Hand">
    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
      <TextBlock Text="&#x2733;" Foreground="#DA7756" FontSize="14" Margin="0,0,10,0" VerticalAlignment="Center"/>
      <TextBlock x:Name="SessionLbl" FontSize="12.5" Foreground="#9AA0AA" VerticalAlignment="Center" Margin="0,0,6,0"/>
      <TextBlock x:Name="SessionPct" Text="&#8230;" FontSize="14" FontWeight="SemiBold" Foreground="#F2F3F5" VerticalAlignment="Center"/>
      <TextBlock x:Name="ClockGlyph" FontFamily="Segoe MDL2 Assets" Text="&#xE823;" FontSize="11.5"
                 Foreground="#8A8F98" VerticalAlignment="Center" Margin="10,1,5,0" Visibility="Collapsed"/>
      <TextBlock x:Name="SessionResetTxt" FontSize="12.5" Foreground="#B9BEC7" VerticalAlignment="Center" Visibility="Collapsed"/>
      <Border Width="1" Height="15" Background="#30FFFFFF" Margin="12,1,12,0" VerticalAlignment="Center"/>
      <TextBlock x:Name="WeekLbl" FontSize="12.5" Foreground="#9AA0AA" VerticalAlignment="Center" Margin="0,0,6,0"/>
      <TextBlock x:Name="WeekPct" Text="&#8230;" FontSize="14" FontWeight="SemiBold" Foreground="#F2F3F5" VerticalAlignment="Center"/>
    </StackPanel>
  </Border>
</Window>
'@

# ---- Detay paneli ----
$panelXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Claude Usage Panel" Width="440" SizeToContent="Height"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize">
  <Border CornerRadius="16" Background="#F81B1D22"
          BorderBrush="#2EFFFFFF" BorderThickness="1" Padding="22,18,22,14">
    <StackPanel>
      <Grid Margin="0,0,0,4">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock Text="Claude Code" FontSize="17" FontWeight="SemiBold" Foreground="#F2F3F5"/>
          <Border x:Name="PlanBadge" Background="#2E3138" CornerRadius="5"
                  Padding="8,2,8,3" Margin="10,0,0,0" VerticalAlignment="Center" Visibility="Collapsed">
            <TextBlock x:Name="PlanText" FontSize="11" FontWeight="SemiBold" Foreground="#B9BEC7"/>
          </Border>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
          <TextBlock x:Name="BtnRefresh" Text="&#x21bb;" FontSize="17" Foreground="#9AA0AA"
                     Cursor="Hand" Margin="0,0,14,0"/>
          <TextBlock x:Name="BtnHide" Text="&#x2715;" FontSize="14" Foreground="#9AA0AA"
                     Cursor="Hand" VerticalAlignment="Center"/>
        </StackPanel>
      </Grid>
      <TextBlock x:Name="SubtitleText" FontSize="11.5" Foreground="#9AA0AA" Margin="0,0,0,14"/>
      <StackPanel x:Name="Rows"/>
      <TextBlock x:Name="StatusText" FontSize="11" Foreground="#6B7078" Margin="2,4,0,0"/>
    </StackPanel>
  </Border>
</Window>
'@

$script:PillWin  = [Windows.Markup.XamlReader]::Parse($pillXaml)
$script:Panel    = [Windows.Markup.XamlReader]::Parse($panelXaml)
$script:SessionLbl = $script:PillWin.FindName('SessionLbl')
$script:SessionPct = $script:PillWin.FindName('SessionPct')
$script:ClockGlyph = $script:PillWin.FindName('ClockGlyph')
$script:SessionResetTxt = $script:PillWin.FindName('SessionResetTxt')
$script:WeekLbl    = $script:PillWin.FindName('WeekLbl')
$script:WeekPct    = $script:PillWin.FindName('WeekPct')
$script:PillBorder = $script:PillWin.FindName('Pill')

$script:SessionLbl.Text = $script:Loc.PillSession
$script:WeekLbl.Text = $script:Loc.PillWeek
$script:RowsPanel  = $script:Panel.FindName('Rows')
$script:StatusText = $script:Panel.FindName('StatusText')
$script:PlanBadge  = $script:Panel.FindName('PlanBadge')
$script:PlanText   = $script:Panel.FindName('PlanText')
$btnRefresh        = $script:Panel.FindName('BtnRefresh')
$btnHide           = $script:Panel.FindName('BtnHide')

$script:Panel.FindName('SubtitleText').Text = $script:Loc.UsageLimits
$btnRefresh.ToolTip = $script:Loc.Refresh
$btnHide.ToolTip = $script:Loc.HidePanel

$script:Exiting = $false
$script:PanelLastHidden = [DateTime]::MinValue
$script:HasData = $false
$script:BackoffUntil = [DateTime]::MinValue

# ---- Konumlama ----
function Set-PillPosition {
    $wa = [System.Windows.SystemParameters]::WorkArea
    $screenH = [System.Windows.SystemParameters]::PrimaryScreenHeight
    $taskbarH = $screenH - $wa.Bottom
    $script:PillWin.Left = $wa.Left + 12
    if ($taskbarH -gt 10 -and $script:PillWin.ActualHeight -gt 0) {
        # Gorev cubugu banti icinde dikey ortala
        $script:PillWin.Top = $wa.Bottom + (($taskbarH - $script:PillWin.ActualHeight) / 2)
    } else {
        # Gorev cubugu altta degil / gizli: sol alt koseye yasla
        $script:PillWin.Top = $wa.Bottom - $script:PillWin.ActualHeight - 8
    }
}

function Set-PanelPosition {
    $wa = [System.Windows.SystemParameters]::WorkArea
    $script:Panel.Left = $wa.Left + 12
    $h = $script:Panel.ActualHeight
    if ($h -le 0) { $h = 380 }
    $script:Panel.Top = $wa.Bottom - $h - 10
}

# ---- Veri guncelleme ----
function Update-All([switch]$Force) {
    # 429 sonrasi bekleme penceresi; elle yenileme (Force) yine de dener
    if (-not $Force -and [DateTime]::Now -lt $script:BackoffUntil) { return }
    try {
        $data = Get-UsageData
        $rows = @(Get-LimitRows $data)

        # Rozet ozeti: oturum + haftalik (tum modeller)
        $session = $rows | Where-Object { $_.Kind -eq 'session' } | Select-Object -First 1
        $weekly  = $rows | Where-Object { $_.Kind -eq 'weekly_all' } | Select-Object -First 1
        if (-not $weekly) { $weekly = $rows | Where-Object { $_.Group -eq 'weekly' } | Select-Object -First 1 }

        if ($session) {
            $script:SessionPct.Text = Format-Pct ([math]::Round($session.Percent))
            $script:SessionPct.Foreground = Get-Brush (Get-FillColor $session.Percent $session.Severity)
            $rs = Format-ResetShort $session.ResetsAt
            if ($rs) {
                $script:SessionResetTxt.Text = $rs
                $script:SessionResetTxt.Visibility = [System.Windows.Visibility]::Visible
                $script:ClockGlyph.Visibility = [System.Windows.Visibility]::Visible
            } else {
                $script:SessionResetTxt.Visibility = [System.Windows.Visibility]::Collapsed
                $script:ClockGlyph.Visibility = [System.Windows.Visibility]::Collapsed
            }
        } else {
            $script:SessionPct.Text = '?'
            $script:SessionResetTxt.Visibility = [System.Windows.Visibility]::Collapsed
            $script:ClockGlyph.Visibility = [System.Windows.Visibility]::Collapsed
        }
        if ($weekly) {
            $script:WeekPct.Text = Format-Pct ([math]::Round($weekly.Percent))
            $script:WeekPct.Foreground = Get-Brush (Get-FillColor $weekly.Percent $weekly.Severity)
        } else {
            $script:WeekPct.Text = '?'
        }

        $tip = ($rows | ForEach-Object { "$($_.Title): $(Format-Pct ([math]::Round($_.Percent))) · $(Format-ResetText $_.ResetsAt $_.Group)" }) -join "`n"
        $script:PillBorder.ToolTip = $tip

        # Panel satirlari
        $script:RowsPanel.Children.Clear()
        foreach ($r in $rows) { [void]$script:RowsPanel.Children.Add((New-UsageRowElement $r -Large)) }
        $script:StatusText.Text = "$($script:Loc.Updated): $((Get-Date).ToString('HH:mm:ss'))"
        $script:StatusText.Foreground = Get-Brush '#6B7078'
        $script:HasData = $true
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match '429') {
            $msg = $script:Loc.Err429
            # Elimizde hic veri yoksa kisa araliklarla dene, veri varsa uzun bekle
            $mins = 5
            if (-not $script:HasData) { $mins = 1 }
            $script:BackoffUntil = [DateTime]::Now.AddMinutes($mins)
        }
        # On transient errors keep the last good pill data; only surface in the status line
        if (-not $script:HasData) {
            $script:SessionPct.Text = '—'
            $script:SessionPct.Foreground = Get-Brush $script:Colors.FillCritical
            $script:SessionResetTxt.Visibility = [System.Windows.Visibility]::Collapsed
            $script:ClockGlyph.Visibility = [System.Windows.Visibility]::Collapsed
            $script:WeekPct.Text = '—'
            $script:WeekPct.Foreground = Get-Brush $script:Colors.FillCritical
            $script:PillBorder.ToolTip = $msg
        }
        $script:StatusText.Text = "$($script:Loc.ErrorLbl): $msg"
        $script:StatusText.Foreground = Get-Brush $script:Colors.FillCritical
    }
}

# ---- Panel ac/kapa ----
function Show-Panel {
    Set-PanelPosition
    $script:Panel.Show()
    Set-PanelPosition
    [void]$script:Panel.Activate()
}

function Switch-Panel {
    if ($script:Panel.IsVisible) {
        $script:Panel.Hide()
        return
    }
    # Panel az once disari tiklanarak kapandiysa ayni tik yeniden acmasin
    if (([DateTime]::Now - $script:PanelLastHidden).TotalMilliseconds -lt 300) { return }
    Show-Panel
}

$script:PillWin.Add_MouseLeftButtonDown({ param($s, $e) $e.Handled = $true; Switch-Panel })

$script:Panel.Add_Deactivated({
    $script:PanelLastHidden = [DateTime]::Now
    $script:Panel.Hide()
})
$script:Panel.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Escape) { $script:Panel.Hide() }
})
$script:Panel.Add_Closing({
    param($s, $e)
    if (-not $script:Exiting) { $e.Cancel = $true; $script:Panel.Hide() }
})
$script:Panel.Add_SizeChanged({ Set-PanelPosition })

$btnHide.Add_MouseLeftButtonDown({ param($s, $e) $e.Handled = $true; $script:Panel.Hide() })
$btnRefresh.Add_MouseLeftButtonDown({ param($s, $e) $e.Handled = $true; Update-All -Force })

function Exit-App {
    $script:Exiting = $true
    try { $script:Panel.Close() } catch { }
    try { $script:PillWin.Close() } catch { }
}

# Rozet sag tik menusu
$menu = New-Object System.Windows.Controls.ContextMenu
$miRefresh = New-Object System.Windows.Controls.MenuItem
$miRefresh.Header = $script:Loc.Refresh
$miRefresh.Add_Click({ Update-All -Force })
$miExit = New-Object System.Windows.Controls.MenuItem
$miExit.Header = $script:Loc.Quit
$miExit.Add_Click({ Exit-App })
[void]$menu.Items.Add($miRefresh)
[void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))
[void]$menu.Items.Add($miExit)
$script:PillWin.ContextMenu = $menu

# ---- Plan rozeti ----
$plan = Get-PlanLabel
if ($plan) {
    $script:PlanText.Text = $plan
    $script:PlanBadge.Visibility = [System.Windows.Visibility]::Visible
}

# ---- Rozeti gorev cubugunun ustunde tut ----
# Gorev cubugu da topmost oldugu icin tiklamalarda rozeti gomebilir; periyodik olarak one cek.
$HWND_TOPMOST = [IntPtr]::new(-1)
$SWP_FLAGS = [uint32]0x0013  # NOSIZE | NOMOVE | NOACTIVATE
function Assert-Topmost {
    try {
        $helper = New-Object System.Windows.Interop.WindowInteropHelper($script:PillWin)
        if ($helper.Handle -ne [IntPtr]::Zero) {
            [void][Native.Win]::SetWindowPos($helper.Handle, $HWND_TOPMOST, 0, 0, 0, 0, $SWP_FLAGS)
        }
    } catch { }
}

$script:PillWin.Add_Loaded({ Set-PillPosition; Assert-Topmost })
$script:PillWin.Add_SizeChanged({ Set-PillPosition })

# ---- Zamanlayicilar ----
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds($script:RefreshSeconds)
$timer.Add_Tick({ Update-All })

$zTimer = New-Object System.Windows.Threading.DispatcherTimer
$zTimer.Interval = [TimeSpan]::FromSeconds(3)
$zTimer.Add_Tick({ Assert-Topmost; Set-PillPosition })

if ($SelfTest) {
    Write-Host 'SelfTest: veri cekiliyor...'
    Update-All
    Write-Host "SelfTest: rozet = '$($script:SessionLbl.Text) $($script:SessionPct.Text) | $($script:SessionResetTxt.Text) | $($script:WeekLbl.Text) $($script:WeekPct.Text)'"
    Write-Host "SelfTest: panel satir sayisi = $($script:RowsPanel.Children.Count), durum = $($script:StatusText.Text)"
    Write-Host 'SelfTest: OK'
    exit 0
}

Update-All
$timer.Start()
$zTimer.Start()
[void]$script:PillWin.ShowDialog()
