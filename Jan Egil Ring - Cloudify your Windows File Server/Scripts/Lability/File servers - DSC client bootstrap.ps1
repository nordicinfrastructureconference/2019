# Script to configure the Desired State Configuration client (LCM) in pull mode against Azure Automation DSC
# See the following article for information about how to generate the MOF-files:
# https://docs.microsoft.com/en-us/azure/automation/automation-dsc-onboarding#generating-dsc-metaconfigurations

# BRANCHFS01

$LCMComputerName = $env:COMPUTERNAME
$DSCMOFDirectory = 'C:\BootStrap\AzureAutomationDscMetaConfiguration'

Set-DscLocalConfigurationManager -Path $DSCMOFDirectory -ComputerName $LCMComputerName -Force

Update-DscConfiguration -Verbose -Wait

# Cluster nodes

$LCMComputerName = 'FS1','FS2'
$DSCMOFDirectory = 'C:\BootStrap\AzureAutomationDscMetaConfiguration'

Set-DscLocalConfigurationManager -Path $DSCMOFDirectory -ComputerName $LCMComputerName -Force

Update-DscConfiguration -Verbose -Wait -ComputerName $LCMComputerName
