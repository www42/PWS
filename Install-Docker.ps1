﻿
#region Variables

$ServerComputerName = "NANO1"
$Lab = "PWS"

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
}

Stop-LabVm -VmComputerName $ServerComputerName
Start-LabVm -VmComputerName $ServerComputerName

Start-Sleep -Seconds 60

Write-Host -ForegroundColor DarkCyan "Install Docker............................... done."

#endregion

#region Test Docker installation

Invoke-Command -ComputerName $ServerComputerName -Credential $DomCred {
  Get-Service -Name Docker
  Get-Command -Name docker,dockerd | ft Name,Version,Source 
  docker version
}

Write-Host -ForegroundColor DarkCyan "Test Docker installation..................... done."

#endregion