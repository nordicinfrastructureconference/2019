@{
    AllNodes = @(
        @{
            NodeName = '*';
            InterfaceAlias = 'Ethernet';
            DefaultGateway = '192.168.147.97';
            #SubnetMask = '24';
            AddressFamily = 'IPv4';
            DnsServerAddress = '192.168.147.100';
            DomainName = 'azurelab.local';
            PSDscAllowPlainTextPassword = $true;
            CertificateFile = "C:\ProgramData\Lability\Certificates\LabClient.cer";
            Thumbprint = '5940D7352AB397BFB2F37856AA062BB471B43E5E';
            PSDscAllowDomainUser = $true; # Removes 'It is not recommended to use domain credential for node X' messages
            #Lability_SwitchName = 'Default Switch';
            Lability_SwitchName = 'nat';
            Lability_ProcessorCount = 2;
            Lability_StartupMemory = 2GB;
            Lability_Media = '2019_x64_Standard_EN_Eval';
        }
        @{
            NodeName = 'DC1';
            IPAddress = '192.168.147.100/28';
            DnsServerAddress = '127.0.0.1';
            Role = 'DC';
            Lability_ProcessorCount = 2;
        }
                @{
            NodeName = 'FS1';
            IPAddress = '192.168.147.101/28';
            Role = 'ClusteredFileServer';
            Lability_ProcessorCount = 2;
            Lability_Media = '2019_x64_Standard_EN_Core_Eval';
        },
        @{
            NodeName = 'FS2';
            IPAddress = '192.168.147.102/28';
            Role = 'ClusteredFileServer';
            Lability_ProcessorCount = 2;
            Lability_Media = '2019_x64_Standard_EN_Core_Eval';
        },
        @{
            NodeName = 'BranchFS1';
            IPAddress = '192.168.147.103/28';
            Role = 'FileServer';
            Lability_ProcessorCount = 2;
            Lability_HardDiskDrive   = @(
                ## Lability can create one or more empty VHDs. You can pass any parameter
                ##   supported by the xVHD resource (https://github.com/PowerShell/xHyper-V#xvhd)
                @{
                    ## Specifies the type of virtual hard disk file. Supported values are 'VHD' or 'VHDX'
                    Generation = 'VHDX';
                    ## Specifies the maximum size of the VHD.
                    MaximumSizeBytes = 101GB;
                }
            )
        }
    );
    NonNodeData = @{
        Lability = @{
            EnvironmentPrefix = 'Azure File Sync - ';
            Media = @();
            Network = @(
                @{ Name = 'Lability'; Type = 'Internal'; }
            );
            DSCResource = @(
                ## Download published version from the PowerShell Gallery
                @{ Name = 'xComputerManagement'; MinimumVersion = '1.3.0.0'; Provider = 'PSGallery'; }
                ## If not specified, the provider defaults to the PSGallery.
                @{ Name = 'xSmbShare'; MinimumVersion = '1.1.0.0'; }
                @{ Name = 'xNetworking'; MinimumVersion = '2.7.0.0'; }
                @{ Name = 'xActiveDirectory'; MinimumVersion = '2.9.0.0'; }
                @{ Name = 'xDnsServer'; MinimumVersion = '1.5.0.0'; }
                @{ Name = 'xDhcpServer'; MinimumVersion = '1.3.0.0'; }
                @{ Name = 'xPendingReboot' }
                ## The 'GitHub# provider can download modules directly from a GitHub repository, for example:
                ## @{ Name = 'Lability'; Provider = 'GitHub'; Owner = 'VirtualEngine'; Repository = 'Lability'; Branch = 'dev'; }
            );
        };
    };
};