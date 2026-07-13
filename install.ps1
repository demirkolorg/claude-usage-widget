# Claude Usage Widget - installer
#
# Remote (one-liner):
#   irm https://raw.githubusercontent.com/demirkolorg/claude-usage-widget/main/install.ps1 | iex
#
# Local (from a cloned repo):
#   .\install.ps1                    install taskbar pill + add to startup + start
#   .\install.ps1 -Mode widget       install the floating card instead
#   .\install.ps1 -Mode both         install both
#   .\install.ps1 -NoStartup         do not add to Windows startup
#   .\install.ps1 -NoStart           do not start now
#   .\install.ps1 -Uninstall         remove shortcuts, stop processes, delete installed files
#
# Remote with options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/demirkolorg/claude-usage-widget/main/install.ps1))) -Mode widget

param(
    [ValidateSet('taskbar', 'widget', 'both')]
    [string]$Mode = 'taskbar',
    [switch]$NoStartup,
    [switch]$NoStart,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoOwner = 'demirkolorg'
$RepoName  = 'claude-usage-widget'
$Branch    = 'main'

$DefaultInstallDir = Join-Path $env:LOCALAPPDATA 'ClaudeUsageWidget'
$StartupDir = [Environment]::GetFolderPath('Startup')
$Shortcuts = @{ taskbar = 'Claude Usage Taskbar.lnk'; widget = 'Claude Usage Widget.lnk' }
$Launchers = @{ taskbar = 'StartTaskbar.vbs'; widget = 'StartWidget.vbs' }

function Stop-RunningInstances {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'ClaudeUsage(Taskbar|Widget)\.ps1' -and $_.ProcessId -ne $PID } |
        ForEach-Object {
            try { Stop-Process -Id $_.ProcessId -Force -Confirm:$false } catch { }
        }
}

if ($Uninstall) {
    foreach ($lnk in $Shortcuts.Values) {
        $p = Join-Path $StartupDir $lnk
        if (Test-Path $p) { Remove-Item $p -Force; Write-Host "Removed: $p" }
    }
    Stop-RunningInstances
    if (Test-Path $DefaultInstallDir) {
        try {
            Remove-Item $DefaultInstallDir -Recurse -Force
            Write-Host "Removed: $DefaultInstallDir"
        } catch {
            Write-Host "Could not remove $DefaultInstallDir - delete it manually."
        }
    }
    Write-Host 'Uninstalled.'
    return
}

# Local mode: running next to the repo files. Remote mode: download the repo zip.
$localRoot = $null
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'UsageCore.ps1'))) { $localRoot = $PSScriptRoot }

if ($localRoot) {
    $TargetDir = $localRoot
    Write-Host "Using local files: $TargetDir"
} else {
    $TargetDir = $DefaultInstallDir
    Write-Host "Downloading $RepoOwner/$RepoName ($Branch)..."
    $zipUrl = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/$Branch.zip"
    $tmpZip = Join-Path $env:TEMP "$RepoName-$Branch.zip"
    $tmpDir = Join-Path $env:TEMP "$RepoName-extract"
    Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing
    if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
    Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force
    $srcDir = Join-Path $tmpDir "$RepoName-$Branch"
    if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir | Out-Null }
    Copy-Item -Path (Join-Path $srcDir '*') -Destination $TargetDir -Recurse -Force
    Remove-Item $tmpZip -Force
    Remove-Item $tmpDir -Recurse -Force
    Write-Host "Installed to: $TargetDir"
}

$modes = if ($Mode -eq 'both') { @('taskbar', 'widget') } else { @($Mode) }

if (-not $NoStartup) {
    $ws = New-Object -ComObject WScript.Shell
    foreach ($m in $modes) {
        $lnkPath = Join-Path $StartupDir $Shortcuts[$m]
        $lnk = $ws.CreateShortcut($lnkPath)
        $lnk.TargetPath = 'wscript.exe'
        $lnk.Arguments = '"' + (Join-Path $TargetDir $Launchers[$m]) + '"'
        $lnk.WorkingDirectory = $TargetDir
        $lnk.Description = 'Claude Code usage limits indicator'
        $lnk.Save()
        Write-Host "Startup shortcut: $lnkPath"
    }
}

if (-not $NoStart) {
    Stop-RunningInstances
    foreach ($m in $modes) {
        Start-Process wscript.exe -ArgumentList ('"' + (Join-Path $TargetDir $Launchers[$m]) + '"')
    }
    Write-Host 'Started.'
}

Write-Host 'Done. Right-click the pill / card for options (refresh, quit).'
