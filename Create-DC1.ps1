#Requires -RunAsAdministrator
#Requires -Modules @{ModuleName="tjLabs";ModuleVersion="0.2.6.10"}

#region Description

#  DC1 = First Domain Controller in Adatum.com

#  Static IP address x.x.0.10/16
#  DNS server with reverse lookup zone
#  DHCP server
#  Enterprise Root CA

#endregion

#region Variables

# To use local variable <var> in a remote session use $Using:<var>
# $Lab* are set in profile

$VmComputerName  = "DC1"
$IfAlias         = "Ethernet"
$IpAddress       = "10.80.0.10"
$PrefixLength    = "16"
$DefaultGw       = "10.80.0.1"
$DnsServer       = "10.80.0.10"
$AdDomain        = "Adatum.com"
$AdDomainNetBios = "ADATUM"
$PwLocal         = 'Pa55w.rd'
$PwDomain        = 'Pa55w.rd'

$VmName = ConvertTo-VmName -VmComputerName $VmComputerName -Lab $Lab

$LocalCred = New-Object System.Management.Automation.PSCredential        "Administrator",(ConvertTo-SecureString $PwLocal -AsPlainText -Force)
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString $PwDomain -AsPlainText -Force)

Write-Host -ForegroundColor DarkCyan "Variables.................................... done."

#endregion

#region Create VM

New-LabVmDifferencing -VmComputerName $VmComputerName -Lab $Lab -Switch $LabSwitch
Start-LabVm -VmComputerName $VmComputerName

# Wait for specialize and oobe
Start-Sleep -Seconds 180

Write-Host -ForegroundColor DarkCyan "Create VM.................................... done."

#endregion

#region Rename and configure static IP address

Invoke-Command -VMName $VmName -Credential $LocalCred {
    New-NetIPAddress -InterfaceAlias $Using:IfAlias -IPAddress $Using:IpAddress -PrefixLength $Using:PrefixLength -DefaultGateway $Using:DefaultGw | Out-Null
    Rename-Computer -NewName $Using:VmComputerName -Restart
    }

# Wait for reboot
Start-Sleep -Seconds 60

Write-Host -ForegroundColor DarkCyan "Rename and configure static IP address....... done."

#endregion

#region Dcpromo New Forest

Invoke-Command -VMName $VmName -Credential $LocalCred {

    $SecureModePW=ConvertTo-SecureString -String $using:PwLocal -AsPlainText -Force

    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Out-Null

    Import-Module ADDSDeployment 

    Install-ADDSForest `
        -DomainName $Using:AdDomain `
        -DomainNetbiosName $Using:AdDomainNetBios `
        -DomainMode "WinThreshold" `
        -ForestMode "WinThreshold" `
        -InstallDns:$true `
        -CreateDnsDelegation:$false `
        -SafeModeAdministratorPassword $SecureModePW `
        -DatabasePath "C:\Windows\NTDS" `
        -SysvolPath "C:\Windows\SYSVOL" `
        -LogPath "C:\Windows\NTDS" `
        -NoRebootOnCompletion:$false `
        -Force:$true `
        -WarningAction Ignore | Out-Null
    }
Start-Sleep -Seconds 360

Write-Host -ForegroundColor DarkCyan "Dcpromo New Forest........................... done."

#endregion

#region Configure DNS Server

Invoke-Command -VMName $VmName -Credential $DomCred {   
    Add-DnsServerPrimaryZone -NetworkId '10.80.0.0/16' -ReplicationScope Domain -DynamicUpdate Secure
    Add-DnsServerResourceRecordPtr -ZoneName "80.10.in-addr.arpa" -Name "10.0" -PtrDomainName "DC1.Adatum.com."
    Add-DnsServerForwarder -IPAddress 8.8.8.8
    Remove-DnsServerForwarder -IPAddress fec0:0:0:ffff::1,fec0:0:0:ffff::2,fec0:0:0:ffff::3 -Force
    }

Write-Host -ForegroundColor DarkCyan "Configure DNS Server......................... done."

#endregion

#region Install and configure DHCP Server

Invoke-Command -VMName $VmName -Credential $domcred {

    Install-WindowsFeature -Name DHCP -IncludeManagementTools | Out-Null

    Add-DhcpServerSecurityGroup
    Restart-Service -Name DHCPServer
    Start-Sleep 60
    Add-DhcpServerInDC

    # tell server manager post-install completed
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2

    # server options
    Set-DhcpServerv4OptionValue -DnsDomain "Adatum.com"

    # new scope with scope options
    Add-DhcpServerv4Scope -Name "Deployment" `
                      -StartRange 10.80.99.1 `
                      -EndRange   10.80.99.199 `
                      -SubnetMask 255.255.0.0 -PassThru |
        Set-DhcpServerv4OptionValue -DnsServer 10.80.0.10 `
                                    -Router 10.80.0.1
    }

Write-Host -ForegroundColor DarkCyan "Install and configure DHCP Server............ done."

#endregion

#region Disable IE Enhanced Security Configuration

Invoke-Command -VMName $VmName -Credential $DomCred {
    $ESCAdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $ESCUserKey  = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $ESCAdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $ESCUserKey  -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer -ErrorAction SilentlyContinue
}

Write-Host -ForegroundColor DarkCyan "Disable IE Enhanced Security Configuration... done."

#endregion

#region Ensure FW Domain Profile

Invoke-Command -VMName $VmName -Credential $DomCred {
    Disable-NetAdapter -Name Ethernet -Confirm:$false
    Enable-NetAdapter -Name Ethernet
    Start-Sleep -Seconds 10
}

Write-Host -ForegroundColor DarkCyan "Ensure FW Domain Profile..................... done."

#endregion

#region Password never expires

Invoke-Command -VMName $VmName -Credential $DomCred {
    Set-ADUser -Identity Administrator -PasswordNeverExpires $true
}

Write-Host -ForegroundColor DarkCyan "Password never expires....................... done."

#endregion

#region Install Adatum CA

Invoke-Command -VMName $VmName -Credential $DomCred {
    Install-WindowsFeature -Name ADCS-Cert-Authority -IncludeManagementTools | Out-Null
    Install-AdcsCertificationAuthority -CACommonName "Adatum CA" -CAType EnterpriseRootCA -Force | Out-Null
}

Write-Host -ForegroundColor DarkCyan "Install Adatum CA............................ done."

#endregion
