#By default if enabled Guest access will be ON for all Teams
#Follow the steps below to turn Guest Access ON/OFF for selected teams
#Tenant and Group details

$tenantId = "TenantID"
$groupName = "Contract Management"


#Connect to Exchange and Azure AD
$cred = Get-Credential
$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $cred -Authentication Basic -AllowRedirection
Import-PSSession $session
Connect-AzureAD -TenantId $tenantId -Credential $cred

#Turn OFF guest access
$template = Get-AzureADDirectorySettingTemplate | ? {$_.displayname -eq "group.unified.guest"}
$settingsCopy = $template.CreateDirectorySetting()
$settingsCopy["AllowToAddGuests"]=$False

$groupID= (Get-AzureADGroup -SearchString $groupName).ObjectId
New-AzureADObjectSetting -TargetType Groups -TargetObjectId $groupID -DirectorySetting $settingsCopy

#Verify settings
Get-AzureADObjectSetting -TargetObjectId $groupID -TargetType Groups | Format-List Values


######
#Turn ON guest access
#Remove current setting
$groupID = (Get-AzureADGroup -SearchString $groupName).ObjectId
$settingId = (Get-AzureADObjectSetting -TargetObjectId $groupID -TargetType Groups).Id
Remove-AzureADObjectSetting -TargetType Groups -TargetObjectId $groupID -Id $settingId

#Verify settings | it should be empty
Get-AzureADObjectSetting -TargetObjectId $groupID -TargetType Groups | fl Values

#Alternatively you can add a new template with AllowToAddGuest = true
$template = Get-AzureADDirectorySettingTemplate | ? {$_.displayname -eq "group.unified.guest"}
$settingsCopy = $template.CreateDirectorySetting()
$settingsCopy["AllowToAddGuests"]=$True

$groupID= (Get-AzureADGroup -SearchString $groupName).ObjectId
New-AzureADObjectSetting -TargetType Groups -TargetObjectId $groupID -DirectorySetting $settingsCopy

#Verify settings
Get-AzureADObjectSetting -TargetObjectId $groupID -TargetType Groups | Format-List Values

