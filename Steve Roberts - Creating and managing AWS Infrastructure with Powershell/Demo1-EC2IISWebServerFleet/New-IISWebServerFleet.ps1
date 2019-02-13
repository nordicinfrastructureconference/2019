<#
.SYNOPSIS
    Creates a VPC with public and private subnets. The public subnets will be used
    to configure an Application Load Balancer. The private subnets contain a fleet of
    Auto Scaled EC2 Windows instances hosting our web application in IIS.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact="Medium")]
Param
(
    # The name to associate with the vpc. This will also be used as a naming prefix for sub-resources
    # using tagging.
    [Parameter(Mandatory=$true, Position=0)]
    [string]$VpcName,

    # The name of the instance profile that should be used when launching the EC2 instances. The script
    # will auto-discover the required Amazon Resource Name (ARN) of the profile.
    [Parameter(Mandatory=$true, Position=1)]
    [string]$InstanceProfileName,

    # The size of instances to be launched in the fleet. If not specified m5.2xlarge will be assumed.
    [Parameter()]
    [string]$InstanceType = "m5.2xlarge",

    # The ID of the Windows-based AMI to launch. If not supplied, Windows Server 206 Base is assumed.
    [Parameter()]
    [string]$ImageID,

    # Optional keypair name that allows SSH/RDP/Admin password decryption of the launched EC2 instances.
    [Parameter()]
    [string]$KeyName,

    # Optional switch to skip specifying instance configuration in user data. Allows bare-bones instances
    # to be launched into the VPC.
    [Parameter()]
    [switch]$SkipInstanceConfiguration
)

if (!($PSCmdlet.ShouldProcess($VpcName, "Create VPC and associated resources for a web server fleet based on Windows/IIS")))
{
    return
}

# This map will contain all the resource IDs we collect along the way and
# will be the logical output from the script as a PSObject
$resourceIDSet = [PSCustomObject]@{}

function _collectResource([string]$propertyName, [string]$idOrName)
{
    $resourceIDSet | Add-Member -NotePropertyName $propertyName -NotePropertyValue $idOrName
    # using Write-Host because Write-Verbose will cause verbose output from
    # the AWS tools to become mixed in, which I don't want
    if ($idOrName -is [string])
    {
        Write-Host "...added $propertyName $idOrName"
    }
    else
    {
        Write-Host "...added $propertyName"
    }
}

function _addNameTagToResource([string]$ResourceID, [string]$NameTagValue)
{
    New-EC2Tag -Resource $ResourceID -Tag @{ Key='Name';Value=$NameTagValue }
}

#==============================================================================
# Validate that the supplied instance profile name exists and we can recover
# the ARN we'll need later, before we create anything

# IAM throws exceptions on unknown resources
try
{
    $instanceProfile = Get-IAMInstanceProfile -InstanceProfileName $InstanceProfileName
}
catch
{
    throw "Failed to locate an instance profile with name $InstanceProfileName"
}

#==============================================================================
# Determine the set of AZs available in the current region. We will create
# public and private subnets in each AZ.

$zones = Get-EC2AvailabilityZone

#==============================================================================
# Create and tag the VPC

$vpc = New-EC2Vpc -CidrBlock "10.0.0.0/16"
_addNameTagToResource -ResourceID $vpc.VpcId -NameTagValue $VpcName
_collectResource 'Vpc' $vpc.VpcId

#==============================================================================
# Attach an internet gateway and associate with the VPC

$igw = New-EC2InternetGateway
_addNameTagToResource -ResourceID $igw.InternetGatewayId -NameTagValue "$VpcName"
Add-EC2InternetGateway -InternetGatewayId $igw.InternetGatewayId -VpcId $vpc.VpcId
_collectResource 'InternetGateway' $igw.InternetGatewayId

#==============================================================================
# Create a pair of public and private subnets for each availability zone

$publicSubnets = [System.Collections.ArrayList]::new()
$privateSubnets = [System.Collections.ArrayList]::new()

$iprangebase = 0
foreach ($az in $zones)
{
    $public = New-EC2Subnet -VpcId $vpc.VpcId -CidrBlock "10.0.$iprangebase.0/24" -AvailabilityZone $az.ZoneName
    [void] $publicSubnets.Add($public.SubnetId)
    _addNameTagToResource -ResourceID $public.SubnetId -NameTagValue "$VpcName-public-$($az.ZoneId)"
    Write-Host "...created public subnet $($public.SubnetId) in zone $($az.ZoneName)"

    $iprangebase++
    $private = New-EC2Subnet -VpcId $vpc.VpcId -CidrBlock "10.0.$iprangebase.0/24" -AvailabilityZone $az.ZoneName
    [void] $privateSubnets.Add($private.SubnetId)
    _addNameTagToResource -ResourceID $private.SubnetId -NameTagValue "$VpcName-private-$($az.ZoneId)"
    Write-Host "...created private subnet $($private.SubnetId) in zone $($az.ZoneName)"

    $iprangebase++
}

