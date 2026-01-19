# Chrome Install Script - Force Clean + Reinstall
function InstallChrome {
    param (
        [Parameter(Mandatory = $false)]
        [string]$ApplicationName = "Chrome",

        [Parameter(Mandatory = $false)]
        [string]$DownloadURL = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi",

        [Parameter(Mandatory = $true)]
        [string]$OrganizationName,

        [Parameter(Mandatory = $false)]
        [string]$LogDirectory = "C:\ProgramData\$($OrganizationName)IntuneLogs",

        [Parameter(Mandatory = $false)]
        [string]$LogFile = "$LogDirectory\$ApplicationName.log",

        [Parameter(Mandatory = $false)]
        [int]$MaxSizeMB = 10
    )

    $MsiPath = Join-Path $LogDirectory "GoogleChromeStandaloneEnterprise64.msi"

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
    
    # Critical: Remove Windows Installer registry artifacts for Chrome
    $InstallerPaths = @(
        "HKLM:\SOFTWARE\Classes\Installer\Products\*",
        "HKLM:\SOFTWARE\Classes\Installer\Features\*",
        "HKLM:\SOFTWARE\Classes\Installer\UpgradeCodes\*",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\*",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($Path in $InstallerPaths) {
        Get-ChildItem $Path -ErrorAction SilentlyContinue | Where-Object { $_.GetValue("ProductName") -like "*Google Chrome*" -or $_.PSChildName -match "CB0DD49F" } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Optional: Clean Google Update keys (can block installs)
    Remove-Item -Path "HKLM:\SOFTWARE\Google\Update" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "HKLM:\SOFTWARE\WOW6432Node\Google\Update" -Recurse -Force -ErrorAction SilentlyContinue
    
    # Download
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    try {
        Write-ApplicationLog -Message "Downloading $ApplicationName from $DownloadURL..." -Level INFO
        Invoke-WebRequest -Uri $DownloadURL -OutFile $MsiPath -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" -UseBasicParsing
        
        if ((Get-Item $MsiPath).Length -lt 100MB) {
            throw "Downloaded file is too small (<100MB) - likely failed or corrupted."
        }
        Write-ApplicationLog -Message "Download successful ($((Get-Item $MsiPath).Length / 1MB) MB)." -Level INFO
    }
    catch {
        Write-ApplicationLog -Message "Download failed: $($_.Exception.Message)" -Level ERROR
        exit 1
    }
    
    # Install
    try {
        Write-ApplicationLog -Message "Installing fresh Chrome with ALLUSERS=1..." -Level INFO
        $InstallLog = Join-Path $LogDirectory "$ApplicationName-install.log"
        $Arguments = "/i `"$MsiPath`" /qn /norestart ALLUSERS=1 NOGOOGLEUPDATEPING=1 /L*v `"$InstallLog`""
        $Process = Start-Process msiexec.exe -ArgumentList $Arguments -Wait -PassThru
        if ($Process.ExitCode -notin 0,3010) { throw "Exit code $($Process.ExitCode)" }
        Write-ApplicationLog -Message "Installed successfully (exit $($Process.ExitCode))." -Level INFO
    } catch {
        Write-ApplicationLog -Message "Install failed: $($_.Exception.Message)" -Level ERROR
        exit 1
    }
    
    # Cleanup MSI
    Remove-Item $MsiPath -Force
    exit 0
}