# Per 04.02.2019 - the Azure File Sync Agent must be installed in order for the StorageSync.Management.PowerShell.Cmdlets to be available
# Download from: https://www.microsoft.com/en-us/download/details.aspx?id=57159

# The Az PowerShell module needs to be installed in order to provision the resource group, storage account and file share needed by Azure File Sync
Install-Module -Name Az -Force

$AzureFileSyncSubscriptionId = '123456-23e3-40c5-b17e-59a82b645596'
$AzureCredential = Get-Credential
$AzureFileSyncResourceGroup = 'NIC2019-Rg'
$AzureFileSyncInstanceName = 'NIC2019'

Import-Module "C:\Program Files\Azure\StorageSyncAgent\StorageSync.Management.PowerShell.Cmdlets.dll" -WarningAction SilentlyContinue

Get-Command -Module StorageSync*

Login-AzureRmStorageSync -SubscriptionId $AzureFileSyncSubscriptionId -Credential $AzureCredential

Connect-AzAccount

Get-AzLocation | select Location 
$location = "westeurope"

$resourceGroup = 'NIC2019-Rg'
New-AzResourceGroup -Name $resourceGroup -Location $location 

New-AzStorageAccount -ResourceGroupName $resourceGroup -Name hybridfileservers -Location $location -SkuName Standard_LRS -Kind StorageV2

$StorageAccountKey = (Get-AzStorageAccountKey -Name hybridfileservers -ResourceGroupName $resourceGroup | Where-Object KeyName -eq key1).Value

$storageContext = New-AzStorageContext -StorageAccountName hybridfileservers -StorageAccountKey $StorageAccountKey
$share = New-AzStorageShare -Context $storageContext -Name nicdemodata

$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name hybridfileservers
$fileshare = Get-AzStorageShare -Context $storageContext -Name nicdemodata

$syncGroupName = 'NICDemoData'

New-AzureRmStorageSyncGroup -SyncGroupName $syncGroupName -StorageSyncService $AzureFileSyncInstanceName -ResourceGroupName $AzureFileSyncResourceGroup


# Create the cloud endpoint
New-AzureRmStorageSyncCloudEndpoint -StorageSyncServiceName $AzureFileSyncInstanceName -SyncGroupName $syncGroupName -StorageAccountResourceId $storageAccount.Id -StorageAccountShareName $fileShare.Name -ResourceGroupName $AzureFileSyncResourceGroup

$syncGroupName = 'NICDemoData'
$serverEndpointPath = "D:\NICDemoData"
$cloudTieringDesired = $false
$volumeFreeSpacePercentage = 10

$registeredServer = Get-AzureRmStorageSyncServer -StorageSyncServiceName $AzureFileSyncInstanceName -ResourceGroupName $AzureFileSyncResourceGroup | Where-Object DisplayName -eq BranchFS1.azurelab.local
$registeredServer.Id

if ($cloudTieringDesired) {
    # Ensure endpoint path is not the system volume
    $directoryRoot = [System.IO.Directory]::GetDirectoryRoot($serverEndpointPath)
    $osVolume = "$($env:SystemDrive)\"
    if ($directoryRoot -eq $osVolume) {
        throw [System.Exception]::new("Cloud tiering cannot be enabled on the system volume")
    }

    # Create server endpoint
    New-AzureRmStorageSyncServerEndpoint `
        -StorageSyncServiceName $storageSyncName `
        -SyncGroupName $syncGroupName `
        -ServerId $registeredServer.Id `
        -ServerLocalPath $serverEndpointPath `
        -CloudTiering $true `
        -VolumeFreeSpacePercent $volumeFreeSpacePercentage `
        -ResourceGroupName $AzureFileSyncResourceGroup
}
else {
    # Create server endpoint
    New-AzureRmStorageSyncServerEndpoint `
        -StorageSyncServiceName $AzureFileSyncInstanceName `
        -SyncGroupName $syncGroupName `
        -ServerId $registeredServer.Id `
        -ServerLocalPath $serverEndpointPath `
        -ResourceGroupName $AzureFileSyncResourceGroup
}
