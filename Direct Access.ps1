# Direct Access
# -------------
#region Variables
$ComputerNameDC1  = "DC1"
$ComputerNameSVR1 = "SVR1"
$ComputerNameCL1  = "CL1"
$VmNameDC1  = "$Lab-$ComputerNameDC1"
$VmNameSVR1 = "$Lab-$ComputerNameSVR1"
$VmNameCL1  = "$Lab-$ComputerNameCL1"
$LocalCred = New-Object System.Management.Automation.PSCredential "Admin",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)

$VmNames = $VmNameDC1,$VmNameSVR1,$VmNameCL1
#endregion

#region Zusätzliches virtuelles Netzwerk "Simuliertes Internet"

New-VMSwitch -Name "Simuliertes Internet" -SwitchType Private | Out-Null
Get-VMSwitch

#endregion

#region Import VM "HDP-CL1"

Copy-Item -Path T:\Labs\HDP\HDP-CL1 -Destination C:\Labs\HDP -Container -Recurse
Compare-VM -Path 'C:\Labs\HDP\HDP-CL1\Virtual Machines\3EAC35B6-1D9E-40ED-BDD2-3AA06E193166.vmcx' | % Incompatibilities
Import-VM  -Path 'C:\Labs\HDP\HDP-CL1\Virtual Machines\3EAC35B6-1D9E-40ED-BDD2-3AA06E193166.vmcx'

#endregion

#region Start VMs
foreach ($VmName in $VmNames) {
    Start-VM -Name $VmName
}
#endregion

#region Sessions
$DC1   = New-PSSession -VMName $VmNameDC1  -Credential $DomCred 
$SVR1  = New-PSSession -VMName $VmNameSVR1 -Credential $DomCred
$CL1   = New-PSSession -VMName $VmNameCL1  -Credential $LocalCred
#endregion

#region Join CL1 to adatum domain

Invoke-Command -VMName $VmNameCL1 -Credential $LocalCred {
    Add-Computer -DomainName "adatum.com" -Credential $Using:DomCred -Restart}

#endregion

#region Zusätzliche Netzwerkkarte in SVR1

Add-VMNetworkAdapter -VMName $VmNameSVR1 -Name "Netzwerkkarte 2" -SwitchName "Simuliertes Internet"
Get-VMNetworkAdapter -VMName $VmNameSVR1

Invoke-Command -Session $SVR1 {
  New-NetIPAddress -InterfaceAlias "Ethernet 2" -IPAddress "131.107.0.1" -PrefixLength 16
  }

#endregion

#region Feature installieren 

Invoke-Command -Session $SVR1 {
  Install-WindowsFeature DirectAccess-VPN -IncludeManagementTools
  }

#endregion

#region New AD Group

Invoke-Command -Session $DC1 {
  New-ADGroup -Name "DA-Clients" -GroupScope Global -Path "cn=Users,dc=adatum,dc=com" 
  $CL1 = Get-ADComputer -Identity CL1
  Add-ADGroupMember -Identity DA-Clients -Members $CL1
  }


#endregion