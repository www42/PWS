#region Variables
$ComputerNameDC1  = "DC1"
$ComputerNameSVR1 = "SVR1"
$ComputerNameSVR2 = "SVR2"
$VmNameDC1  = "$Lab-$ComputerNameDC1"
$VmNameSVR1 = "$Lab-$ComputerNameSVR1"
$VmNameSVR2 = "$Lab-$ComputerNameSVR2"
$LocalCred = New-Object System.Management.Automation.PSCredential        "Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
#endregion

#region Zusätzliche Platten für die Nodes

Remove-VMDvdDrive -VMName BBV-SVR1 -ControllerNumber 0 -ControllerLocation 1

foreach ($NodeName in "BBV-SVR1","BBV-SVR2")
{
  $Disk1 = "$LabDir\$NodeName\Virtual Hard Disks\Disk1.vhdx"
  $Disk2 = "$LabDir\$NodeName\Virtual Hard Disks\Disk2.vhdx"
  $Disk3 = "$LabDir\$NodeName\Virtual Hard Disks\Disk3.vhdx"
  $Disk4 = "$LabDir\$NodeName\Virtual Hard Disks\Disk4.vhdx"
  New-VHD -Path $Disk1 -Dynamic -SizeBytes 100GB | Out-Null
  New-VHD -Path $Disk2 -Dynamic -SizeBytes 100GB | Out-Null
  New-VHD -Path $Disk3 -Dynamic -SizeBytes 100GB | Out-Null
  New-VHD -Path $Disk4 -Dynamic -SizeBytes 100GB | Out-Null
  Add-VMHardDiskDrive -VMName $NodeName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1 -Path $Disk1
  Add-VMHardDiskDrive -VMName $NodeName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 2 -Path $Disk2
  Add-VMHardDiskDrive -VMName $NodeName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 3 -Path $Disk3
  Add-VMHardDiskDrive -VMName $NodeName -ControllerLocation 4 -Path $Disk4
  Get-VMHardDiskDrive -VMName $NodeName
}

#endregion

#region Start VMs
Start-VM -Name $VmNameDC1
Start-Sleep -Seconds 30
Start-VM -Name $VmNameSVR1,$VmNameSVR2
#endregion

#region Sessions
$DC1   = New-PSSession -VMName BBV-DC1  -Credential $DomCred 
$SVR1  = New-PSSession -VMName BBV-SVR1 -Credential $DomCred
$SVR2  = New-PSSession -VMName BBV-SVR2 -Credential $DomCred
#endregion

#region Create Cluster

Invoke-Command -Session $SVR1,$SVR2 {
    Install-WindowsFeature –Name File-Services,Failover-Clustering –IncludeManagementTools}

# en-US
# -----
#Invoke-Command -Session $SVR1 {
#    Test-Cluster -Node SVR1,SVR2 `
#                 -Include “Storage Spaces Direct”,"Inventory","Network",”System Configuration” `
#                 -ReportName "C:\Report"}

# de-DE
# -----
Invoke-Command -Session $SVR1 {
    Test-Cluster -Node SVR1,SVR2 `
                 -Include “Storage Spaces Direct”,"Inventar","Netzwerk",”Systemkonfiguration” `
                 -ReportName "C:\Report"}

Copy-Item -FromSession $SVR1 -Path C:\Report.htm -Destination "$HOME\Desktop"

$ClusterIP = "10.80.0.100"
$ClusterName = "Cluster1"
Invoke-Command -Session $SVR1 {
    New-Cluster –Name $using:ClusterName –Node SVR1,SVR2 –NoStorage –StaticAddress $using:ClusterIP}

#endregion

#region Create S2D (Pool, vDisk, Volume)

Invoke-Command -Session $SVR1 {
    Enable-ClusterS2D -CacheState Disabled -AutoConfig:0 -SkipEligibilityChecks -Confirm:$false}

$PoolFriendlyName = "S2DStoragePool"
Invoke-Command -Session $SVR1 {
    $ClusterFqdn = "$using:ClusterName.adatum.com"
    New-StoragePool  -StorageSubSystemName $ClusterFqdn `
                     -FriendlyName $using:PoolFriendlyName `
                     -ProvisioningTypeDefault Fixed `
                     -ResiliencySettingNameDefault Mirror `
                     -PhysicalDisk (Get-StorageSubSystem  -Name $ClusterFqdn | Get-PhysicalDisk) }

$VolumeFriendlyName = "CSV"
Invoke-Command -Session $SVR1 {
    New-Volume -StoragePoolFriendlyName $using:PoolFriendlyName `               -FriendlyName $using:VolumeFriendlyName `
               -FileSystem CSVFS_ReFS `
               -Size 50GB }

#endregion

#region Create Scale Out File Server

$FsFriendlyName = "SOFS"
Invoke-Command -Session $SVR1 {
    $ClusterFqdn = "$using:ClusterName.adatum.com"
    New-StorageFileServer -StorageSubSystemName $ClusterFqdn `
                          -FriendlyName $using:FsFriendlyName `
                          -HostName $using:FsFriendlyName `
                          -Protocols SMB }

#endregion

#region Create File Share

Invoke-Command -Session $SVR1 {
    mkdir "C:\ClusterStorage\Volume1\VM"
    mkdir "C:\ClusterStorage\Volume1\VHD"
    New-SmbShare -Name VM  -Path "C:\ClusterStorage\Volume1\VM"  -FullAccess "Adatum\Administrator"
    New-SmbShare -Name VHD -Path "C:\ClusterStorage\Volume1\VHD" -FullAccess "Adatum\Administrator"
    Set-SmbPathAcl -ShareName VM
    Set-SmbPathAcl -ShareName VHD }

#endregion

#region Zusätzliche Platten löschen

foreach ($NodeName in "BBV-SVR1","BBV-SVR2")
{
  $Disk1 = "$LabDir\$NodeName\Virtual Hard Disks\Disk1.vhdx"
  $Disk2 = "$LabDir\$NodeName\Virtual Hard Disks\Disk2.vhdx"
  $Disk3 = "$LabDir\$NodeName\Virtual Hard Disks\Disk3.vhdx"
  $Disk4 = "$LabDir\$NodeName\Virtual Hard Disks\Disk4.vhdx"
  Remove-VMHardDiskDrive -VMName $NodeName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1
  Remove-VMHardDiskDrive -VMName $NodeName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 2
  Remove-VMHardDiskDrive -VMName $NodeName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 3
  Remove-VMHardDiskDrive -VMName $NodeName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 4
  Get-VMHardDiskDrive -VMName $NodeName
  Remove-Item -Path $Disk1
  Remove-Item -Path $Disk2
  Remove-Item -Path $Disk3
  Remove-Item -Path $Disk4
}


#endregion