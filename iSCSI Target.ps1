# Create iSCSI target
# ===================

# Start DC1, SVR1, SVR2, R1 (für CAU)

# -----------------------
# Run this script on HOST
# -----------------------


$LocalCred = New-Object System.Management.Automation.PSCredential        "Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
$ComputerNameDC1  = "DC1"
$ComputerNameSVR1 = "SVR1"
$ComputerNameSVR2 = "SVR2"
$VmNameDC1  = "$Lab-$ComputerNameDC1"
$VmNameSVR1 = "$Lab-$ComputerNameSVR1"
$VmNameSVR2 = "$Lab-$ComputerNameSVR2"


# Configure the iSCSI targets
#
Invoke-Command -VMName $VmNameDC1 -Credential $DomCred {
    Install-WindowsFeature -Name FS-iSCSITarget-Server

    $TargetName = "Cluster"
    New-IscsiServerTarget -TargetName $TargetName -InitiatorIds IPAddress:10.80.0.21,IPAddress:10.80.0.22

    [uint64]$LunSize = 5GB
    for ($i = 1; $i -le 3; $i++)
    { 
        [string]$LunPath = "c:\iSCSIDisk\iSCSIDisk$i.vhdx"
        New-IscsiVirtualDisk -Path $LunPath -SizeBytes $LunSize
        Add-IscsiVirtualDiskTargetMapping -TargetName $TargetName -Path $LunPath
    }
}
