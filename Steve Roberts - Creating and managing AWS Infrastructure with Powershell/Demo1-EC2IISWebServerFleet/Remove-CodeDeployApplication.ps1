<#
.Synopsis
    Removes the AWS CodeDeploy application, deployment group and any associated configuration.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact="High")]
Param
(
    # The name of the application to be deleted.
    [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
    [string]$ApplicationName
)

if (!($PSCmdlet.ShouldProcess($ApplicationName, "Delete CodeDeploy Application")))
{
    return
}

$autoDiscoveredGroupConfigNames = New-Object System.Collections.Generic.HashSet[string]

#==============================================================================
# Discover and remove the deployment groups associated with the application.
# Note that this is not an api the PowerShell tools can auto-paginate, so we
# must handle it ourselves

$nextToken = $null
do
{
    $apiResponse = Get-CDDeploymentGroupList -ApplicationName $ApplicationName
    $nextToken = $apiResponse.NextToken

    foreach ($groupName in $apiResponse.DeploymentGroups)
    {
        $group = Get-CDDeploymentGroup -ApplicationName $ApplicationName -DeploymentGroupName $groupName
        $configName = $group.DeploymentConfigName
        if (!($configName.StartsWith('CodeDeployDefault.')))
        {
            [void] $autoDiscoveredGroupConfigNames.Add($group.DeploymentConfigName)
        }

        Write-Host "...deleting deployment group $groupName."
        Remove-CDDeploymentGroup -ApplicationName $ApplicationName -DeploymentGroupName $groupName -Force > $null
    }

} while ($nextToken)

if ($autoDiscoveredGroupConfigNames.Count -gt 0)
{
    foreach ($configName in $autoDiscoveredGroupConfigNames)
    {
        Write-Host "...deleting auto-discovered custom deployment configuration $configName."
        Remove-CDDeploymentConfig -DeploymentConfigName $configName -Force
    }
}

Write-Host "...deleting application $ApplicationName."
Remove-CDApplication -ApplicationName $ApplicationName -Force
