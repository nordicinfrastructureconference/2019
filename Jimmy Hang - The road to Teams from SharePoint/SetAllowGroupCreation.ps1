#Group creation policy
#Run the script below to make sure only approved users may create new groups 
#https://docs.microsoft.com/en-us/office365/admin/create-groups/manage-creation-of-groups?view=o365-worldwide

$GroupName = "AllowGroupCreation"
$AllowGroupCreation = "True"

#Connect-AzureAD

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

$settingsCopy["EnableGroupCreation"] = $AllowGroupCreation

If ($GroupName -eq "")
    {
        $SettingsCopy["GroupCreationAllowedGroupId"] = ""
    }
Else
    {
        $SettingsCopy["GroupCreationAllowedGroupId"] = (Get-AzureADGroup -SearchString $GroupName).objectid
    }

Set-AzureADDirectorySetting -Id $settingsObjectID -DirectorySetting $settingsCopy

(Get-AzureADDirectorySetting -Id $settingsObjectID).Values