_collectResource 'PublicSubnet' $publicSubnets
_collectResource 'PrivateSubnet' $privateSubnets

#==============================================================================
# Create security groups; one allowing inbound traffic from the elb on port 80,
# the second used to protect instances in the private subnets to only allow
# traffic on port 80 originating through the public subnets.

$publicSG = New-EC2SecurityGroup -VpcId $vpc.VpcId -GroupName "$VpcName-public" -GroupDescription "public port 80"
_addNameTagToResource -ResourceID $publicSG -NameTagValue "$VpcName-public"
Grant-EC2SecurityGroupIngress -GroupId $publicSG -IpPermission @{ IpProtocol="tcp"; FromPort="80"; ToPort="80"; IpRanges="0.0.0.0/0" }
_collectResource 'PublicSecurityGroup' $publicSG

$internalSG = New-EC2SecurityGroup -VpcId $vpc.VpcId -GroupName "$VpcName-internal" -GroupDescription "internal port 80"
_addNameTagToResource -ResourceID $internalSG -NameTagValue "$VpcName-internal"

$ugPair = New-Object Amazon.EC2.Model.UserIdGroupPair
$ugPair.GroupId = "$publicSG"
$internalPort80Rule = @{ IpProtocol="tcp"; FromPort="80"; ToPort="80"; UserIdGroupPairs=$ugPair }
Grant-EC2SecurityGroupIngress -GroupId $internalSG -IpPermission $internalPort80Rule
_collectResource 'PrivateSecurityGroup' $internalSG

#==============================================================================
# Create and configure a route table for the public routes, then associate the
# route table with the public subnets.

$publicRT = New-EC2RouteTable -VpcId $vpc.VpcId
_addNameTagToResource -ResourceID $publicRT.RouteTableId -NameTagValue "$VpcName-public"
New-EC2Route -RouteTableId $publicRT.RouteTableId -DestinationCidrBlock "0.0.0.0/0" -GatewayId $igw.InternetGatewayId > $null
_collectResource 'PublicRouteTable' $publicRT.RouteTableId

foreach ($subnet in $publicSubnets)
{
    Register-EC2RouteTable -RouteTableId $publicRT.RouteTableId -SubnetId $subnet > $null
    Write-Host "...associated public subnet $($subnet) with public route table $($publicRT.RouteTableId)"
}

#==============================================================================
# Add a NAT gateway to the first public subnet; the private route table will
# be configured to send all outbound traffic to the gateway allowing our EC2
# instances access to the internet. We could also elect to create an additional
# public subnet solely for this purpose.

$eip = New-EC2Address -Domain Vpc
_collectResource 'ElasticIP' $eip.PublicIp
$natGateway = (New-EC2NatGateway -AllocationId $eip.AllocationId -SubnetId $publicSubnets[0]).NatGateway
_addNameTagToResource -ResourceID $natGateway.NatGatewayId -NameTagValue "$VpcName"
_collectResource 'NATGateway' $natGateway.NatGatewayId

# we need to wait for this resource to be ready
Write-Host "...awaiting completion of NAT gateway creation"
do {
    Start-Sleep -Seconds 5
    $natGateway = Get-EC2NatGateway -NatGatewayId $natGateway.NatGatewayId
} while ($natGateway.State -ne 'available')

Write-Host "...created NAT gateway $($natGateway.NatGatewayId) associated with EIP $($eip.PublicIp)"

#==============================================================================
# Create the internal route table allowing outbound access to the NAT gateway,
# associating the table with the private subnets to allow outbound internet
# connectivity from the EC2 instances we'll place into the private subnets.

$privateRT = New-EC2RouteTable -VpcId $vpc.VpcId
_addNameTagToResource -ResourceID $privateRT.RouteTableId -NameTagValue Value="$VpcName-internal"
_collectResource 'PrivateRouteTable' $privateRT.RouteTableId
New-EC2Route -RouteTableId $privateRT.RouteTableId -DestinationCidrBlock "0.0.0.0/0" -NatGatewayId $natGateway.NatGatewayId > $null

Write-Host "...created internal route table $($privateRT.RouteTableId) for internal subnets to NAT gateway $($natGateway.NatGatewayId)"

