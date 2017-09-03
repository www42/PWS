
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

$Lab             = "HDP"
$LabDir          = "C:\Labs\HDP"
$LabSwitch       = "HDP"

#endregion

#region Create scheduled task to start ISE at logon

# Old style
# ---------
# cmd  (as administrator)
# echo start %windir%\system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe > %HOMEPATH%\Documents\StartISE.bat
# schtasks /CREATE /SC ONLOGON /TN "Start PowerShell ISE at logon" /TR %HOMEPATH%\Documents\StartISE.bat /RL HIGHEST

# New style
# ----------
#$TaskName    = "Start Powershell ISE for $env:USERNAME"
#$AtLogon     = New-ScheduledTaskTrigger -AtLogOn
#$StartIse    = New-ScheduledTaskAction -Execute PowerShell_ISE.exe
#$CurrentUser = New-ScheduledTaskPrincipal -RunLevel Highest -LogonType Interactive -UserId $env:USERNAME

#Register-ScheduledTask -TaskName $TaskName -TaskPath "\" -Trigger $AtLogon -Action $StartIse -Principal $CurrentUser

#endregion

#region Map Drive T: to Transfer

Get-Volume
New-SmbMapping -LocalPath T: -RemotePath "\\HOST10\Transfer" -UserName Administrator -Password 'Pa$$w0rd' -Persistent:$true

#endregion

#region Copy Base files

$SourceDir = "T:\Base"
$DestDir   = "C:\Base"
New-Item -ItemType Directory -Path $DestDir -Force
Copy-Item -Path $SourceDir\Base-WS2016_1607_withDesktopExperience_DE_GPT_1708.vhdx -Destination $DestDir

#endregion

#region Copy Iso files

$SourceDir = "T:\iso"
$DestDir   = "C:\iso"
New-Item -ItemType Directory -Path $DestDir -Force
Copy-Item -Path $SourceDir\14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_DE-DE.ISO -Destination $DestDir

#endregion

#region Download custom PowerShell module "tjLabs"

#Register-PSRepository -Name MyGet -SourceLocation https://www.myget.org/F/tj/api/v2/
#Get-PSRepository
#Install-Module -Name tjLabs -MinimumVersion 0.2.6.5 -Repository MyGet

#endregion

#region Create PowerShell profiles

New-Item -ItemType File -Path $profile.CurrentUserAllHosts -Force | Out-Null

Write-Output '[string]$Lab          = "HDP"'                                                              > $profile.CurrentUserAllHosts
Write-Output '[string]$LabDrive     = "C:"'                                                              >> $profile.CurrentUserAllHosts
Write-Output '[string]$LabDir       = "C:\Labs\HDP"'                                                     >> $profile.CurrentUserAllHosts
Write-Output '[string]$LabSwitch    = "HDP"'                                                             >> $profile.CurrentUserAllHosts
Write-Output '[string]$LabBaseGen1  = "C:\Base\vyos-999.201612310331-amd64.vhd"'                         >> $profile.CurrentUserAllHosts
Write-Output '[string]$LabBaseGen2  = "C:\Base\Base-WS2016_1607_withDesktopExperience_DE_GPT_1708.vhdx"' >> $profile.CurrentUserAllHosts
Write-Output '[long]  $LabMem       = 4GB'                                                               >> $profile.CurrentUserAllHosts
Write-Output '[long]  $LabCpuCount  = 4'                                                                 >> $profile.CurrentUserAllHosts
Write-Output '#------------------------------------------'                                               >> $profile.CurrentUserAllHosts
Write-Output 'Write-Output  "This is PowerShell $($PSVersionTable.PSVersion)`n"'                         >> $profile.CurrentUserAllHosts
Write-Output ''                                                                                          >> $profile.CurrentUserAllHosts
#Write-Output 'Write-Output "Loading module tjLabs..."'                                                   >> $profile.CurrentUserAllHosts
#Write-Output 'Import-Module -Name tjLabs -WarningAction SilentlyContinue '                               >> $profile.CurrentUserAllHosts
#Write-Output 'Get-Module -Name tjLabs | ft Name,Version'                                                 >> $profile.CurrentUserAllHosts
Write-Output ''                                                                                          >> $profile.CurrentUserAllHosts
Write-Output 'if (Test-Path $LabDir) {cd $LabDir}'                                                       >> $profile.CurrentUserAllHosts
#Write-Output 'if(Get-Command Get-VM -ea SilentlyContinue) {"Current Lab is $Lab."; Show-Lab}'            >> $profile.CurrentUserAllHosts
Write-Output 'function prompt {"$Lab> "}'                                                                >> $profile.CurrentUserAllHosts

