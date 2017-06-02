# https://gist.github.com/stknohg/4a2f1f46946a863807e3706a0e90b1ae
$dockers = Invoke-RestMethod -Uri 'https://go.microsoft.com/fwlink/?LinkID=825636&clcid=0x409'
$dockers.versions.$($dockers.channels.edge.version)

$DockerUrl = ($dockers.versions.$($dockers.channels.edge.version)).url

Start-BitsTransfer -Source $DockerUrl -Destination /docker.zip
Get-FileHash -Path /docker.zip -Algorithm SHA256
Expand-Archive -Path /docker.zip -DestinationPath $env:ProgramFiles
$env:Path += ";C:\Program Files\docker" 
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\docker", [EnvironmentVariableTarget]::Machine)
dockerd.exe --register-service  
Start-Service -Name docker
Get-Service -Name docker | ft Name,DisplayName,Status,StartType

Restart-Computer
