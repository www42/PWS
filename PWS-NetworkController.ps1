
#region Variables

$Lab = "PWS"

$ServerComputerName = "SVR1"
$DcComputerName     = "DC1"

$ServerVmName = ConvertTo-VmName -VmComputerName $ServerComputerName
$DcVmName     = ConvertTo-VmName -VmComputerName $DcComputerName

$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)

Write-Host -ForegroundColor Cyan "Variables.................................... done."

#endregion

#region Create AD groups

Invoke-Command -VMName $DcVmName -Credential $DomCred {

    New-ADGroup -Name "Network Controller Admins" `
                -SamAccountName "Network Controller Admins" `
                -GroupCategory "Security" `
                -GroupScope "Global" `
                -Path "CN=Users,DC=Adatum,DC=com"

    New-ADGroup -Name "Network Controller Ops" `
                -SamAccountName "Network Controller Ops" `
                -GroupCategory "Security" `
                -GroupScope "Global" `
                -Path "CN=Users,DC=Adatum,DC=com"

    Add-ADPrincipalGroupMembership `
                -Identity "CN=Administrator,CN=Users,DC=Adatum,DC=com" `
                -MemberOf "CN=Network Controller Ops,CN=Users,DC=Adatum,DC=com",`
                          "CN=Network Controller Admins,CN=Users,DC=Adatum,DC=com"
}

Write-Host -ForegroundColor Cyan "Create AD groups............................. done."

#endregion

#region Deploy Network Controller

Invoke-Command -VMName $ServerVmName -Credential $DomCred {
    
    Install-WindowsFeature -Name "NetworkController" -IncludeManagementTools
    Restart-Computer
}

Start-Sleep -Seconds 60

#---------------------------------------

Invoke-Command -VMName $ServerVmName -Credential $DomCred {

    Get-Certificate -Template "Machine" -CertStoreLocation "Cert:\LocalMachine\My"
    $Certificate = Get-ChildItem Cert:\LocalMachine\My | where {$_.Subject -imatch "SVR1" }

    $node = New-NetworkControllerNodeObject `
            -Name          "Node1" `
            -Server        "SVR1.adatum.com" `
            -FaultDomain   "fd:/rack1/host1" `
            -RestInterface "Ethernet"
    
    Install-NetworkControllerCluster `
            -Node $node `
            -ClusterAuthentication Kerberos `
            -ManagementSecurityGroup "Adatum\Network Controller Admins" `
            -CredentialEncryptionCertificate $Certificate

    Install-NetworkController `
            -Node $node `
            -ClientAuthentication Kerberos `
            -ClientSecurityGroup "Adatum\Network Controller Ops" `
            -RestIpAddress "10.60.0.99/24" `
            -ServerCertificate $Certificate
}


    Get-NetworkControllerCluster
    Get-NetworkController
    Get-NetworkControllerDeploymentInfo -NetworkController SVR1

#endregion

#region Create Virtual Networks

Import-Module -Name NetworkController

# Define the Virtual Network
$VirtualNetworkProperties                = New-Object -TypeName Microsoft.Windows.NetworkController.VirtualNetworkProperties
$VirtualNetworkProperties.AddressSpace   = New-Object -TypeName Microsoft.Windows.NetworkController.AddressSpace
$VirtualNetworkProperties.LogicalNetwork = New-Object -TypeName Microsoft.Windows.NetworkController.LogicalNetwork

$VirtualNetworkProperties.LogicalNetwork.ResourceRef = "/LogicalNetworks/HNVPA"
$VirtualNetworkProperties.AddressSpace.AddressPrefixes = "192.168.0.0/16"

# Add a Virtual Subnet for Web Server Tier
$VirtualNetworkProperties.Subnets                                += New-Object -TypeName Microsoft.Windows.NetworkController.VirtualSubnet
$VirtualNetworkProperties.Subnets[0].Properties                   = New-Object -TypeName Microsoft.Windows.NetworkController.VirtualSubnetProperties
$VirtualNetworkProperties.Subnets[0].Properties.AccessControlList = New-Object -TypeName Microsoft.Windows.NetworkController.AccessControlList

$VirtualNetworkProperties.Subnets[0].ResourceId = "Subnet1"
$VirtualNetworkProperties.Subnets[0].Properties.AddressPrefix = "192.168.1.0/24"
$VirtualNetworkProperties.Subnets[0].Properties.AccessControlList.ResourceRef = "/accessControlList/AllowAll"

# Add a Virtual Subnet for File Server Tier
$VirtualNetworkProperties.Subnets                                += New-Object -TypeName Microsoft.Windows.NetworkController.VirtualSubnet
$VirtualNetworkProperties.Subnets[1].Properties                   = New-Object -TypeName Microsoft.Windows.NetworkController.VirtualSubnetProperties
$VirtualNetworkProperties.Subnets[1].Properties.AccessControlList = New-Object -TypeName Microsoft.Windows.NetworkController.AccessControlList

$VirtualNetworkProperties.Subnets[1].ResourceId = "Subnet2"
$VirtualNetworkProperties.Subnets[1].Properties.AddressPrefix = "192.168.2.0/24"
$VirtualNetworkProperties.Subnets[1].Properties.AccessControlList.ResourceRef = "/accessControlList/AllowAll"

# Apply the settings -- funktioniert nicht Krrrrrr :-((
$Uri = "https://SVR1.adatum.com"
#$Uri = "https://10.60.0.99"
New-NetworkControllerVirtualNetwork -ResourceId "MyNetwork" -Properties $VirtualNetworkProperties -ConnectionUri $Uri -Verbose -Force

#endregion
