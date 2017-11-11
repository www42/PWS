#region Lab variables

$Lab       ="Base"
$LabDir    = "D:\Labs\Base"
$LabSwitch = "External Network"

if ( -not (Test-Path $LabDir) ) { echo "`$LabDir `"$LabDir`" does not exist." }
if ( -not (Get-VMSwitch -Name $LabSwitch -ea SilentlyContinue) ) {echo "`$LabSwitch `"$LabSwitch`" does not exist."}


#endregion

#region Starting with an older Base version
$VmComputerName = "1710en"
$LabBaseGen2 = "D:\Base\Base-WS2016_1607_withDesktopExperience_en_GPT_1708.vhdx"
New-LabVmGen2Copying -VmComputerName $VmComputerName

$VmComputerName = "1710de"
$LabBaseGen2 = "D:\Base\Base-WS2016_1607_withDesktopExperience_DE_GPT_1708.vhdx"
New-LabVmGen2Copying -VmComputerName $VmComputerName

#endregion

#region Starting from the very beginning

#$IsoPath = "D:\iso\14393.0.161119-1705.RS1_REFRESH_SERVER_EVAL_X64FRE_EN-US.ISO"
#$IsoPath = "D:\iso\Windows_InsiderPreview_Server_16278.iso"
$IsoPath = "D:\iso\en_windows_server_version_1709_x64_dvd_100090904.iso"

#$VmComputerName = "WS2016_DesktopExperience_withUpdates1710_en-US"
#$VmComputerName = "WS1709_InsiderBuild16278_withUpdates1710_en-US"
$VmComputerName = "WS1709_Core_withUpdates1710_en-US"

$VmName = "$Lab-$VmComputerName"
New-LabVmGen2 -VmComputerName $VmComputerName
Add-VMDvdDrive -VMName $VmName
Set-VMDvdDrive -VMName $VmName -Path $IsoPath
Set-VMFirmware -VMName $VmName -FirstBootDevice $(Get-VMDvdDrive -VMName $VmName)
#Get-VMFirmware -VMName $VmName | % BootOrder
Connect-LabVm $VmComputerName

#endregion

#region Configuration steps

# [nur Client] Administrator Password setzen und aktivieren, Benutzer "Paul" und sein Profil löschen
#
# Windows Update
#
# Powershell Update-Help
#
# Windows Explorer 
#         General
#              "Show recently used files in Quick access"     uncheck
#              "Show frequently used folders in Quick access" uncheck
#         View
#              "Hide extentions for known file types"         uncheck
#              "Expand to open folder"                        check
#              "Show all folders"                             check
#
# Settings - System - Power & sleep - Screen: When plugged in, turn off after "Never"
#
# Control Panel - Sound - No Sounds
#
# Computer Management - Administrator - Password never expires
#
# Server Manager - Do not start automatically at logon
#
# IE Enhanced Security Configuration - Off
#
# [nur Server] Set-Service -Name MapsBroker -StartupType Disabled
#
# BackInfo & ZoomIt - siehe unten
#
# sysprep - siehe unten

#endregion

#region BackInfo und ZoomIt

# 1.) Ordner kopieren C:\Program Files (x86)\BackInfo
# 
# 2.) Shortcut "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\BackInfo.exe.lnk" [shell:common startup]
# 
# 3.) Tool kopieren "C:\Windows\System32\ZoomIt.exe"
#     
#          Zoom             - Strg-^
#          LiveZoom         - <not set>
#          Draw             - Strg-2 (default)
#          Break            - Strg-6
#          "Show tray icon" - uncheck
#          "Run ZoomIt ..." - check

#endregion

#region sysprep

# 1.) Antwortdatei kopieren "C:\Windows\System32\Sysprep\CopyProfile_and_OOBE.xml"
# 
# 2.) Vhd sichern als "C:\Labss\Base\BeforeSysprep\Base-BeforeSysprep-xxxxx.vhdx"
# 
# 3.) c:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /unattend:"C:\Windows\System32\Sysprep\CopyProfile_and_OOBE.xml" /shutdown
# 
# 4.) Vhd sichern als "D:\Base\Base-xxxxx.vhdx"

#endregion

#region Server Core specials

$Cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "Administrator",(ConvertTo-SecureString -String 'Pa55w.rd' -AsPlainText -Force)
$Core = New-PSSession -VMName $VmName -Credential $Cred

Copy-Item -Path D:\temp\CopyProfile_and_OOBE.xml -ToSession $Core -Destination C:\Windows\System32\Sysprep\
Invoke-Command -Session $Core { c:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /unattend:"C:\Windows\System32\Sysprep\CopyProfile_and_OOBE.xml" /shutdown }


#endregion