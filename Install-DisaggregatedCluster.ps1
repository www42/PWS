# 1. Cluster (SOFS Cluster)
#region VMs for SOFS Cluster

New-LabVmGen2Differencing -VmComputerName SOFS1
New-LabVmGen2Differencing -VmComputerName SOFS2

#endregion
#region Zusätzliche Platten für die Nodes

foreach ($NodeName in "ATL-SOFS1","ATL-SOFS2")
{
  $Disk1 = "$LabDir\$NodeName\Virtual Hard Disks\Disk1.vhdx"
  $Disk2 = "$LabDir\$NodeName\Virtual Hard Disks\Disk2.vhdx"
  $Disk3 = "$LabDir\$NodeName\Virtual Hard Disks\Disk3.vhdx"
  $Disk4 = "$LabDir\$NodeName\Virtual Hard Disks\Disk4.vhdx"
  New-VHD -Path $Disk1 -Dynamic -SizeBytes 100GB | Out-Null
  New-VHD -Path $Disk2 -Dynamic -SizeBytes 100GB | Out-Null
  New-VHD -Path $Disk3 -Dynamic -SizeBytes 100GB | Out-Null
  New-VHD -Path $Disk4 -Dynamic -SizeBytes 100GB | Out-Null
  Add-VMHardDiskDrive -VMName $NodeName -ControllerLocation 1 -Path $Disk1
  Add-VMHardDiskDrive -VMName $NodeName -ControllerLocation 2 -Path $Disk2
  Add-VMHardDiskDrive -VMName $NodeName -ControllerLocation 3 -Path $Disk3
  Add-VMHardDiskDrive -VMName $NodeName -ControllerLocation 4 -Path $Disk4
  Get-VMHardDiskDrive -VMName $NodeName
}

#endregion
#region Start VMs

Start-LabVm SOFS1,SOFS2

#endregion
#region Sessions

$LocalCred = New-Object System.Management.Automation.PSCredential        "Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)

$DC1   = New-PSSession -VMName ATL-DC1 -Credential $DomCred 
$SOFS1 = New-PSSession -VMName ATL-SOFS1 -Credential $LocalCred
$SOFS2 = New-PSSession -VMName ATL-SOFS2 -Credential $LocalCred

#endregion
#region Configure SOFS1 (Hostname, IP, join domain)

$VmComputerName = "SOFS1"
$IfAlias        = "Ethernet"
$IpAddress      = "10.60.1.11"
$PrefixLength   = "16"
$DefaultGw      = "10.60.0.1"
$DnsServer      = "10.60.0.10"
$AdDomain       = "Adatum.com"
Invoke-Command -Session $SOFS1 {
    New-NetIPAddress -InterfaceAlias $Using:IfAlias `
                     -IPAddress $Using:IpAddress `
                     -PrefixLength $Using:PrefixLength `
                     -DefaultGateway $Using:DefaultGw
    Set-DnsClientServerAddress -InterfaceAlias $Using:IfAlias `
                               -ServerAddresses $Using:DnsServer
    Rename-Computer -NewName $Using:VmComputerName -Restart}
Start-Sleep -Seconds 60

$SOFS1 = New-PSSession -VMName ATL-SOFS1 -Credential $LocalCred
Invoke-Command -Session $SOFS1 {
    Add-Computer -DomainName $Using:AdDomain -Credential $Using:DomCred -Restart}

#endregion
#region Configure SOFS2 (Hostname, IP, join domain)

$VmComputerName = "SOFS2"
$IfAlias        = "Ethernet"
$IpAddress      = "10.60.1.12"
$PrefixLength   = "16"
$DefaultGw      = "10.60.0.1"
$DnsServer      = "10.60.0.10"
$AdDomain       = "Adatum.com"
Invoke-Command -Session $SOFS2 {
    New-NetIPAddress -InterfaceAlias $Using:IfAlias `
                     -IPAddress $Using:IpAddress `
                     -PrefixLength $Using:PrefixLength `
                     -DefaultGateway $Using:DefaultGw
    Set-DnsClientServerAddress -InterfaceAlias $Using:IfAlias `
                               -ServerAddresses $Using:DnsServer
    Rename-Computer -NewName $Using:VmComputerName -Restart}
Start-Sleep -Seconds 60

$SOFS2 = New-PSSession -VMName ATL-SOFS2 -Credential $LocalCred
Invoke-Command -Session $SOFS2 {
    Add-Computer -DomainName $Using:AdDomain -Credential $Using:DomCred -Restart}

#endregion
#region Create Cluster

$SOFS1 = New-PSSession -VMName ATL-SOFS1 -Credential $DomCred
$SOFS2 = New-PSSession -VMName ATL-SOFS2 -Credential $DomCred

Invoke-Command -Session $SOFS1,$SOFS2 {
    Install-WindowsFeature –Name File-Services,Failover-Clustering –IncludeManagementTools}

Invoke-Command -Session $SOFS1 {
    Test-Cluster -Node SOFS1,SOFS2 `
                 -Include “Storage Spaces Direct”,Inventory,Network,”System Configuration” `
                 -ReportName "C:\Report"}

Copy-Item -FromSession $SOFS1 -Path C:\Report.htm -Destination "$HOME\Desktop"

$ClusterIP = "10.60.1.10"
$ClusterName = "Cluster1"
Invoke-Command -Session $SOFS1 {
    New-Cluster –Name $using:ClusterName –Node SOFS1,SOFS2 –NoStorage –StaticAddress $using:ClusterIP}

