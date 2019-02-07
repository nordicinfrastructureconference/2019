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
            AzureFileSyncGroup = 'NICDemoData'
            AzureFileSyncServerEndpointLocalPath = 'D:\NICDemoData'
            AzureFileSyncCloudTiering = $true
            AzureFileSyncTierFilesOlderThanDays = 365
        },
        @{
            NodeName = 'ClusterFS'
        }
    )
}
