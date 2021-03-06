﻿
#region Mount Windows Server Iso

$IsoPath = "D:\iso\Windows_InsiderPreview_Server_16278.iso"

$a = Mount-DiskImage -ImagePath $IsoPath -PassThru | Get-Volume | Select-Object -ExpandProperty DriveLetter 
$IsoDriveLetter = $a + ":"

#endregion

#region Explore Wim File

dir -Recurse -Path $IsoDriveLetter -Filter *.wim

$WimPath = Join-Path  $IsoDriveLetter "sources\install.wim"

Get-WindowsImage -ImagePath $WimPath

# Datacenter Edition with Desktop Experience
#$Index = "4"

# Datacenter Edition Core
$Index = "2"

Get-WindowsImage -ImagePath $WimPath -Index $Index

#endregion

#region Convert Wim Image into Bootable Vhd

$VhdPath = "D:\BootVhd\WS1709-InsiderPreview_16278.vhd"
$VhdSize = 80GB

$ScriptPath = "D:\BootVhd\Convert-WindowsImage--tj_line_4092.ps1"

. $ScriptPath

Convert-WindowsImage -SourcePath $WimPath -Edition $Index -VHDFormat VHD -VHDPath $VhdPath -SizeBytes $VhdSize -BCDinVHD NativeBoot -Verbose

#endregion

#region Edit Boot Configuration

$VhdWindowsLetter = Mount-VHD -Path $VhdPath -Passthru | Get-Disk | Get-Partition | ? PartitionNumber -eq 2 | % DriveLetter
$a = $VhdWindowsLetter + ":\Windows"
bcdboot $a
Dismount-VHD -Path $VhdPath

#endregion

#region Dismount Windows Server Iso

Dismount-DiskImage -ImagePath $IsoPath

#endregion