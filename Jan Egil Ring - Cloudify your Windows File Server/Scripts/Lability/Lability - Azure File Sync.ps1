# http://www.powershell.no/hyper-v,/powershell/dsc/2017/07/19/lability.html

# The easiest way to install Lability is to leverage PowerShellGet
Find-Module -Name Lability |
Install-Module

# One advantage of doing so is that Update-Module makes it very convenient to update to the latest version at a later point in time
Update-Module -Name Lability

# Explore available commands
Get-Command -Module Lability

# Explore help files (highly recommended)
Get-Help about_Lability
Get-Help about_ConfigurationData

# Explore lab media registered in Lability (use Register-LabMedia to add custom media)
Get-LabMedia | Format-Table ImageName,Id

# Inspect current configuration (settings for specifying where Lability should store VHDX/ISO-files, PowerShell DSC modules and so on)
Get-LabHostConfiguration
Get-LabHostDefault

# Configure host. A best practice is to move VHDX/ISO files to a separate data disk of possible, especially if running the host in Azure.
$LabHostParameters = @{
    ParentVhdPath = 'E:\Lability\MasterVirtualHardDisks'
    DifferencingVhdPath = 'E:\Lability\VMVirtualHardDisks'
    IsoPath = 'E:\Lability\ISOs'
    ConfigurationPath = 'E:\Lability\Configurations'
    HotfixPath = 'E:\Lability\Hotfixes'
    ResourcePath = 'E:\Lability\Resources'
    ModuleCachePath = 'E:\Lability\Modules'
}

Set-LabHostDefault @LabHostParameters

# Configure the host according to the configuration. This will also enable the Hyper-V role if it`s not already installed.
Start-LabHostConfiguration -Verbose

# Verify that the host configuration is correct
Test-LabHostConfiguration -Verbose

# Inspect current default configuration for new lab VMs
Get-LabVMDefault

# Configure custom default configuration for new lab VMs
$LabDefaultVMParameters = @{
    InputLocale = 'nb-NO'
    SystemLocale = 'nb-NO'
    ProcessorCount = '2'
    StartupMemory = '2147483648'
    RegisteredOwner = 'Your Name'
    TimeZone = 'W. Europe Standard Time'
    SwitchName = 'NAT'
}

Set-LabVMDefault @LabDefaultVMParameters

# Inspect current Hyper-V virtual switches
Get-VMSwitch

# If necessary, create a new virtual switch. This is an example of creating an Internal switch which uses NAT for external VM connectivity:

New-VMSwitch -Name 'NAT' -SwitchType Internal

$NICAlias = (Get-NetAdapter 'vEthernet (NAT)').Name
New-NetIPAddress -IPAddress 10.0.3.1 -PrefixLength 24 -InterfaceAlias $NICAlias
New-NetNAT -Name NATNetwork -InternalIPInterfaceAddressPrefix 10.0.3.0/24

# Makes Lability not create a new virtual switch prefixed with the environment name (i.e. Azure File Sync) - useful if you want to leverage your own NAT switch
Set-LabHostDefault -DisableSwitchEnvironmentName

# Azure File Sync lab

$DSCConfigurationDataPath = "C:\Labs\Lability - Azure File Sync\AzureFileSyncLabConfig.psd1"
$LabilityConfigurationDataPath = "C:\Labs\Lability - Azure File Sync\Lability - Azure File Sync\AzureFileSyncLabConfig.psd1"

# Dot source DSC configuration
. $DSCConfigurationPath

$Credential = Get-Credential -UserName administrator -Message 'Specify credential for lab environment'

AzureFileSyncServerConfiguration -OutputPath C:\Lability\Configurations -ConfigurationData $DSCConfigurationDataPath -Credential $Credential

Start-LabConfiguration -ConfigurationData $LabilityConfigurationDataPath -Credential $Credential -Verbose

Start-Lab -ConfigurationData $LabilityConfigurationDataPath

Checkpoint-Lab -ConfigurationData $LabilityConfigurationDataPath -SnapshotName "Initial setup - $(Get-Date)"
Checkpoint-Lab -ConfigurationData $LabilityConfigurationDataPath -SnapshotName "Injected scripts, Chrome and WAC - $(Get-Date)"
Checkpoint-Lab -ConfigurationData $LabilityConfigurationDataPath -SnapshotName "Configured cluster and DFS - $(Get-Date)"
Checkpoint-Lab -ConfigurationData $LabilityConfigurationDataPath -SnapshotName "Installed AzureRM module - $(Get-Date)"

Restore-Lab -ConfigurationData $LabilityConfigurationDataPath -SnapshotName 'Installed AzureRM module - 01/23/2019 17:50:45'

Stop-Lab -ConfigurationData $LabilityConfigurationDataPath

Remove-LabConfiguration -ConfigurationData $LabilityConfigurationDataPath

#endregion