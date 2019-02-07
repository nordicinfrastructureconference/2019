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

    Node 'HybridFileServer' {

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
