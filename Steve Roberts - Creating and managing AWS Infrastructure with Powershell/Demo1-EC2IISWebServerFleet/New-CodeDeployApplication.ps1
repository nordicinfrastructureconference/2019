<#
.Synopsis
    Sets up an AWS CodeDeploy application and deployment group infrastructure to target
    EC2 instances managed in an Auto Scaling group.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact="Medium")]
Param
(
    # The name of the CodeDeploy application to create.
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ApplicationName,

    # The name of the auto scaling group containing the EC2 instances to target
    # for deployment.
    [Parameter(Mandatory=$true, Position=1)]
    [string]$AutoScalingGroupName,

    # The name of the service role that allows AWS CodeDeploy to act on the user's
    # behalf when interacting with AWS services. The Amazon Resource Name (ARN)
    # corresponding to the role name will be discovered automatically.
    [Parameter(Mandatory=$true, Position=2)]
    [string]$ServiceRoleName
)

if (!($PSCmdlet.ShouldProcess($ApplicationName, "Create CodeDeploy application and deployment group targeting Auto Scaling group $AutoScalingGroup")))
{
    return
}

#==============================================================================
# Validate that the specified service role and Auto Scaling group exists before
# we attempt to create further resources

# IAM throws exceptions on unknown resources
try
{
    $serviceRole = Get-IAMRole -RoleName $ServiceRoleName
}
catch
{
    throw "Failed to locate a role with name $ServiceRoleName"
}

# Auto Scaling simply yields null on unknown resource
$asg = Get-ASAutoScalingGroup -AutoScalingGroupName $AutoScalingGroupName
if (!($asg))
{
    throw new "Failed to locate an Auto Scaling group with name $AutoScalingGroupName"
}

#==============================================================================
# Create the root CodeDeploy application; the cmdlet returns the unique
# application ID (which we will not use)

New-CDApplication -ApplicationName $ApplicationName -ComputePlatform Server > $null

#==============================================================================
# Set a custom configuration requesting CodeDeploy maintain one healthy
# instance during deployments. We could also use a built-in option, like
# 'CodeDeployDefault.OneAtATime', when specifying the deployment group options.
# Note that if we create our own deployment config, it is not deleted when the
# application is deleted, we must do an extra step.

$deploymentConfigName = "$ApplicationName-DeploymentConfig"

$deploymentConfigOptions = @{
    ComputePlatform='Server'
    MinimumHealthyHosts_Type='HOST_COUNT'
    MinimumHealthyHosts_Value=1
}

#==============================================================================
# Construct the deployment group which determines which instances to target,
# in this case all those that are in our auto scaling group. We can elect to do
# an in-place deployment or blue-green deployment and can also elect to use the
# load balancer to perform traffic control during a deployment. For the demo,
# we'll do in-place deployment without traffic control to speed things up. The
# cmdlet outputs the unique deployment configuration ID (which we do not need).

New-CDDeploymentConfig -DeploymentConfigName $deploymentConfigName @deploymentConfigOptions > $null

$deploymentGroupName = "$ApplicationName-DeploymentGroup"
$deploymentGroupOptions = @{
    ApplicationName=$ApplicationName
    AutoScalingGroup=$AutoScalingGroupName
    ServiceRoleArn=$serviceRole.Arn
    # optional use built-in configs like 'CodeDeployDefault.OneAtATime'
    DeploymentConfigName=$deploymentConfigName
    # optional 'BLUE_GREEN'
    DeploymentStyleType='IN_PLACE'
    # optional 'WITH_TRAFFIC_CONTROL', and set LoadBalancerInfo_TargetGroupInfoList
    DeploymentStyleOption='WITHOUT_TRAFFIC_CONTROL'
}

New-CDDeploymentGroup -DeploymentGroupName $deploymentGroupName @deploymentGroupOptions | Out-Null

[PSCustomObject]@{
    ApplicationName=$ApplicationName
    DeploymentConfigName=$deploymentConfigName
    DeploymentGroupName=$deploymentGroupName
}
