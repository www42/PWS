#region Lab variables

$Lab       ="Base"
$LabDrive  = "D:"
$LabDir    = "D:\Labs\Base"
$LabSwitch = "External Network"

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

$IsoPath = "D:\iso\14393.0.160715-1616.RS1_RELEASE_SERVER_EVAL_X64FRE_EN-US.ISO"
$VmComputerName = "1710core-en"
$VmName = "$Lab-$VmComputerName"
New-LabVmGen2 -VmComputerName $VmComputerName
Add-VMDvdDrive -VMName $VmName
Set-VMDvdDrive -VMName $VmName -Path $IsoPath
Set-VMFirmware -VMName $VmName -FirstBootDevice $(Get-VMDvdDrive -VMName $VmName)
#Get-VMFirmware -VMName $VmName | % BootOrder
Connect-LabVm $VmComputerName

#endregion