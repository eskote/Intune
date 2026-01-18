# Intune Chrome Detect Script

$ApplicationName = "Chrome"
$exePath = "C:\Program Files\Google\Chrome\Application\Chrome.exe"
$logDirectory = "C:\ProgramData\0riongpgIntuneLogs"
$maxSizeMB = 10
$logFile = Join-Path -Path $logDirectory -ChildPath "$ApplicationName-log.log"

# Write Log Function
function Write-ApplicationLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level
    )

    # Ensure log directory exists
    if (-not (Test-Path -Path $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }

    # === Size check: If current log is too big, delete it ===
    $logDeleted = $false
    if (Test-Path -Path $logFile) {
        $fileSizeMB = (Get-Item -Path $logFile).Length / 1MB
        if ($fileSizeMB -gt $maxSizeMB) {
            Remove-Item -Path $logFile -Force
            $logDeleted = $true
        }
    }

    # Optional: Add a note if we just deleted the oversized log
    if ($logDeleted) {
        $deleteMessage = "[$timestamp] INFO  Previous log file deleted because it exceeded $maxSizeMB MB. Starting fresh log."
        Add-Content -Path $logFile -Value $deleteMessage
    }

    # Timestamp and prefix for the new entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) {
        'INFO' { 'INFO ' }
        'WARN' { 'WARN ' }
        'ERROR' { 'ERROR' }
    }
    $logEntry = "[$timestamp] $prefix $Message"

    # Write the actual log entry
    Add-Content -Path $logFile -Value $logEntry
}

# Begin Script
if (Test-Path -Path $exePath) {
    Write-ApplicationLog -Message "$applicationName is already installed on $env:COMPUTERNAME. Script will now end." -Level INFO
    exit 0
}
else {
    Write-ApplicationLog -Message "$applicationName not detected on $env:COMPUTERNAME. Installation script will now run." -Level WARN
    exit 1
}