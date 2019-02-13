#Set Office 365 Groups Naming Prefix, Suffix
#https://docs.microsoft.com/en-us/office365/admin/create-groups/groups-naming-policy?view=o365-worldwide
#verify that you have AzureADPreview module installed: Install-Module AzureADPreview
#Global Admins, Partner Tier 1 Support, Partner Tier 2 Support, User account admin, Directory writers are exempted from the policy

Import-Module AzureADPreview
Connect-AzureAD

#verify current settings
$Setting = Get-AzureADDirectorySetting -Id (Get-AzureADDirectorySetting | Where-Object -Property DisplayName -Value "Group.Unified" -EQ).id
$Setting.Values


#Add blockedwords and prefix
$BlockedWords = "Payroll,CEO,HR,IT"

$PrefixSuffix = "GRP_[GroupName]"

try
{
    $template = Get-AzureADDirectorySettingTemplate | ? {$_.displayname -eq "group.unified"}
    $settingsCopy = $template.CreateDirectorySetting()
    New-AzureADDirectorySetting -DirectorySetting $settingsCopy
    $settingsObjectID = (Get-AzureADDirectorySetting | Where-object -Property Displayname -Value "Group.Unified" -EQ).id
}
catch
{
    $settingsObjectID = (Get-AzureADDirectorySetting | Where-object -Property Displayname -Value "Group.Unified" -EQ).id       
}

$settingsCopy = Get-AzureADDirectorySetting -Id $settingsObjectID

$SettingsCopy["PrefixSuffixNamingRequirement"] = $PrefixSuffix

$SettingsCopy["CustomBlockedWordsList"] = $BlockedWords

Set-AzureADDirectorySetting -Id $settingsObjectID -DirectorySetting $settingsCopy

(Get-AzureADDirectorySetting -Id $settingsObjectID).Values