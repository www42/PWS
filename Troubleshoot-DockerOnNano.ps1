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


# Enough space on volume?
# ------------------------
get-volume | 
  ft @{n="Size (GB)";     e={[math]::Round($_.size/1gb,1)}},`
     @{n="Size remaining";e={[math]::Round($_.sizeremaining/1gb,1)}}


# PackageProvider installed?
Get-PackageProvider -ListAvailable -Name DockerMsftProvider


# Docker running?
Get-Service -Name Docker
docker version

# And now .....
docker images
docker pull microsoft/nanoserver

# [PWS-NANO4]: PS C:\> docker pull microsoft/nanoserver
# Using default tag: latest
# latest: Pulling from microsoft/nanoserver
# bce2fbc256ea: Pulling fs layer
# 4a8c367fd46d: Pulling fs layer
# 4a8c367fd46d: Verifying Checksum
# 4a8c367fd46d: Download complete
# bce2fbc256ea: Verifying Checksum
# bce2fbc256ea: Download complete
# 
# docker : failed to register layer: re-exec error: exit status 1: output: ProcessBaseLayer 
# C:\ProgramData\docker\windowsfilter\300134286e88df06998197131155a1f31533114a7977f8926dbd888ca54d9e21: This operation returned because the timeout 
# period expired.
#     + CategoryInfo          : NotSpecified: (failed to regis...period expired.:String) [], RemoteException
#     + FullyQualifiedErrorId : NativeCommandError
#  
# :-((

