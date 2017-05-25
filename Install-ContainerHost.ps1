
#region Variables

$Lab = "PWS"
$ServerComputerName = "SVR1"
$DcComputerName     = "DC1"

$ServerVmName = ConvertTo-VmName -VmComputerName $ServerComputerName
$DcVmName     = ConvertTo-VmName -VmComputerName $DcComputerName
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)

Write-Host -ForegroundColor DarkCyan "Variables.................................... done."

#endregion

#region Start VMs

Start-LabVm -Lab $Lab -VmComputerName $DcComputerName -WarningAction SilentlyContinue | Out-Null
Start-Sleep -Seconds 15
Start-LabVm -Lab $Lab -VmComputerName $ServerComputerName -WarningAction SilentlyContinue | Out-Null

Write-Host -ForegroundColor DarkCyan "Start VMs.................................... done."

#endregion

#region Install Docker

# funktioniert nicht über PowerShell direct :-(

# Namensauflösung sollte über ...\etc\hosts  funktionieren
# Resolve-DnsName -Name $ServerComputerName

Invoke-Command -ComputerName $ServerComputerName -Credential $DomCred {
  Install-PackageProvider -Name DockerMsftProvider -Force | Out-Null
  Install-Package -Name Docker -ProviderName DockerMsftProvider -Force | Out-Null
  Restart-Computer }

Start-Sleep -Seconds 30

Invoke-Command -ComputerName $ServerComputerName -Credential $DomCred {
  Get-Service -Name Docker
  Get-Command -Name docker,dockerd | ft Name,Version,Source }

Write-Host -ForegroundColor DarkCyan "Install Docker............................... done."

#endregion