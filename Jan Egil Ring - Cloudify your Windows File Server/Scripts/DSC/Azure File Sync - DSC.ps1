Install-Module -Name Az -Force

Connect-AzAccount
Set-AzContext -SubscriptionId 1f732d91-23e3-40c5-b17e-59a82b645596

Import-Module Az.Automation

$PSDefaultParameterValues = @{
  "*AzAutomation*:ResourceGroupName" = 'West-Europe-Management'
  "*AzAutomation*:AutomationAccountName" = 'Automation-West-Europe'
}

# HybridFileServers - import configuration to Azure Automation
$SourcePath = '.\AzureFileSyncAgent\HybridFileServer.ps1'
Import-AzAutomationDscConfiguration -SourcePath $SourcePath -Force -Published -Tags @{Source='Git'}

# HybridFileServers - compile configuration in Azure Automation
$ConfigurationData = Import-PowerShellDataFile -Path '.\AzureFileSyncAgent\HybridFileServer_Configuration_Data.psd1'
$CompilationJob = Start-AzAutomationDscCompilationJob -ConfigurationName HybridFileServer -ConfigurationData $ConfigurationData


#region DSC LCM

$LCMComputerName = 'BranchFS1'
$NodeConfigurationName = 'HybridFileServer.BranchFS1'
$DSCMOFDirectory = 'C:\temp\AzureAutomationDscMetaConfiguration'

# Create the metaconfigurations
$Params = @{
  RegistrationUrl = 'https://we-agentservice-prod-1.azure-automation.net/accounts/a8072ea5-60ec-4209-b9b0-64c519efbc73';
  RegistrationKey = '1234567W+enQyQXHd9cKX9/FI8WOZgumoQC5ks+jXo/TBwOjxeW1k2gQywhiPHNoDUiMf6abcde';
  ComputerName = @($LCMComputerName);
  NodeConfigurationName = $NodeConfigurationName;
  RefreshFrequencyMins = 720;
  ConfigurationModeFrequencyMins = 360;
  RebootNodeIfNeeded = $False;
  AllowModuleOverwrite = $True;
  ConfigurationMode = 'ApplyAndAutoCorrect';
  ActionAfterReboot = 'ContinueConfiguration';
  ReportOnly = $False;  # Set to $True to have machines only report to AA DSC but not pull from it
  OutputPath = $DSCMOFDirectory
}

. '.\AzureAutomationDscMetaConfiguration.ps1'

AzureAutomationDscMetaConfiguration @Params

$LCMComputerName = $env:COMPUTERNAME
$DSCMOFDirectory = 'C:\temp\AzureAutomationDscMetaConfiguration'

Set-DscLocalConfigurationManager -Path $DSCMOFDirectory -ComputerName $LCMComputerName -Force

Update-DscConfiguration -Wait -Verbose -CimSession $LCMComputerName

Get-DscLocalConfigurationManager -CimSession $LCMComputerName

#endregion