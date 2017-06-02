
#region Description

# Configure Hyper-V Host
# ----------------------
#  - Create a scheduled task to start ISE automatically
#  - Copy Files (Base VHDs, ISOs, PowerShell Modules)
#  - Create PowerShell Profiles
#  - Install Hyper-V Role
#  - Create Virtual Switches
#  - Import VM "R1"
#  - Edit Hosts File for Name Resolution
#  - Edit Trusted Hosts List

#endregion

#region Variables

$Lab             = "PWS"
$LabDir          = "D:\Labs\PWS"
$LabSwitch       = "PWS"

#endregion

#region Create scheduled task to start ISE at logon

# Old style
# ---------
# cmd  (as administrator)
# echo start %windir%\system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe > %HOMEPATH%\Documents\StartISE.bat
# schtasks /CREATE /SC ONLOGON /TN "Start PowerShell ISE at logon" /TR %HOMEPATH%\Documents\StartISE.bat /RL HIGHEST

# New style
# ----------
$TaskName    = "Start Powershell ISE for $env:USERNAME"
$AtLogon     = New-ScheduledTaskTrigger -AtLogOn
$StartIse    = New-ScheduledTaskAction -Execute PowerShell_ISE.exe
$CurrentUser = New-ScheduledTaskPrincipal -RunLevel Highest -LogonType Interactive -UserId $env:USERNAME

Register-ScheduledTask -TaskName $TaskName -TaskPath "\" -Trigger $AtLogon -Action $StartIse -Principal $CurrentUser

#endregion

#region Copy Base files

Get-Volume
New-SmbMapping -LocalPath T: -RemotePath "\\10.1.7.12\Transfer"
$SourceDir = "T:\Base"
$DestDir   = "D:\Base"
New-Item -ItemType Directory -Path $DestDir -Force
Copy-Item -Path $SourceDir\Base-WS2016_1607_withDesktopExperience_en_GPT_v0.3.vhdx -Destination $DestDir

#endregion

#region Copy Iso files

$SourceDir = "T:\iso"
$DestDir   = "D:\iso"
New-Item -ItemType Directory -Path $DestDir -Force
Copy-Item -Path $SourceDir\14393.0.160715-1616.RS1_RELEASE_SERVER_EVAL_X64FRE_EN-US.ISO -Destination $DestDir

#endregion

#region Download custom PowerShell module "tjLabs"

Register-PSRepository -Name MyGet -SourceLocation https://www.myget.org/F/tj/api/v2/
Get-PSRepository
Install-Module -Name tjLabs -MinimumVersion 0.2.6.5 -Repository MyGet

#endregion

#region Create PowerShell profiles

New-Item -ItemType File -Path $profile.CurrentUserAllHosts -Force | Out-Null

Write-Output '[string]$Lab          = "PWS"'                                                              > $profile.CurrentUserAllHosts
Write-Output '[string]$LabDrive     = "D:"'                                                              >> $profile.CurrentUserAllHosts
Write-Output '[string]$LabDir       = "D:\Labs\PWS"'                                                     >> $profile.CurrentUserAllHosts
Write-Output '[string]$LabSwitch    = "PWS"'                                                             >> $profile.CurrentUserAllHosts
Write-Output '[string]$LabBaseGen1  = "D:\Base\vyos-999.201612310331-amd64.vhd"'                         >> $profile.CurrentUserAllHosts
Write-Output '[string]$LabBaseGen2  = "D:\Base\Base-WS2016_1607_withDesktopExperience_en_GPT_v0.3.vhdx"' >> $profile.CurrentUserAllHosts
Write-Output '[long]  $LabMem       = 4GB'                                                               >> $profile.CurrentUserAllHosts
Write-Output '[long]  $LabCpuCount  = 4'                                                                 >> $profile.CurrentUserAllHosts
Write-Output '#------------------------------------------'                                               >> $profile.CurrentUserAllHosts
Write-Output 'Write-Output  "This is PowerShell $($PSVersionTable.PSVersion)`n"'                         >> $profile.CurrentUserAllHosts
Write-Output ''                                                                                          >> $profile.CurrentUserAllHosts
Write-Output 'Write-Output "Loading module tjLabs..."'                                                   >> $profile.CurrentUserAllHosts
Write-Output 'Import-Module -Name tjLabs -WarningAction SilentlyContinue '                               >> $profile.CurrentUserAllHosts
Write-Output 'Get-Module -Name tjLabs | ft Name,Version'                                                 >> $profile.CurrentUserAllHosts
Write-Output ''                                                                                          >> $profile.CurrentUserAllHosts
Write-Output 'if (Test-Path $LabDir) {cd $LabDir}'                                                       >> $profile.CurrentUserAllHosts
Write-Output 'if(Get-Command Get-VM -ea SilentlyContinue) {"Current Lab is $Lab."; Show-Lab}'            >> $profile.CurrentUserAllHosts
Write-Output 'function prompt {"$Lab> "}'                                                                >> $profile.CurrentUserAllHosts

# Current Host is ISE
New-Item -ItemType File -Path $profile.CurrentUserCurrentHost -Force | Out-Null
Write-Output '$psISE.Options.Zoom = 120' > $profile.CurrentUserCurrentHost

#endregion

#region Create Folders

New-Item -ItemType Directory -Path $LabDir

#endregion

#region Install Hyper-V

Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart

#endregion 

#region Configure Hyper-V

Set-VMHost -EnableEnhancedSessionMode $true
Set-VMHost -VirtualMachinePath $LabDir
Set-VMHost -VirtualHardDiskPath $LabDir

#endregion

#region Create Virtual Switches

$NIC = Get-NetAdapter -Physical | ? Status -eq "Up"
New-VMSwitch -Name "External Network" -NetAdapterName $NIC.Name

New-VMSwitch -Name $LabSwitch -SwitchType Internal
$idx = Get-NetAdapter  | where Name -Like *$LabSwitch* | % InterfaceIndex

New-NetIPAddress -InterfaceIndex $idx -IPAddress "10.70.0.200" -PrefixLength "16"


#endregion

#region Import VM R1

$SourceDir = "T:\VMs\PWS-R1"
$DestDir   = $LabDir
if (!(Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir }
Copy-Item $SourceDir -Destination $DestDir -Recurse
$R1 = "$DestDir\PWS-R1\Virtual Machines\C94694C2-2D3C-4975-A6B4-ED8D90677D55.vmcx"
Compare-VM -Path $R1
Import-VM -Path $R1

#endregion

#region Edit etc/hosts

$etc = "C:\WINDOWS\system32\drivers\etc\hosts"
Add-Content -Path $etc -Value "`r"
Add-Content -Path $etc -Value "10.70.0.1    R1"
Add-Content -Path $etc -Value "10.70.0.10   DC1"
Add-Content -Path $etc -Value "10.70.0.21   SVR1"
Add-Content -Path $etc -Value "10.70.17.1   NANO1"
Add-Content -Path $etc -Value "10.70.17.2   NANO2"
Add-Content -Path $etc -Value "10.70.17.3   NANO3"
Add-Content -Path $etc -Value "10.70.17.4   NANO4"
Clear-DnsClientCache

#endregion

#region Edit TrustedHosts

$TrustedHosts = "WSMan:\localhost\Client\TrustedHosts"
Set-Item  $TrustedHosts -Value '*' -Force

#endregion
