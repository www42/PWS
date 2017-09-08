# Implementing service accounts
# -----------------------------

#region Variables
$ComputerNameDC2  = "DC2"
$VmNameDC2  = "HDP-ContosoDC2"
$DomCred   = New-Object System.Management.Automation.PSCredential "Contoso\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
#endregion

#region Sessions
$DC2   = New-PSSession -VMName $VmNameDC2  -Credential $DomCred 
#endregion

#region  Create and associate a managed service account

Enter-PSSession -Session $DC2
  cd \
  Add-KdsRootKey –EffectiveTime ((get-date).addhours(-10))
  New-ADServiceAccount –Name Webservice –DNSHostName DC2 –PrincipalsAllowedToRetrieveManagedPassword DC2$
  Add-ADComputerServiceAccount -Identity DC2 –ServiceAccount Webservice
  Get-ADServiceAccount -Filter *
  Get-ADServiceAccount -Identity webservice  -Properties * | % PrincipalsAllowedToRetrieveManagedPassword
  Install-ADServiceAccount –Identity Webservice
Exit-PSSession

#endregion
