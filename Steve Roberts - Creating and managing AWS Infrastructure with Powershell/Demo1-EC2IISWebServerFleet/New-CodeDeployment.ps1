<#
.Synopsis
    Performs a new deployment to an existing deployment group using AWS CodeDeploy,
    Uploading the archive containing the code to deploy to an Amazon S3 bucket.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact="Medium")]
Param
(
    # The name of the CodeDeploy application to deploy to.
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ApplicationName,

    # The archive file containing the application to deploy.
    [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
    [string]$DeploymentBundle,

    # The name of the bucket to which the deployment archive will be uploaded.
    [Parameter(Mandatory=$true, Position=2)]
    [string]$BucketName,

    # Optional key for the deployment archive in the bucket. Defaults to the name of the archive file.
    [Parameter()]
    [string]$ArchiveKey,

    # The deployment group to use. If not specified defaults to the application name suffixed with '-DeploymentGroup'.
    [Parameter()]
    [string]$DeploymentGroupName,

    # If set the script waits for the deployment to complete (success or fail), polling for status every 15 seconds.
    [Parameter()]
    [switch]$WaitForCompletion
)

if (!($PSCmdlet.ShouldProcess($ApplicationName, "Deploy application")))
{
    return
}

#==============================================================================
# Set defaults for unspecified options

$_deploymentGroupName = $DeploymentGroupName
if (!($_deploymentGroupName))
{
    $_deploymentGroupName = "$ApplicationName-DeploymentGroup"
}

$_archiveKey = $ArchiveKey
if (!($_archiveKey))
{
    $_archiveKey = Split-Path -Path $DeploymentBundle -Leaf
}

#==============================================================================
# Upload the bundle to S3

if (!(Test-Path $DeploymentBundle))
{
    throw "Specified deployment bundle does not exist"
}

Write-S3Object -BucketName $BucketName -Key $_archiveKey -File $DeploymentBundle

#==============================================================================
# Request the deployment

$deploymentOptions = @{
    ApplicationName=$ApplicationName
    DeploymentGroupName=$_deploymentGroupName
    RevisionType='S3'
    S3Location_Bucket=$BucketName
    S3Location_Key=$_archiveKey
    S3Location_BundleType='zip'
    FileExistsBehavior='OVERWRITE'
}

$deploymentId = New-CDDeployment @deploymentOptions

Write-Output (New-Object PSObject -Property @{ DeploymentId = $deploymentId })

if ($WaitForCompletion)
{
    Write-Host "...polling for completion of deployment $deploymentId"

    $exitStates = "Failed","Succeeded","Stopped"
    do
    {
        Start-Sleep -Seconds 15
        $deployment = Get-CDDeployment -DeploymentId $deploymentId
        Write-Host "...current deployment status: $($deployment.Status)"
    } while (!($exitStates -contains $deployment.Status))
}
