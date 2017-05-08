
#region Description


  # SVR1
  # Server with Desktop Experience
  # Static IP address 10.70.0.21 /16
  # Member domain Adatum.com
  # 
  # Nano Server Deployment Workbench
  #   d.h. es ist allen vorhanden was man braucht, um Nano Images zu deployen
  #   C:\Nano_Workbench


#endregion

#region Variables

# To use local variable <var> in a remote session use $Using:<var>

$Lab            = "PWS"
$LabSwitch      = "PWS"
$VmComputerName = "SVR1"
$IfAlias        = "Ethernet"
$IpAddress      = "10.70.0.21"
$PrefixLength   = "16"
$DefaultGw      = "10.70.0.1"
$DnsServer      = "10.70.0.10"
$AdDomain       = "Adatum.com"

$VmName = ConvertTo-VmName -VmComputerName $VmComputerName -Lab $Lab

$LocalCred = New-Object System.Management.Automation.PSCredential        "Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)

Write-Host -ForegroundColor Cyan "Variables.................................... done."

#endregion

#region Create VM

New-LabVmGen2Differencing -VmComputerName $VmComputerName -Lab $Lab -Switch $LabSwitch
Start-LabVm -VmComputerName $VmComputerName

# Wait for specialize and oobe to complete
Start-Sleep -Seconds 180

Write-Host -ForegroundColor Cyan "Create VM.................................... done."

#endregion

#region Rename and IP configuration

Invoke-Command -VMName $VmName -Credential $LocalCred {
    New-NetIPAddress -InterfaceAlias $Using:IfAlias -IPAddress $Using:IpAddress -PrefixLength $Using:PrefixLength -DefaultGateway $Using:DefaultGw | Out-Null
    Set-DnsClientServerAddress -InterfaceAlias $Using:IfAlias -ServerAddresses $Using:DnsServer  | Out-Null
    Rename-Computer -NewName $Using:VmComputerName -Restart
    }

# Wait for reboot
Start-Sleep -Seconds 60
Write-Host -ForegroundColor Cyan "Rename and IP configuration.................. done."

#endregion

#region Join Domain

Invoke-Command -VMName $VmName -Credential $LocalCred {

    Add-Computer -DomainName $Using:AdDomain -Credential $Using:DomCred -Restart
    
    }

Start-Sleep -Seconds 60
Write-Host -ForegroundColor Cyan "Join Domain.................................. done."

#endregion

#region Create Nano Workbench

$Ws2016Iso = "D:\iso\14393.0.160715-1616.RS1_RELEASE_SERVER_EVAL_X64FRE_EN-US.ISO"
$Ws2016IsoLabel = "SSS_X64FREE_EN-US_DV9"

$DvdLw = Get-VMDvdDrive -VMName $VmName
if (-not $DvdLw) {Add-VMDvdDrive -VMName $VmName}

Set-VMDvdDrive -VMName $VmName -Path $Ws2016Iso

Invoke-Command -VMName $VmName -Credential $DomCred {

    $DvdVolume = (Get-Volume -FileSystemLabel $Using:Ws2016IsoLabel | % DriveLetter) + ':'
    
    mkdir C:\Nano_WorkBench | Out-Null
    cp $DvdVolume\NanoServer\NanoServerImageGenerator\*  C:\Nano_WorkBench

    # Einmalig ein Nano Image erzeugen, damit vom MediaPath alles kopiert wird. Das hat den Vorteil, dass man später keinen MediaPath angeben muss.
    Import-Module -Name C:\Nano_WorkBench\NanoServerImageGenerator.psd1
    New-NanoServerImage `
        -DeploymentType        Guest `
        -Edition               Datacenter `
        -BasePath              "C:\Nano_WorkBench\Base" `
        -TargetPath            "C:\Nano_WorkBench\Target\Test.vhdx" `
        -MediaPath             $DvdVolume `
        -ComputerName          "Test" `
        -AdministratorPassword (ConvertTo-SecureString -String 'Pa$$w0rd' -AsPlainText -Force) | Out-Null
   
    del C:\Nano_WorkBench\Target\Test.vhdx

    # unattend file TimeZone.xml
    $UnattendFile = "C:\Nano_WorkBench\TimeZone.xml"
    New-Item -ItemType File -Path $UnattendFile | Out-Null
    Add-Content -Path $UnattendFile -Value '<?xml version=''1.0'' encoding=''utf-8''?>'
    Add-Content -Path $UnattendFile -Value '<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    Add-Content -Path $UnattendFile -Value '  <settings pass="specialize">'
    Add-Content -Path $UnattendFile -Value '    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">'
    Add-Content -Path $UnattendFile -Value '      <TimeZone>W. Europe Standard Time</TimeZone>'
    Add-Content -Path $UnattendFile -Value '    </component>'
    Add-Content -Path $UnattendFile -Value '  </settings>'
    Add-Content -Path $UnattendFile -Value '</unattend>'
    }

Set-VMDvdDrive -VMName $VmName -Path $null

Write-Host -ForegroundColor Cyan "Create Nano Workbench........................ done."

#endregion