#endregion
#region Create S2D (Pool, vDisk, Volume)

Invoke-Command -Session $SOFS1 {
    Enable-ClusterS2D -CacheState Disabled -AutoConfig:0 -SkipEligibilityChecks -Confirm:$false}

$PoolFriendlyName = "S2DStoragePool"
Invoke-Command -Session $SOFS1 {
    $ClusterFqdn = "$using:ClusterName.adatum.com"
    New-StoragePool  -StorageSubSystemName $ClusterFqdn `
                     -FriendlyName $using:PoolFriendlyName `
                     -ProvisioningTypeDefault Fixed `
                     -ResiliencySettingNameDefault Mirror `
                     -PhysicalDisk (Get-StorageSubSystem  -Name $ClusterFqdn | Get-PhysicalDisk) }

$VolumeFriendlyName = "CSV"
Invoke-Command -Session $SOFS1 {
    New-Volume -StoragePoolFriendlyName $using:PoolFriendlyName `               -FriendlyName $using:VolumeFriendlyName `
               -FileSystem CSVFS_ReFS `
               -Size 50GB }

#endregion
#region Create Scale Out File Server

$FsFriendlyName = "SOFS"
Invoke-Command -Session $SOFS1 {
    $ClusterFqdn = "$using:ClusterName.adatum.com"
    New-StorageFileServer -StorageSubSystemName $ClusterFqdn `
                          -FriendlyName $using:FsFriendlyName `
                          -HostName $using:FsFriendlyName `
                          -Protocols SMB }

#endregion
#region Create File Share

Invoke-Command -Session $SOFS1 {
    mkdir "C:\ClusterStorage\Volume1\VM"
    mkdir "C:\ClusterStorage\Volume1\VHD"
    New-SmbShare -Name VM  -Path "C:\ClusterStorage\Volume1\VM"  -FullAccess "Adatum\Administrator"
    New-SmbShare -Name VHD -Path "C:\ClusterStorage\Volume1\VHD" -FullAccess "Adatum\Administrator"
    Set-SmbPathAcl -ShareName VM
    Set-SmbPathAcl -ShareName VHD }

#endregion

# 2. Cluster (Hyper-V Cluster)
#region VMs for Hyper-V Cluster

New-LabVmGen2Differencing -VmComputerName N1
New-LabVmGen2Differencing -VmComputerName N2

#endregion
#region Start VMs

Start-LabVm N1,N2

#endregion
#region Sessions

$N1 = New-PSSession -VMName ATL-N1 -Credential $LocalCred
$N2 = New-PSSession -VMName ATL-N2 -Credential $LocalCred

#endregion
#region Configure N1 (Hostname, IP, join domain)

$VmComputerName = "N1"
$IfAlias        = "Ethernet"
$IpAddress      = "10.60.2.11"
$PrefixLength   = "16"
$DefaultGw      = "10.60.0.1"
$DnsServer      = "10.60.0.10"
$AdDomain       = "Adatum.com"
Invoke-Command -Session $N1 {
    New-NetIPAddress -InterfaceAlias $Using:IfAlias `
                     -IPAddress $Using:IpAddress `
                     -PrefixLength $Using:PrefixLength `
                     -DefaultGateway $Using:DefaultGw
    Set-DnsClientServerAddress -InterfaceAlias $Using:IfAlias `
                               -ServerAddresses $Using:DnsServer
    Rename-Computer -NewName $Using:VmComputerName -Restart}
Start-Sleep -Seconds 60

$N1 = New-PSSession -VMName ATL-N1 -Credential $LocalCred
Invoke-Command -Session $N1 {
    Add-Computer -DomainName $Using:AdDomain -Credential $Using:DomCred -Restart}

#endregion
#region Configure N2 (Hostname, IP, join domain)

$VmComputerName = "N2"
$IfAlias        = "Ethernet"
$IpAddress      = "10.60.2.12"
$PrefixLength   = "16"
$DefaultGw      = "10.60.0.1"
$DnsServer      = "10.60.0.10"
$AdDomain       = "Adatum.com"
Invoke-Command -Session $N2 {
    New-NetIPAddress -InterfaceAlias $Using:IfAlias `
                     -IPAddress $Using:IpAddress `
                     -PrefixLength $Using:PrefixLength `
                     -DefaultGateway $Using:DefaultGw
    Set-DnsClientServerAddress -InterfaceAlias $Using:IfAlias `
                               -ServerAddresses $Using:DnsServer
    Rename-Computer -NewName $Using:VmComputerName -Restart}
Start-Sleep -Seconds 60

$N2 = New-PSSession -VMName ATL-N2 -Credential $LocalCred
Invoke-Command -Session $N2 {
    Add-Computer -DomainName $Using:AdDomain -Credential $Using:DomCred -Restart}

#endregion
#region Create Cluster

$N1 = New-PSSession -VMName ATL-N1 -Credential $DomCred
$N2 = New-PSSession -VMName ATL-N2 -Credential $DomCred

Invoke-Command -Session $N1,$N2 {
    Install-WindowsFeature –Name File-Services,Failover-Clustering –IncludeManagementTools}

$ClusterIP = "10.60.2.10"
$ClusterName = "Cluster2"
Invoke-Command -Session $N1 {
    New-Cluster –Name $using:ClusterName –Node N1,N2 –NoStorage –StaticAddress $using:ClusterIP}

#endregion
