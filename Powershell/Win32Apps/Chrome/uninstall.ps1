# Chrome Uninstall script
function UninstallChrome {
    param (
        [Parameter(Mandatory = $false)]
        [string]$ApplicationName = "Chrome",

        [Parameter(Mandatory = $false)]
        [string]$ChromePath = "C:\Program Files\Google\$ApplicationName\Application\$ApplicationName.exe",

        [Parameter(Mandatory = $true)]
        [string]$OrganizationName,

        [Parameter(Mandatory = $false)]
        [string]$LogDirectory = "C:\ProgramData\$($OrganizationName)IntuneLogs",

        [Parameter(Mandatory = $false)]
        [string]$LogFile = "$LogDirectory\$ApplicationName.log",

        [Parameter(Mandatory = $false)]
        [int]$MaxSizeMB = 10
    )

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
        if (-not (Test-Path -Path $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        }
    
        # === Size check: If current log is too big, delete it ===
        $LogDeleted = $false
        if (Test-Path -Path $LogFile) {
            $FileSizeMB = (Get-Item -Path $LogFile).Length / 1MB
            if ($FileSizeMB -gt $MaxSizeMB) {
                Remove-Item -Path $LogFile -Force
                $LogDeleted = $true
            }
        }
    
        # Optional: Add a note if we just deleted the oversized log
        if ($LogDeleted) {
            $DeleteMessage = "[$Timestamp] INFO  Previous log file deleted because it exceeded $MaxSizeMB MB. Starting fresh log."
            Add-Content -Path $LogFile -Value $DeleteMessage
        }
    
        # Timestamp and prefix for the new entry
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $Prefix = switch ($Level) {
            'INFO' { 'INFO ' }
            'WARN' { 'WARN ' }
            'ERROR' { 'ERROR' }
        }
        $LogEntry = "[$Timestamp] $Prefix $Message"
    
        # Write the actual log entry
        Add-Content -Path $LogFile -Value $LogEntry
    }
    
    $CurrentVersion = ((Get-ItemProperty -Path $ChromePath).VersionInfo).FileVersion
    $UninstallPath = "C:\Program Files\Google\$ApplicationName\Application\$CurrentVersion\Installer\setup.exe"

    if (Test-Path -Path $UninstallPath) {
        Write-ApplicationLog -Message "$ApplicationName.exe path exists. Script will now attempt to uninstall." -Level INFO
    }
    Write-ApplicationLog -Message "$ApplicationName version $CurrentVersion is currently installed on $env:COMPUTERNAME." -Level INFO
    
    try {
        & $UninstallPath --uninstall --system-level --force-uninstall
    }
    catch {
        Write-ApplicationLog -Message "Script was unable to attempt $ApplicationName uninstallation. Try again." -Level ERROR
        exit 1
    }
    
    Write-ApplicationLog -Message "$ApplicationName uninstall script appeared to be successful." -Level INFO
    exit 0
}