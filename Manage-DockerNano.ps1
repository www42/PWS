# At Nano server open firewall for docker client remote. Docker daemon is listening on port 2375
#
#   netsh advfirewall firewall add rule name="Docker daemon" dir=in action=allow protocol=TCP localport=2375

New-NetFirewallRule -Name "Allow Docker daemon" `
                    -DisplayName "Allow Docker daemon" `
                    -Direction Inbound `
                    -Action Allow `
                    -LocalPort 2375 `
                    -Protocol tcp `
                    -Profile Any

# Create Docker daemon config file
$DockerConfig = "$env:ProgramData\Docker\config\daemon.json"
New-Item -ItemType File -Path $DockerConfig

Add-Content -Path $DockerConfig -Value '{ "hosts": ["tcp://0.0.0.0:2375", "npipe://"] }'

Restart-Service -Name Docker

# Start Docker client remotely by
#   docker -H tcp://<ip>:2375 <command>
#
# or set env variable
#   $env:DOCKER_HOST = 'tcp://<ip>:2375'