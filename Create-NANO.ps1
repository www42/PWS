
#region Description


#  NANO - Nano Server
#  ------------------
#    
#  Es wird eine VM Gen. 2 erzeugt in zwei Schritten:
#  
#      Schritt 1: Auf SVR1 wird die vhdx-Datei für die Nano-VM erzeugt.
#  
#      Schritt 2: Die vhdx-Datei wird von SVR1 auf den Hyper-V Host kopiert und in eine VM eingebunden.
#  
#  Die Nano-Server 
#      - haben statische IP Adressen
#      - sind Domain-Member (Adatum.com)
#      - haben die korrekte Zeitzone durch eine Antwort-Datei (TimeZone.xml)


#endregion

[string]$NanoComputerName   = "NANO1"
[string]$NanoIPv4Address    = "10.70.17.1"

#region Variables

# To use local variable <var> in a remote session use $Using:<var>

$Lab = "PWS"
$ServerComputerName = "SVR1"
$serverVmName = ConvertTo-VmName -VmComputerName $ServerComputerName -Lab $Lab

$LocalCred = New-Object System.Management.Automation.PSCredential        "Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)

Write-Host -ForegroundColor DarkCyan "Variables.................................... done."

#endregion

#region More Nano Variables

# Achtung! Es wird ein Nano Image für eine Generation 2 VM erzeugt. (Man achte auf das "x" in "NANO1.vhdx")
# Achtung! Angabe vom -MediaPath ist nicht nötig, ist schon auf der Workbench erzeugt worden.
# -------------------------------------------------------------------------------
[string]$NanoRootPath       = "C:\Nano_WorkBench"
[string]$NanoBasePath       = "$NanoRootPath\Base"
[string]$NanoTargetPath     = "$NanoRootPath\Target\$NanoComputerName.vhdx"
[string]$NanoDeploymentType = "Guest"
[string]$NanoEdition        = "Datacenter"
[string]$NanoUnattendPath   = "$NanoRootPath\TimeZone.xml"
[string]$NanoInterface      = "Ethernet"
[string]$NanoIpv4SubnetMask = "255.255.0.0"
[string]$NanoIpv4Gateway    = "10.70.0.1"
[string]$NanoIpv4Dns        = "10.70.0.10"
[string]$NanoDomainName     = "Adatum.com"
[long]  $NanoMem            = 1GB
[long]  $NanoProcessorCount = 1
[securestring]$NanoPw       = ConvertTo-SecureString -String 'Pa$$w0rd' -AsPlainText -Force

Write-Host -ForegroundColor DarkCyan "More Nano Variables.......................... done."

#endregion

#region Step 1: Generate Nano Image

Invoke-Command -VMName $ServerVmName -Credential $DomCred {

    Import-Module -Name $Using:NanoRootPath\NanoServerImageGenerator.psd1

    New-NanoServerImage `
        -DeploymentType        $Using:NanoDeploymentType `
        -Edition               $Using:NanoEdition `
        -BasePath              $Using:NanoBasePath `
        -TargetPath            $Using:NanoTargetPath `
        -ComputerName          $Using:NanoComputerName `
        -AdministratorPassword $Using:NanoPw `
        -InterfaceNameOrIndex  $Using:NanoInterface `
        -Ipv4Address           $Using:NanoIPv4Address `
        -Ipv4SubnetMask        $Using:NanoIpv4SubnetMask `
        -Ipv4Gateway           $Using:NanoIpv4Gateway `
        -Ipv4Dns               $Using:NanoIpv4Dns `
        -DomainName            $Using:NanoDomainName `
        -UnattendPath          $Using:NanoUnattendPath `
        | Out-Null
}

Write-Host -ForegroundColor DarkCyan "Step 1: Generate Nano Image.................. done."

#endregion

#region Step 2: Deploy Nano VM

# VM NANO1 anlegen
New-LabVmGen2 -VmComputerName $NanoComputerName -Count $NanoProcessorCount -Mem $NanoMem

# Die VM NANO1 hat schon eine vhdx, aber leer
$NanoVmName = ConvertTo-VmName -VmComputerName $NanoComputerName -Lab $Lab
$DestinationFile = Get-VM $NanoVmName | % HardDrives | % Path
# Diese vhdx muß jetzt ersetzt werden durch das NANO Image

# Kopieren über das Netzwerk (Kopieren mit PowerShell Direct dauert zu lange)
# Namensauflösung sollte über ../etc/hosts funktionieren
# Resolve-DnsName -Name $NanoComputerName

$TempSession = New-PSSession -ComputerName $ServerComputerName -Credential $DomCred

Copy-Item -FromSession $TempSession -Path $NanoTargetPath -Destination $DestinationFile 

Remove-PSSession -Session $TempSession

Write-Host -ForegroundColor DarkCyan "Step 2: Deploy Nano VM....................... done."

#endregion

#region Optional: Update Nano - about 20 min

Start-LabVm -VmComputerName $NanoComputerName
Start-Sleep -Seconds 10

Invoke-Command -VMName $NanoVmName -Credential $DomCred {
  $ci = New-CimInstance -Namespace root/Microsoft/Windows/WindowsUpdate -ClassName MSFT_WUOperationsSession
  Invoke-CimMethod -InputObject $ci -MethodName ApplyApplicableUpdates | Out-Null
  Restart-Computer
}

Start-Sleep -Seconds 120

# Get a list of installed updates
Invoke-Command -VMName $NanoVmName -Credential $DomCred {
  $ci = New-CimInstance -Namespace root/Microsoft/Windows/WindowsUpdate -ClassName MSFT_WUOperationsSession
  $Result = Invoke-CimMethod -InputObject $ci -MethodName ScanForUpdates -Arguments @{SearchCriteria="IsInstalled=1";OnlineScan=$true}
  $Result.Updates.Title
}

Write-Host -ForegroundColor DarkCyan "Optional: Update Nano - about 20 min......... done."


#endregion