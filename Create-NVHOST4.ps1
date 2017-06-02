#region Description

  # NVHOST4
  # Server with Desktop Experience
  # Static IP address 10.70.0.34 /16
  # Member domain Adatum.com

  # Nested Virtualization

#endregion

#region Variables

# To use local variable <var> in a remote session use $Using:<var>

$Lab            = "PWS"
$LabSwitch      = "PWS"
$VmComputerName = "NVHOST4"
$IfAlias        = "Ethernet"
$IpAddress      = "10.70.0.34"
$PrefixLength   = "16"
$DefaultGw      = "10.70.0.1"
$DnsServer      = "10.70.0.10"
$AdDomain       = "Adatum.com"

$VmName = ConvertTo-VmName -VmComputerName $VmComputerName -Lab $Lab

$LocalCred = New-Object System.Management.Automation.PSCredential        "Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)

#endregion

#region Create VM

New-LabVmGen2Differencing -VmComputerName $VmComputerName -Lab $Lab -Switch $LabSwitch
Start-LabVm -VmComputerName $VmComputerName

# Wait for specialize and oobe to complete
Start-Sleep -Seconds 180

#endregion

#region Rename and IP configuration

Invoke-Command -VMName $VmName -Credential $LocalCred {
    New-NetIPAddress -InterfaceAlias $Using:IfAlias -IPAddress $Using:IpAddress -PrefixLength $Using:PrefixLength -DefaultGateway $Using:DefaultGw
    Set-DnsClientServerAddress -InterfaceAlias $Using:IfAlias -ServerAddresses $Using:DnsServer
    Rename-Computer -NewName $Using:VmComputerName -Restart
    }

# Wait for reboot
Start-Sleep -Seconds 60

#endregion

# kein Domain Member

#region Preparing for Nested Virtualization

Stop-LabVm -VmComputerName $VmComputerName

Set-VMProcessor -VMName $VmName -ExposeVirtualizationExtensions:$true
Set-VMMemory -VMName $VmName -DynamicMemoryEnabled:$false -StartupBytes 10GB
Set-VMNetworkAdapter -VMName $VmName -MacAddressSpoofing On

Start-LabVm -VmComputerName $VmComputerName

#endregion

#region Copy Base Vhdx and Install Module tjLabs

Invoke-Command -VMName $VmName -Credential $LocalCred {
    Enable-NetFirewallRule -Name FPS-SMB-In-TCP -Verbose
    New-Item -ItemType Directory -Path c:\Base
}

Copy-Item -Path $LabBaseGen2 -Destination "\\10.70.0.34\c$\Base\"

# ---------------------------------------------------
# Proxy manuell setzen. In IE (nicht in "Settings")!
# 192.168.254.5:8080
# ---------------------------------------------------
Invoke-Command -VMName $VmName -Credential $LocalCred {
    Install-PackageProvider -Name nuget -ForceBootstrap -Force
    $Repo = "MyGet"
    $SourceLocation  = 'https://www.myget.org/F/tj/api/v2/'
    $PublishLocation = 'https://www.myget.org/F/tj/api/v2/package/'
    Register-PSRepository -Name $Repo -SourceLocation $SourceLocation -PublishLocation $PublishLocation -InstallationPolicy Trusted
    Install-Module -Name tjLabs -Repository $Repo
}

#endregion

#region Installing Hyper-V

Invoke-Command -VMName $VmName -Credential $LocalCred {
    Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart
}

Invoke-Command -VMName $VmName -Credential $LocalCred {
    $NetAdapter = Get-NetAdapter
    New-VMSwitch -Name "External Network" -NetAdapterName $NetAdapter.Name
}

#endregion