foreach ($subnet in $privateSubnets)
{
    Register-EC2RouteTable -RouteTableId $privateRT.RouteTableId -SubnetId $subnet > $null
    Write-Host "...associated private subnet $($subnet) with internal route table $($privateRT.RouteTableId)"
}

#==============================================================================
# With the VPC network now constructed we can build out the application load
# balancer components

$elbParams = @{
    Name=$VpcName
    Subnet=$publicSubnets
    SecurityGroup=$publicSG
}

$elb = New-ELB2LoadBalancer @elbParams -Tag @{Key='Name';Value="$VpcName" }
_collectResource 'LoadBalancer' $elb.LoadBalancerArn

$tgParams = @{
    VpcId=$vpc.VpcId
    Name=$VpcName
    Protocol='HTTP'
    Port=80
}

$targetGroup = New-ELB2TargetGroup @tgParams
_collectResource 'LoadBalancerTargetGroup' $targetGroup.TargetGroupArn

$listenerParams = @{
    LoadBalancerArn=$elb.LoadBalancerArn
    Protocol='HTTP'
    Port=80
    DefaultAction=@{ Type='forward'; TargetGroupArn=$targetGroup.TargetGroupArn }
}

$listener = New-ELB2Listener @listenerParams
_collectResource 'LoadBalancerListener' $listener.ListenerArn

#==============================================================================
# Finally define the auto scaling group configuration that will be used to
# launch stock Windows Server 2016 EC2 instances, configured at boot time with
# a PowerShell-based user data script.

# retrieve the latest Windows Server 2016 image, if not specified
if (!($ImageID))
{
    $ImageID = (Get-EC2ImageByName WINDOWS_2016_BASE).ImageId
    Write-Host "...Windows image ID not specified, using latest Windows Server 2016 image ID $ImageID in $InstanceType types"
}

# construct a launch configuration that Auto Scaling will use to launch new
# instances on a up scaling event

$asgConfig = @{
    LaunchConfigurationName=$VpcName
    InstanceType=$InstanceType
    ImageId=$ImageID
    SecurityGroup=$internalSG
    IamInstanceProfile=$instanceProfile.Arn
    BlockDeviceMapping=@{ DeviceName='/dev/sda1'; Ebs=@{ VolumeType='gp2'; VolumeSize=100 } }
}

if (!($SkipInstanceConfiguration))
{
    # configure the script our instance will run on startup - it runs only on initial creation
    # but you can configure it to run on restarts if needed
    $region = (Get-DefaultAWSRegion).Region

    $userData = @"
<powershell>
# Install IIS
Install-WindowsFeature -Name Web-Server,NET-Framework-45-ASPNET,NET-Framework-45-Core,NET-Framework-45-Features,NET-Framework-Core -IncludeManagementTools
# Download and install Chocolately and use it to obtain webdeploy
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install webdeploy -y
# Download and install the CodeDeploy agent from the regional bucket location
Read-S3Object -BucketName aws-codedeploy-$region -Key latest/codedeploy-agent.msi -File c:\temp\codedeploy-agent.msi
c:\temp\codedeploy-agent.msi /quiet /l c:\temp\host-agent-install-log.txt
</powershell>
"@

    # note that we must base64 encode the user data; unlike the New-EC2Instance cmdlet
    # the New-ASLaunchConfiguration cmdlet does not have a switch enabling the cmdlet to
    # do the work for us
    $userDataBytes = [System.Text.Encoding]::UTF8.GetBytes($userData)
    $encodedUserData = [System.Convert]::ToBase64String($userDataBytes)

    $asgConfig.Add('UserData', $encodedUserData)
}

if ($KeyName)
{
    $asgConfig.Add('KeyName', $KeyName)
    _collectResource 'KeyPairName' $KeyName
}

New-ASLaunchConfiguration @asgConfig
_collectResource 'AutoScalingLaunchConfiguration' $VpcName

$asgParams = @{
    AutoScalingGroupName=$VpcName
    LaunchConfigurationName=$VpcName
    MinSize=1
    MaxSize=4
    DesiredCapacity=2
    TargetGroupARNs=$targetGroup.TargetGroupArn
    VPCZoneIdentifier=($privateSubnets -Join ",")
}

New-ASAutoScalingGroup @asgParams -Tag @{ Key='Name';Value="$VpcName" }
_collectResource 'AutoScalingGroup' $VpcName

#==============================================================================
# All done, output the collated resource IDs to the pipeline

Write-Output $resourceIDSet
