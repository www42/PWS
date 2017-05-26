## Welcome to the PWS repository!

[What is PWS?](https://www.prader-willi.de/alles-uber-pws/)

# First: Create Virtual Machines
| Role                            |        |                           | Script                               |
|---------------------------------|--------|---------------------------|--------------------------------------|
| Domain Controller _Adatum.com_  | DC1    |[README](./Create-DC1.md)  | [Create-DC1.ps1](./Create-DC1.ps1)   |
| Member Server                   | SVR1   |[README](./Create-SVR1.md) | [Create-SVR1.ps1](./Create-SVR1.ps1) | 
| Nano Server                     | NANO11 |[README](./Create-NANO.md) | [Create-SVR1.ps1](./Create-NANO.ps1) | 

# Next: Add Functionality

| Fuctionality       |            | Script                            |
| ------------------ | ---------- | --------------------------------- |
| Network Controller | [README]() | [Install-NetworkController.ps1]() |
| Container Host     | [README]() | [Install-ContainerHost.ps1]()     |