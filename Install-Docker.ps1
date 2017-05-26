
#region Variables

$Lab = "PWS"
$ServerComputerName = "NANO2"

$ServerVmName = ConvertTo-VmName -VmComputerName $ServerComputerName -Lab $Lab
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)

Write-Host -ForegroundColor DarkCyan "Variables.................................... done."

#endregion

#region Install Docker

# funktioniert nicht über PowerShell direct :-(

# Namensauflösung sollte über ...\etc\hosts  funktionieren
# Resolve-DnsName -Name $ServerComputerName

Invoke-Command -ComputerName $ServerComputerName -Credential $DomCred {
  Install-PackageProvider -Name DockerMsftProvider -Force | Out-Null
  Install-Package -Name Docker -ProviderName DockerMsftProvider -Force | Out-Null
  Restart-Computer 
}

Start-Sleep -Seconds 60

Invoke-Command -ComputerName $ServerComputerName -Credential $DomCred {
  Get-Service -Name Docker
  Get-Command -Name docker,dockerd | ft Name,Version,Source }

#endregion