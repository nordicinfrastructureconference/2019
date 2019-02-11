# Connect to SkypeOnline
$Session = New-CsOnlineSession

# Import the session
Import-PSSession $Session

# Take a look at new available teams cmdlets
gcm *Teams*

# Take a look at TeamsUpgradePolicy
Get-CsTeamsUpgradePolicy

# Get User Settings
Get-CsOnlineUser summer.smith@hangconsult.net | Select-Object Teams*

# Grant the policy we want
Grant-CsTeamsUpgradePolicy Summer.smith@hangconsult.net -PolicyName "SfBWithTeamsCollabWithNotify"

# Get User Settings
Get-CsOnlineUser summer.smith@hangconsult.net | Select-Object Teams*

# Enterprise Voice
cls

# Enterprise Voice
 Get-CsTeamsInteropPolicy
