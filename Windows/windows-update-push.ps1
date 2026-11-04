<#
.SYNOPSIS
    Report pending Windows and winget updates to an Uptime Kuma push monitor.

.DESCRIPTION
    Counts updates that Windows Update would install (optional updates and
    drivers are left out) and upgrades winget offers from its own source. The
    monitor goes down when updates are waiting or a check fails. A pending
    reboot is shown in the message but does not take the monitor down.

    The monitor's host, port and token are read from -ConfigPath as KEY=VALUE
    lines: PUSH_HOST, PUSH_PORT and PUSH_TOKEN.

.PARAMETER ConfigPath
    The settings file. See windows-update-push.conf.

.PARAMETER SkipWinget
    Don't check winget. Use this when running as SYSTEM, where winget doesn't work.

.EXAMPLE
    .\windows-update-push.ps1 -WhatIf

    Do the checks and show the URL without sending it.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $ConfigPath = (Join-Path $env:ProgramData 'windows-update-push.conf'),
    [switch] $SkipWinget
)

$ErrorActionPreference = 'Stop'

# Read KEY=VALUE lines, ignoring comments and blank lines
function Read-Config {
    param([string] $Path)

    $config = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*([A-Za-z_]+)\s*=\s*(.*?)\s*$') {
            $config[$Matches[1]] = $Matches[2]
        }
    }
    foreach ($key in 'PUSH_HOST', 'PUSH_PORT', 'PUSH_TOKEN') {
        if (-not $config[$key]) { throw "$key is not set in $Path" }
    }
    $config
}

function Get-WindowsUpdateCount {
    $searcher = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
    $result = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")
    @($result.Updates | Where-Object { -not $_.BrowseOnly }).Count
}

function Get-WingetUpgradeCount {
    # Only winget's own source: the Microsoft Store source needs its terms
    # accepted, and Store apps update themselves
    $output = & winget upgrade --source winget --disable-interactivity 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "winget exited with $LASTEXITCODE" }

    if ($output -match '(?m)^(\d+) upgrades? available') { return [int] $Matches[1] }
    # A table with no count means the wording changed (another display language,
    # say). Fail rather than report zero.
    if ($output -match '(?m)^-{3,}') { throw 'could not read the winget upgrade count' }
    0
}

$config = Read-Config $ConfigPath
$failed = 0

$windows = 0
try {
    $windows = Get-WindowsUpdateCount
} catch {
    Write-Warning "Windows Update check failed: $_"
    $failed++
}

$winget = 0
if (-not $SkipWinget) {
    try {
        $winget = Get-WingetUpgradeCount
    } catch {
        Write-Warning "winget check failed: $_"
        $failed++
    }
}

$status = if ($windows + $winget + $failed -eq 0) { 'up' } else { 'down' }
$message = "$windows windows, $winget winget, $failed failed"
if ((New-Object -ComObject Microsoft.Update.SystemInfo).RebootRequired) {
    $message += ', reboot pending'
}

$url = 'http://{0}:{1}/api/push/{2}?status={3}&msg={4}' -f $config.PUSH_HOST, $config.PUSH_PORT,
    $config.PUSH_TOKEN, $status, [uri]::EscapeDataString($message)

if ($PSCmdlet.ShouldProcess($url, 'Send')) {
    Invoke-WebRequest -Uri $url -UseBasicParsing | Out-Null
}
