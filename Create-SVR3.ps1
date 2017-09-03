
#region Description


  # SVR3
  # Server with Desktop Experience
  # Static IP address x.x.0.23 /16
  # Member domain Adatum.com

#endregion

#region Variables

# To use local variable <var> in a remote session use $Using:<var>

$Lab            = "HDP"
$LabSwitch      = "HDP"
$VmComputerName = "SVR3"
$IfAlias        = "Ethernet"
$IpAddress      = "10.80.0.23"
$PrefixLength   = "16"
$DefaultGw      = "10.80.0.1"
$DnsServer      = "10.80.0.10"
$AdDomain       = "Adatum.com"

$VmName = ConvertTo-VmName -VmComputerName $VmComputerName -Lab $Lab

$LocalCred = New-Object System.Management.Automation.PSCredential        "Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)

Write-Host -ForegroundColor DarkCyan "Variables.................................... done."

#endregion

#region Create VM

New-LabVmGen2Differencing -VmComputerName $VmComputerName -Lab $Lab -Switch $LabSwitch
Start-LabVm -VmComputerName $VmComputerName

# Wait for specialize and oobe to complete
Start-Sleep -Seconds 180

Write-Host -ForegroundColor DarkCyan "Create VM.................................... done."

#endregion

#region Rename and IP configuration

Invoke-Command -VMName $VmName -Credential $LocalCred {
    New-NetIPAddress -InterfaceAlias $Using:IfAlias -IPAddress $Using:IpAddress -PrefixLength $Using:PrefixLength -DefaultGateway $Using:DefaultGw | Out-Null
    Set-DnsClientServerAddress -InterfaceAlias $Using:IfAlias -ServerAddresses $Using:DnsServer  | Out-Null
    Rename-Computer -NewName $Using:VmComputerName -Restart
    }

# Wait for reboot
Start-Sleep -Seconds 60
Write-Host -ForegroundColor DarkCyan "Rename and IP configuration.................. done."

#endregion

#region Join Domain

Invoke-Command -VMName $VmName -Credential $LocalCred {

    Add-Computer -DomainName $Using:AdDomain -Credential $Using:DomCred -Restart
    
    }

Start-Sleep -Seconds 60
Write-Host -ForegroundColor DarkCyan "Join Domain.................................. done."

#endregion
