#region Description

  # NVHOST3
  # Server with Desktop Experience
  # Static IP address 10.70.0.33 /16
  # Member domain Adatum.com

  # Nested Virtualization

#endregion

#region Variables

# To use local variable <var> in a remote session use $Using:<var>

$Lab            = "PWS"
$LabSwitch      = "PWS"
$VmComputerName = "NVHOST3"
$IfAlias        = "Ethernet"
$IpAddress      = "10.70.0.33"
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

#region Join Domain

Invoke-Command -VMName $VmName -Credential $LocalCred {

    Add-Computer -DomainName $Using:AdDomain -Credential $Using:DomCred -Restart
    
    }

#endregion

# --------------------------------------------------------
# Achtung! NVHOST3 wurde wieder aus der Domäne entfernt!
# (Damit man die die VM besser kopieren kann.)
# --------------------------------------------------------

#region Preparing for Nested Virtualization

Stop-LabVm -VmComputerName $VmComputerName

Set-VMProcessor -VMName $VmName -ExposeVirtualizationExtensions:$true
Set-VMMemory -VMName $VmName -DynamicMemoryEnabled:$false -StartupBytes 10GB
Set-VMNetworkAdapter -VMName $VmName -MacAddressSpoofing On

Start-LabVm -VmComputerName $VmComputerName

#endregion

#region Installing Hyper-V

Invoke-Command -VMName $VmName -Credential $DomCred {
    Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart
}

Invoke-Command -VMName $VmName -Credential $DomCred {
    $NetAdapter = Get-NetAdapter
    New-VMSwitch -Name "External Network" -NetAdapterName $NetAdapter.Name
}

#endregion

#region Copy Base Vhdx and Install Module tjLabs

Invoke-Command -VMName $VmName -Credential $LocalCred {
    Enable-NetFirewallRule -Name FPS-SMB-In-TCP -Verbose
    New-Item -ItemType Directory -Path c:\Base
}

Copy-Item -Path $LabBaseGen2 -Destination "\\10.70.0.33\c$\Base\"

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

#region Install Docker

$NV3 = New-PSSession -VMName $VmName -Credential $LocalCred
Enter-PSSession -Session $NV3
# --------------  
  Install-WindowsFeature -Name Containers -IncludeManagementTools
  
  # NuGet sollte schon installiert sein:
  Get-PackageProvider -ListAvailable
  Find-PackageProvider
  Install-PackageProvider -Name DockerMsftProvider -Force
  Find-Package -ProviderName DockerMsftProvider
  Install-Package -Name Docker -Force
  
  # Das ist notwendig:
  Restart-Computer
# --------------

$NV3 = New-PSSession -VMName $VmName -Credential $LocalCred
Enter-PSSession -Session $NV3
# -------------- 
  Get-Command dockerd
  Get-Command docker
  Get-Service docker
  
  # Proxy für docker pull
  [Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://192.168.254.5:8080/", [EnvironmentVariableTarget]::Machine)
  Restart-Service -Name docker
  Exit-PSSession
# --------------
  
vmconnect localhost PWS-NVHOST3

# in einfacher PowerShell (nicht ISE!)
  docker pull microsoft/nanoserver
  docker pull microsoft/windowsservercore
  docker pull microsoft/iis

#endregion