# Current Host is ISE
New-Item -ItemType File -Path $profile.CurrentUserCurrentHost -Force | Out-Null
Write-Output '$psISE.Options.Zoom = 120' > $profile.CurrentUserCurrentHost

#endregion

#region Create Lab Folder

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
New-VMSwitch -Name "External Network" -NetAdapterName $NIC.Name | Out-Null

New-VMSwitch -Name $LabSwitch -SwitchType Internal | Out-Null
$idx = Get-NetAdapter  | where Name -Like *$LabSwitch* | % InterfaceIndex

New-NetIPAddress -InterfaceIndex $idx -IPAddress "10.80.0.200" -PrefixLength "16" | Out-Null

Get-VMSwitch
Get-NetIPConfiguration | ft InterfaceAlias,IPv4Address

#endregion

#region Edit etc/hosts

$etc = "C:\WINDOWS\system32\drivers\etc\hosts"
Add-Content -Path $etc -Value "`r"
Add-Content -Path $etc -Value "10.80.0.1    R1"
Add-Content -Path $etc -Value "10.80.0.10   DC1"
Add-Content -Path $etc -Value "10.80.0.21   SVR1"
Add-Content -Path $etc -Value "10.80.0.22   SVR2"
Add-Content -Path $etc -Value "10.80.0.23   SVR3"
Clear-DnsClientCache

#endregion

#region Edit TrustedHosts

$TrustedHosts = "WSMan:\localhost\Client\TrustedHosts"
Set-Item  $TrustedHosts -Value '*' -Force

#endregion

#region misc

# Services
    Set-Service -Name MapsBroker -StartupType Disabled
    Set-Service -Name Audiosrv -StartupType Automatic
    Start-Service -Name Audiosrv

# Enhanced IE Security
    $ESCAdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $ESCUserKey  = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $ESCAdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $ESCUserKey  -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer -ErrorAction SilentlyContinue

# IE Start Page
    $IeStartPageKey = 'HKCU:\Software\Microsoft\Internet Explorer\Main\'
    $Name = 'Start Page'
    $Url = 'https://google.de'
    Set-ItemProperty -Path $IeStartPageKey -Name $Name -Value $Url
    (Get-ItemProperty -Path $IeStartPageKey -Name $Name).$Name

#endregion

#region Import VMs

$SourceDir = "T:\Labs\HDP"
$DestDir   = $LabDir
if (!(Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir }

Copy-Item $SourceDir\* -Destination $DestDir -Recurse -Container

$R1 = "$DestDir\HDP-R1\Virtual Machines\A35E800B-2155-4E68-BE8F-E8151E6BAF14.vmcx"
Compare-VM -Path $R1
Import-VM -Path $R1

$DC1 = "$DestDir\HDP-DC1\Virtual Machines\1EBC8627-6910-4DA2-906F-FD229BEB695D.vmcx"
Compare-VM -Path $DC1
Import-VM -Path $DC1

$SVR1 = "$DestDir\HDP-SVR1\Virtual Machines\12D4B973-ABBD-4D92-A8D0-30A572DEF907.vmcx"
Compare-VM -Path $SVR1
Import-VM -Path $SVR1

$SVR2 = "$DestDir\HDP-SVR2\Virtual Machines\A81277DF-280C-455C-9C8E-920AA5BDF949.vmcx"
Compare-VM -Path $SVR2
Import-VM -Path $SVR2

$SVR3 = "$DestDir\HDP-SVR3\Virtual Machines\53C0103C-5F50-4554-A584-EE9134E75893.vmcx"
Compare-VM -Path $SVR3
Import-VM -Path $SVR3

#endregion