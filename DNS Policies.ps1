#region Variables
$ComputerNameDC1  = "DC1"
$ComputerNameSVR1 = "SVR1"
$ComputerNameSVR2 = "SVR2"
$VmNameDC1  = "$Lab-$ComputerNameDC1"
$VmNameSVR1 = "$Lab-$ComputerNameSVR1"
$VmNameSVR2 = "$Lab-$ComputerNameSVR2"
$LocalCred = New-Object System.Management.Automation.PSCredential        "Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)

$VmNames = $VmNameDC1,$VmNameSVR1,$VmNameSVR2
#endregion

#region Start VMs
foreach ($VmName in $VmNames) {
    Start-VM -Name $VmName
}
#endregion

#region Sessions
$DC1   = New-PSSession -VMName $VmNameDC1  -Credential $DomCred 
$SVR1  = New-PSSession -VMName $VmNameSVR1 -Credential $DomCred
$SVR2  = New-PSSession -VMName $VmNameSVR2 -Credential $DomCred
#endregion

#region Check DNS name resolution before configuring DNS policies

Enter-PSSession -Session $DC1
  cd \
  Add-DnsServerResourceRecordA -Name "www" -IPv4Address 10.80.0.10 -ZoneName "adatum.com"
Exit-PSSession

Enter-PSSession -Session $SVR1
  cd \
  Clear-DnsClientCache
  Resolve-DnsName www.adatum.com
Exit-PSSession

Enter-PSSession -Session $SVR2
  cd \
  Clear-DnsClientCache
  Resolve-DnsName www.adatum.com
Exit-PSSession

#endregion

#region Configure DNS policies
Enter-PSSession -Session $DC1
  Add-DnsServerZoneScope –ZoneName "adatum.com" -Name "partners"
  Add-DNSServerClientSubnet –Name “TreyPartner” –IPv4Subnet 10.80.0.22/32
  Add-DnsServerResourceRecord -ZoneName "adatum.com" -A -Name "www" -IPv4Address "131.107.0.200" -ZoneScope "partners"
  Add-DnsServerQueryResolutionPolicy `
      -Name "SplitBrainZonePolicy" `
      -Action ALLOW -ClientSubnet "eq,TreyPartner" `
      -ZoneScope "partners,1" `
      -ZoneName adatum.com
Exit-PSSession
#endregion

#region Check DNS name resolution after configuring DNS policies

Enter-PSSession -Session $SVR1
  Clear-DnsClientCache
  Resolve-DnsName www.adatum.com
Exit-PSSession

Enter-PSSession -Session $SVR2
  Clear-DnsClientCache
  Resolve-DnsName www.adatum.com
Exit-PSSession

#endregion
