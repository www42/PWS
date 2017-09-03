$VmName          = "HDP-R1"
$Dir             = "C:\Labs\HDP"
$Switch_Private  = "HDP"
$Switch_External = "External Network"
$VyosTemplate    = "C:\Base\vyos-999.201703132237-amd64.vhd"

$VmDir   = Join-Path $Dir $VmName
$VhdDir  = Join-Path $VmDir  "Virtual Hard Disks"
$VhdPath = Join-Path $VhdDir "$VmName.vhd"

New-Item -Path $VhdDir -ItemType Directory | Out-Null
Copy-Item -Path $VyosTemplate -Destination $VhdPath 
New-VM -Name $VmName -Path $Dir -VHDPath $VhdPath -MemoryStartupBytes 512MB | Out-Null
Remove-VMNetworkAdapter -VMName $VmName
Add-VMNetworkAdapter -VMName $VmName -Name "Private"  -SwitchName $Switch_Private
Add-VMNetworkAdapter -VMName $VmName -Name "External" -SwitchName $Switch_External

Start-VM -Name $VmName
vmconnect.exe localhost $VmName

# login: vyos
# Password: Pa55w.rd
#
# # Hint: Use Tab completion
#
# show interfaces
# show ip route
# show host lookup google.com
# ping google.com    # Ctl-C to stop
#
#
# # Two ways to change ip address of eth0
# # -------------------------------------
#
# # a) Edit config file
#      vi /config/config.boot
#      reboot now
#
# # b) Use config mode
#      config
#         delete interfaces ethernet eth0 address 172.16.0.1/16
#         set interfaces ethernet eth0 address 10.0.0.1/24
#         set nat source rule 100 source address 10.0.0.0/24
#         commit
#         save
#         exit
#      reboot now
# 
# poweroff now

Export-VM -Name $VmName -Path C:\Transfer\VMs