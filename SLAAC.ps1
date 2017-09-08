#region Variables
$ComputerNameDC1  = "DC1"
$ComputerNameSVR1 = "SVR1"
$ComputerNameSVR2  = "SVR2"
$ComputerNameR1   = "R1"
$VmNameDC1  = "$Lab-$ComputerNameDC1"
$VmNameSVR1 = "$Lab-$ComputerNameSVR1"
$VmNameSVR2  = "$Lab-$ComputerNameSVR2"
$VmNameR1   = "$Lab-$ComputerNameR1"

$LocalCred = New-Object System.Management.Automation.PSCredential "Admin",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)

$VmNames = $VmNameDC1,$VmNameSVR1,$VmNameSVR2,$VmNameR1
#endregion

#region Start VMs
foreach ($VmName in $VmNames) {
    Start-VM -Name $VmName
}
#endregion

#region Sessions
$DC1   = New-PSSession -VMName $VmNameDC1  -Credential $DomCred 
$SVR1  = New-PSSession -VMName $VmNameSVR1 -Credential $DomCred
$SVR2   = New-PSSession -VMName $VmNameSVR2  -Credential $DomCred
#endregion

#region Zusätzliche Netzwerkkarte in SVR1

Add-VMNetworkAdapter -VMName $VmNameSVR1 -Name "Netzwerkkarte" -SwitchName "External Network"
Get-VMNetworkAdapter -VMName $VmNameSVR1

#endregion

#region Configure DC1 (static IPv6 address, DHCPv6 server option)

Enter-PSSession -Session $DC1
  cd \
  New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress "2001:db8:bade:affe::a" -PrefixLength 64
  Get-DnsServerResourceRecord -ZoneName "adatum.com"
  Get-DhcpServerv6OptionDefinition | ft Name,OptionId, Type
  Set-DhcpServerv6OptionValue -OptionId  23 -Value "2001:db8:bade:affe::a"
  Get-DhcpServerv6OptionValue | Format-Table OptionId,Name,Type,Value
Exit-PSSession

#endregion
#region Configure SVR1 (static IPv6 address, Router Advertisement)

Enter-PSSession -Session $SVR1
  cd \
  Get-NetAdapter
  New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress "2001:db8:bade:affe::15" -PrefixLength 64

  Set-NetIPInterface -InterfaceAlias "Ethernet" `                     -AddressFamily IPv6 `                     -Forwarding Enabled `                     -Advertising Enabled `                     -ManagedAddressConfiguration Disabled `                     -OtherStatefulConfiguration Enabled `                     -AdvertiseDefaultRoute Enabled  Get-NetIPInterface -InterfaceAlias "Ethernet" -AddressFamily IPv6 |       Format-List Forwarding,RouterDiscovery,Advertising,ManagedAddressConfiguration,OtherStatefulConfiguration,AdvertiseDefaultRoute
  Get-NetRoute -DestinationPrefix "2001:db8:bade:affe::/64" | Format-List DestinationPrefix,InterfaceAlias,Publish
  Set-NetRoute -InterfaceAlias "Ethernet" -DestinationPrefix "2001:db8:bade:affe::/64" -Publish Yes

Exit-PSSession

#endregion#region Test mit SVR2

Enter-PSSession -Session $SVR2
  cd \

  Get-NetIPInterface -InterfaceAlias "Ethernet" -AddressFamily IPv6 |      Format-List RouterDiscovery,Dhcp,AdvertisedRouterLifetime  Get-NetIPConfiguration  Get-NetIPAddress -AddressFamily IPv4 | Format-Table InterfaceAlias,IPAddress,PrefixLength,PrefixOrigin  Get-NetIPAddress -AddressFamily IPv6 | Format-Table InterfaceAlias,IPAddress,PrefixLength,PrefixOrigin  Get-NetRoute

Exit-PSSession

#endregion