# Chrome Install Script - Force Clean + Reinstall
$ApplicationName = "Chrome"
$downloadURL = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"  # Consistent direct URL
$logDirectory = "C:\ProgramData\0riongpgIntuneLogs"
$msiPath = Join-Path $logDirectory "GoogleChromeStandaloneEnterprise64.msi"
$logFile = Join-Path $logDirectory "$ApplicationName.log"

# Write Log Function
function Write-ApplicationLog {
    param (
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)][ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) { 'INFO' { 'INFO ' } 'WARN' { 'WARN ' } 'ERROR' { 'ERROR' } }
    $logEntry = "[$timestamp] $prefix $Message"
    Add-Content -Path $logFile -Value $logEntry
}

Write-ApplicationLog -Message "Starting forceful $ApplicationName cleanup and reinstall." -Level INFO

# Kill Chrome/Google processes
Get-Process -Name "chrome","google*update*" -ErrorAction SilentlyContinue | Stop-Process -Force

# Uninstall via MSI product code (if detected)
$productCode = "{CB0DD49F-5FA4-3FF9-B44A-FCC7A19D2687}"
if (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq $productCode -or $_.DisplayName -like "*Google Chrome*" }) {
    Write-ApplicationLog -Message "Uninstalling existing Chrome via msiexec /x" -Level INFO
    Start-Process msiexec.exe -ArgumentList "/x $productCode /qn /norestart" -Wait
}

# Force-remove Chrome folders
Remove-Item -Path "C:\Program Files\Google\Chrome" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Program Files (x86)\Google\Chrome" -Recurse -Force -ErrorAction SilentlyContinue

# Clean per-user Chrome (loop profiles)
Get-ChildItem "C:\Users" -Directory | ForEach-Object {
    $userChrome = "$($_.FullName)\AppData\Local\Google\Chrome"
    if (Test-Path $userChrome) {
        Remove-Item $userChrome -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Critical: Remove Windows Installer registry artifacts for Chrome
$installerPaths = @(
    "HKLM:\SOFTWARE\Classes\Installer\Products\*",
    "HKLM:\SOFTWARE\Classes\Installer\Features\*",
    "HKLM:\SOFTWARE\Classes\Installer\UpgradeCodes\*",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\*",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
foreach ($path in $installerPaths) {
    Get-ChildItem $path -ErrorAction SilentlyContinue | Where-Object { $_.GetValue("ProductName") -like "*Google Chrome*" -or $_.PSChildName -match "CB0DD49F" } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# Optional: Clean Google Update keys (can block installs)
Remove-Item -Path "HKLM:\SOFTWARE\Google\Update" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "HKLM:\SOFTWARE\WOW6432Node\Google\Update" -Recurse -Force -ErrorAction SilentlyContinue

# Download
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Write-ApplicationLog -Message "Downloading $ApplicationName from $downloadURL..." -Level INFO
    Invoke-WebRequest -Uri $downloadURL -OutFile $msiPath -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" -UseBasicParsing
    
    if ((Get-Item $msiPath).Length -lt 100MB) {
        throw "Downloaded file is too small (<100MB) - likely failed or corrupted."
    }
    Write-ApplicationLog -Message "Download successful ($((Get-Item $msiPath).Length / 1MB) MB)." -Level INFO
}
catch {
    Write-ApplicationLog -Message "Download failed: $($_.Exception.Message)" -Level ERROR
    exit 1
}

# Install
try {
    Write-ApplicationLog -Message "Installing fresh Chrome with ALLUSERS=1..." -Level INFO
    $installLog = Join-Path $logDirectory "$ApplicationName-install.log"
    $arguments = "/i `"$msiPath`" /qn /norestart ALLUSERS=1 NOGOOGLEUPDATEPING=1 /L*v `"$installLog`""
    $process = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -notin 0,3010) { throw "Exit code $($process.ExitCode)" }
    Write-ApplicationLog -Message "Installed successfully (exit $($process.ExitCode))." -Level INFO
} catch {
    Write-ApplicationLog -Message "Install failed: $($_.Exception.Message)" -Level ERROR
    exit 1
}

# Cleanup MSI
Remove-Item $msiPath -Force
exit 0