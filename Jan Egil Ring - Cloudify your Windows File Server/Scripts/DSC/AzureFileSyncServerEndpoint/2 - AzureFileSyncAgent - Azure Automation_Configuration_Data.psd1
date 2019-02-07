$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName                    = '*'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true
            NodeType                    = 'HybridFileServer'
        },
        @{
            NodeName = 'BranchFS'
            AzureFileSyncGroup = 'DemoData'
            AzureFileSyncServerEndpointLocalPath = 'D:\DemoData'
            AzureFileSyncCloudTiering = $true
            AzureFileSyncTierFilesOlderThanDays = 365
        },
        @{
            NodeName = 'ClusterFS'
        }
    )
}
