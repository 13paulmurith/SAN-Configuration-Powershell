#Name the Machine and join it to your domain
#Credits Paul MURITH 
#ISCSI Target are identified by IP

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
$i=1
$ArrayNetAdapter = "Ethernet","Eternet 2"
$ArrayNewNetAdapter = @()
foreach ($Adapter in $ArrayNetAdapter)
{
    Rename-NetAdapter -Name $Adapter -NewName "LAN$i"
    $ArrayNewNetAdapter += 'LAN'+$i 
    $i++
}
$TeamingNetAdapter = $ArrayNewNetAdapter -join ','
New-NetlbfoTeam -Name StorageAgregat -TeamMembers $TeamingNetAdapter -TeamingMode SwitchIndependent -Confirm $true
Install-WindowsFeature -Name FS-iSCSITarget-Server -IncludeAllSubFeature -IncludeManagementTools
$PhysicalDisksCanPool = (Get-PhysicalDisk -CanPool $True)
New-StoragePool -FriendlyName STORAGE_POOL1 -StorageSubsystemFriendlyName "Windows Storage*" -PhysicalDisks $PhysicalDisksCanPool -ResiliencySettingNameDefault Simple -ProvisioningTypeDefault Thin -Verbose
New-VirtualDisk -StoragePoolFriendlyName "STORAGE_POOL1" -FriendlyName QUORUM_2 -Size 8GB -ProvisioningType Fixed -ResiliencySettingName "Simple"
New-VirtualDisk -StoragePoolFriendlyName "STORAGE_POOL1" -FriendlyName VMDATA_2 -Size 20GB -ProvisioningType Fixed -ResiliencySettingName "Simple"
$DiskVM = (Get-Disk -FriendlyName VMDATA_2).Number
$DiskQuorum =(Get-Disk -FriendlyName QUORUM_2).Number
Set-Disk -Number $DiskVM -isOffline $false | Initialize-Disk -VirtualDisk (Get-VirtualDisk -FriendlyName VMDATA)
Set-Disk -Number $DiskQuorum -isOffline $false | Initialize-Disk -VirtualDisk (Get-VirtualDisk -FriendlyName QUORUM)
New-Partition -DiskNumber $DiskVM -DriveLetter F -UseMaximumSize 
Format-Volume -DriveLetter F -FileSystem NTFS 
Set-Volume -DriveLetter F -NewFileSystemLabel VM_DATA
New-Partition -DiskNumber $DiskQuorum -DriveLetter Q -UseMaximumSize 
Format-Volume -DriveLetter Q -FileSystemLabel NTFS 
Set-Volume -DriveLetter Q -NewFileSystemLabel QUORUM
New-IscsiVirtualDisk -UseFixed -Path "F:\DATA_VM.vhdx" -Size 7GB
New-IscsiVirtualDisk -UseFixed -Path "Q:\QUORUM.vhdx" -Size 19GB
New-IscsiServerTarget -TargetName targetCluster -InitiatorId IPAddress:172.168.100.20,IPAddress:172.168.100.30
Add-IscsiVirtualDiskTargetMapping -TargetName targetCluster -Path F:\DATA_VM.vhdx 
Add-IscsiVirtualDiskTargetMapping -TargetName targetCluster -Path Q:\QUORUM.vhdx