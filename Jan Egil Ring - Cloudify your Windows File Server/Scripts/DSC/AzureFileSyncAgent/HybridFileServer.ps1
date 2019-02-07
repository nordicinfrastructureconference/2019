Configuration HybridFileServer
{
    $FileSyncPackageLocalPath = "C:\Windows\Temp\StorageSyncAgent.msi"
    $AzureFileSyncSubscriptionId = Get-AutomationVariable -Name "AzureFileSyncSubscriptionId"
    $AzureFileSyncResourceGroup = Get-AutomationVariable -Name "AzureFileSyncResourceGroup"
    $AzureFileSyncInstanceName = Get-AutomationVariable -Name "AzureFileSyncInstanceName"
    $AzureCredential = Get-AutomationPSCredential -Name "AzureFileSyncNodeRegistration"

    Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 8.4.0.0
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName PackageManagement -ModuleVersion 1.3.1
    Import-DscResource -ModuleName AzureFileSyncDsc -ModuleVersion 1.0.0.3
    Import-DscResource -ModuleName StorageDsc -ModuleVersion 4.4.0.0

    Node $AllNodes.Where{$PSItem.NodeType -eq 'HybridFileServer'}.NodeName {

        Service FileSyncService
        {
            Name = "FileSyncSvc"
            State = "Running"
            DependsOn = "[Package]FileSync"
        }

        xRemoteFile FileSyncPackage {
            Uri = "https://download.microsoft.com/download/1/8/D/18DC8184-E7E2-45EF-823F-F8A36B9FF240/StorageSyncAgent_V4_WS2019.msi"
            DestinationPath = $FileSyncPackageLocalPath
        }

        Package FileSync {
            Ensure = "Present"
            Path  = $FileSyncPackageLocalPath
            Name = "Storage Sync Agent"
            ProductId = "F5EA481D-EECC-4AA8-B62D-108001DA2462"
            Arguments = '/quiet'
            DependsOn = "[xRemoteFile]FileSyncPackage"
        }

        PackageManagement AzureRMPowerShellModule {

			Name = 'AzureRM'
			ProviderName = 'PowerShellGet'
			RequiredVersion = '6.13.1'
            Source = 'PSGallery'
            DependsOn = "[Package]FileSync"

        }

        AzureFileSyncAgent Registration {

            AzureSubscriptionId = $AzureFileSyncSubscriptionId
            AzureFileSyncResourceGroup = $AzureFileSyncResourceGroup
            AzureFileSyncInstanceName = $AzureFileSyncInstanceName
            AzureCredential = $AzureCredential
            DependsOn = '[Service]FileSyncService'

        }

        if ($NodeName -like "BranchFS*") {

        WaitForDisk Disk1
        {
             DiskId = 1
             RetryIntervalSec = 60
             RetryCount = 60
             DependsOn = '[AzureFileSyncAgent]Registration'
        }

        Disk DVolume
        {
             DiskId = 1
             DriveLetter = 'D'
             Size = 100GB
             DependsOn = '[WaitForDisk]Disk1'
        }

        File DirectoryDemoData
        {
            Ensure = "Present" # Ensure the directory is Present on the target node.
            Type = "Directory" # The default is File.
            DestinationPath = "D:\NICDemoData"
            DependsOn = '[Disk]DVolume'
        }

        AzureFileSyncServerEndpoint DemoData {

            AzureSubscriptionId = $AzureFileSyncSubscriptionId
            AzureFileSyncResourceGroup = $AzureFileSyncResourceGroup
            AzureFileSyncInstanceName = $AzureFileSyncInstanceName
            AzureFileSyncGroup = $node.AzureFileSyncGroup
            AzureCredential = $AzureCredential
            ServerLocalPath = $Node.AzureFileSyncServerEndpointLocalPath
            CloudTiering = $node.AzureFileSyncCloudTiering
            TierFilesOlderThanDays = $node.AzureFileSyncTierFilesOlderThanDays
            DependsOn = '[File]DirectoryDemoData'

        }

      }

    }
}
