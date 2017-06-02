
#region Description

<#
Create Hyper-V Host from scratch
--------------------------------
- Der PC wird mit PE gebootet (USB Stick, Zalman, etc.)

- Es wird die vorhandene Partitionierung des PCs weiter benutzt (spart Zeit). Es wird lediglich neu formatiert.

  Die vorhandene Partitionierung auf dem PC kann unterschiedlich sein:

  Fall 1  Auf dem PC ist eine Partition vorhanden (> 20 GB).
  
  Fall 2  Auf dem PC sind zwei Partitionen vorhanden (eine kleine Partition [350 MB] und eine große Partition [> 20 GB].

  Fall 3  Auf dem PC sind keine Partitionen vorhanden.


- Eine bootbare VHD (foo.vhd  - muss vorher erzeugt worden sein) wird vom PE-Medium (Laufwerk G:) kopiert
  und in die BCD eingetragen.

#>
#endregion

#region Create BCD

<#

PE booten (evtl. F12)
----------------------

G:   ist das PE Laufwerk, dort liegt die zu bootende vhd-Datei
     (Die zu bootende vhd-Datei wird von G: nach M: kopiert.)
     G: ist nur ein Beispiel, es kann auch F: oder H: sein
     diskpart list volume

M:   ist eine große (> 20 GB), frisch formatierte NTFS Partition auf dem PC

W:   ist die Windows-Partition aus der zu bootenden vhd-Datei

Press F12 to select boot device
    ZALMAN ZM-VE350 1060
 -> ZALMAN Virtual CD 3E40 1060

a) Diskpart, um (vorhandene) Partition auf PC neu zu formatieren
-----------------------------------------------------------------
diskpart
	list disk
	select disk 0
	list partition
	select partition 1        oder 2 je nach Fall, siehe region Description, Es muß die große Partition sein.
	format fs=ntfs quick
	assign letter=M
	list volume
	exit



b) vhd-Datei kopieren
---------------------
mkdir M:\BootVhd
copy G:\BootVhd\BootVhd_WS2016__B__with-drivers-sysprepped_v0.3.vhd   M:\BootVhd\WS2016.vhd     (G:  ist das PE Laufwerk)



c) Diskpart, um Windows Partition aus der vhd-Datei zu mounten
---------------------------------------------------------------
diskpart
	select vdisk file=M:\BootVhd\WS2016.vhd
	attach vdisk
	list disk
	select disk 2
	list partition
	select partition 2
	assign letter=W
	exit


d) Windows aus der vhd-Datei in die BCD eintagen
------------------------------------------------
bcdboot W:\Windows


    Fall 3 - kein System Store vorhanden:
        mkdir M:\Boot
        bcdedit /createstore M:\Boot\BCD
        bcdedit /import M:\Boot\BCD


#>

#endregion
