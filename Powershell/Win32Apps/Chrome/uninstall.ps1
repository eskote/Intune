# Chrome Uninstall script

$applicationName = "Chrome"
$logDirectory = "C:\ProgramData\0riongpgIntuneLogs"
$chromePath = "C:\Program Files\Google\$applicationName\Application\chrome.exe"
$UninstallPath = "C:\Program Files\Google\$applicationName\Application\$currentVersion\Installer\setup.exe"
$logFile   = Join-Path -Path $logDirectory -ChildPath "$ApplicationName.log"

# Ensure log directory exists
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
}

# Write Log Function
function Write-ApplicationLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level
    )

    # Timestamp and prefix for the new entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) {
        'INFO'  { 'INFO ' }
        'WARN'  { 'WARN ' }
        'ERROR' { 'ERROR' }
    }
    $logEntry = "[$timestamp] $prefix $Message"

    # Write the actual log entry
    Add-Content -Path $logFile -Value $logEntry
}

$currentVersion = ((Get-ItemProperty -Path $chromePath).VersionInfo).FileVersion
Write-ApplicationLog -Message "Current $applicationName version is $currentVersion." -Level INFO

if (Test-Path -Path $UninstallPath) {
    Write-ApplicationLog -Message "$applicationName.exe path exists. Script will now attempt to uninstall." -Level INFO
}
Write-ApplicationLog -Message "$applicationName version $currentVersion is currently installed on $env:COMPUTERNAME." -Level INFO

try {
    & $UninstallPath--uninstall --system-level --force-uninstall
}
catch {
    Write-ApplicationLog -Message "Script was unable to attempt $applicationName uninstallation. Try again." -Level ERROR
    exit 1
}

Write-ApplicationLog -Message "$applicationName uninstall script appeared to be successful. Detection script will verify." -Level INFO
exit 0