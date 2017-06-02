## Welcome to the PWS repository!

[What is PWS?](https://www.prader-willi.de/alles-uber-pws/)

# First: Create Virtual Machines
| Role                            |        |                           | Script                                     |
|---------------------------------|--------|---------------------------|--------------------------------------------|
| Bootable VHD                    |        |                           | [Create-BootVhd.ps1](./Create-BootVhd.ps1) |
| Bare Metal Boot Configuration   |        |                           | [Create-BCD.ps1](./Create-BCD.ps1)         |
| Hyper-V Host                    |        |                           | [Create-HOST.ps1](./Create-HOST.ps1)       |
| Domain Controller               | DC1    |[README](./Create-DC1.md)  | [Create-DC1.ps1](./Create-DC1.ps1)         |
| Member Server                   | SVR1   |[README](./Create-SVR1.md) | [Create-SVR1.ps1](./Create-SVR1.ps1)       | 
| Nano Server                     | NANO1  |[README](./Create-NANO.md) | [Create-NANO1.ps1](./Create-NANO.ps1)      |
| Router                          | R1     |                           | [Create-R1.ps1](./Create-R1.ps1)           | 
| Nested Hyper-V Host             | NVHOST3|                           | [Create-NVHOST3.ps1](./Create-NVHOST3.ps1) |

# Next: Add Functionality

| Fuctionality          |            | Script                                                                 |
|-----------------------|------------|------------------------------------------------------------------------|
| Network Controller    | [README]() | [Install-NetworkController.ps1](./Install-NetworkController.ps1)       |
| Container Host        |            | [Install-ContainerHost.ps1](./Install-ContainerHost.ps1)               |
| Disaggregated Cluster |            | [Install-DisaggregatedCluster.ps1](./Install-DisaggregatedCluster.ps1) |