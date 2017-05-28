# Windows version
# ---------------
function GetWinVer {
  $version    = Get-CimInstance -ClassName Win32_OperatingSystem | % version
  $Major      = $version.split(".")[0]
  $Minor      = $version.split(".")[1]
  $BuildLabEx = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\' | % BuildLabEx
  $Build      = $BuildLabEx.split(".")[0]
  $Revision   = $BuildLabEx.split(".")[1]
  echo "$Major.$Minor.$Build.$Revision" }
GetWinVer


# Updates installed?
# ------------------
$ci = New-CimInstance -Namespace root/Microsoft/Windows/WindowsUpdate -ClassName MSFT_WUOperationsSession
$Result = Invoke-CimMethod -InputObject $ci -MethodName ScanForUpdates -Arguments @{SearchCriteria="IsInstalled=1";OnlineScan=$true}
$Result.Updates.Title


# Hyper-V installed?
# ------------------
Get-WindowsOptionalFeature -Online | ft FeatureName,State
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V 


# Enough space on volume?
# ------------------------
Get-Volume | ? DriveLetter -eq "C" |
  ft @{n="Size (GB)";     e={[math]::Round($_.size/1gb,1)}},`
     @{n="Size remaining";e={[math]::Round($_.sizeremaining/1gb,1)}}


# PackageProvider installed?
# --------------------------
Get-PackageProvider -ListAvailable -Name DockerMsftProvider


# Docker running?
# ---------------
Get-Service -Name Docker
docker version

# Docker images?
# --------------
docker images
docker pull microsoft/nanoserver
