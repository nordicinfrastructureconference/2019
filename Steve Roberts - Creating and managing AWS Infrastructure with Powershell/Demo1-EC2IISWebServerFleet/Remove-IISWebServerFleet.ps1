<#
.Synopsis
    Reverses the effects of the New-IISWebServerFleet script to tear down
    the resources that were created. The resources related to the VPC are
    auto-discovered based on naming or tagging convention.

    Note: the cmdlet does not deal with eventual consistency issues that
    can sometimes occur. Instead it should be safe to run multiple times
    to clean up remaining resources left behind should the script fail
    due to eventual consistency issues at any point.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact="High")]
Param
(
    # The name associated with the vpc and its component resources.
    [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
    [string]$VpcName
)

if (!($PSCmdlet.ShouldProcess($VpcName, "Delete demo IIS web server fleet VPC and associated resources")))
{
    return
}

#==============================================================================
# Recover the details of the VPC, knowing we applied a Name tag of the given
# value

$vpc = Get-EC2Vpc -Filter @{ Name='tag:Name'; Values=$VpcName }
if (!($vpc))
{
    Write-Error "No VPC with Name tag matching the value $VpcName exists" -ErrorAction Stop
}

#==============================================================================
# Remove the Auto Scaling group, which will drain the instances, and then remove
# the launch configuration. This is slower than simply terminating the instances
# but cleaner.

try
{
    $asg = Get-ASAutoScalingGroup -AutoScalingGroupName $VpcName
}
catch
{
    Write-Warning "Autoscaling group $asg not found, assuming already deleted"
}

if ($asg)
{
    Write-Host "...removing Auto Scaling group $VpcName and terminating EC2 instances"

    Write-Host "......updating auto scaling group to set max capacity/desired to 0"
    Update-ASAutoScalingGroup -AutoScalingGroupName $VpcName -MinSize 0 -DesiredCapacity 0

    $toTerminate = $asg.Instances.Count

    Write-Host "......waiting for $toTerminate instances in group to terminate"
    do
    {
        Start-Sleep -Seconds 15

        $instances = (Get-ASAutoScalingGroup -AutoScalingGroupName $VpcName).Instances
        if ($instances.Count -gt 0)
        {
            $terminating = ($instances | Where-Object { $_.LifecycleState -eq 'Terminating' } | Measure-Object).Count
            $terminated = ($instances | Where-Object { $_.LifecycleState -eq 'Terminated' } | Measure-Object).Count

            Write-Host ".........$terminated terminated, $terminating still pending..."
        }
     } while ($instances.Count -gt 0)

    Write-Host "......removing auto scaling group and launch configuration"
    Remove-ASAutoScalingGroup -AutoScalingGroupName $VpcName -Force
    Remove-ASLaunchConfiguration -LaunchConfigurationName $VpcName -Force
}

#==============================================================================
# Remove the listener from the Application Load Balancer, then remove the
# target group and finally delete the ALB itself

try
{
    $alb = Get-ELB2LoadBalancer -Name $VpcName
}
catch
{
    Write-Warning "Load balancer $VpcName not found, assuming already deleted"
}

if ($alb)
{
    Write-Host "...removing application load balancer resources"

    # get the groups and listeners ahead of deletion, otherwise Get-ELB2TargetGroup
    # won't yield a result for the ALB
    $targetGroups = Get-ELB2TargetGroup -LoadBalancerArn $alb.LoadBalancerArn
    $listeners = Get-ELB2Listener -LoadBalancerArn $alb.LoadBalancerArn

    foreach ($listener in $listeners)
    {
        Write-Host "......removing application load balancer for port $($listener.Port)"
        Remove-ELB2Listener -ListenerArn $listener.ListenerArn -Force
    }

    foreach ($targetGroup in $targetGroups)
    {
        Write-Host "......removing target group $($targetGroup.TargetGroupName)"
        Remove-ELB2TargetGroup -TargetGroupArn $targetGroup.TargetGroupArn -Force
    }

    Remove-ELB2LoadBalancer -LoadBalancerArn $alb.LoadBalancerArn -Force
}

#==============================================================================
# Delete the NAT gateway and release the associated Elastic IP address

try
{
    $natGateway = Get-EC2NatGateway -Filter @{ Name='tag:Name';Values="$VpcName" },@{ Name='state'; Values='available' }
}
catch
{
    Write-Warning "NAT Gateway not found, assuming already deleted"
}

if ($natGateway)
{
    Write-Host "...removing NAT gateway"

    # deleted gateways can show up for a period of time, so add state qualifier
    Remove-EC2NatGateway -NatGatewayId $natGateway.NatGatewayId -Force

    # wait for the gateway deletion to complete
    Write-Host "......waiting on completion of deletion of NAT gateway"
    do {
        Write-Host ".........sleeping..."
        Start-Sleep -Seconds 5
        $ngwState = (Get-EC2NatGateway -NatGatewayId $natGateway.NatGatewayId).State
    } while ($ngwState -ne 'deleted')

    Write-Host "......releasing Elastic IP(s) previously associated with the NAT gateway"
    foreach ($eip in $natGateway.NatGatewayAddresses)
    {
        Write-Host ".........releasing eip allocation $($eip.AllocationId)"
        Remove-EC2Address -AllocationId $eip.AllocationId -Force
    }
}

#==============================================================================
# Delete the security groups

Write-Host "...removing security groups"

# groups must have any dependencies removed before deletion, so simplest to
# revoke all rules in all groups first

$securityGroups = Get-EC2SecurityGroup -Filter @{ Name='vpc-id'; Values=$vpc.VpcId }

foreach ($sg in $securityGroups)
{
    if ($sg.GroupName -eq 'default')
    {
        continue
    }

    foreach ($ingress in $sg.IpPermissions)
    {
        Write-Host "......removing ingress rules for group $($sg.GroupId)"
        Revoke-EC2SecurityGroupIngress -GroupId $sg.GroupId -IpPermission $ingress -Force
    }
    foreach ($egress in $sg.IpPermissions.Egress)
    {
        Write-Host "......removing egress rules for group $($sg.GroupId)"
        Revoke-EC2SecurityGroupEgress -GroupId $sg.GroupId -IpPermission $egress
    }
}

foreach ($sg in $securityGroups)
{
    if ($sg.GroupName -eq 'default')
    {
        continue
    }

    Write-Host "......removing group $($sg.GroupId)"
    Remove-EC2SecurityGroup -GroupId $sg.GroupId -Force
}

#==============================================================================
# Delete the route tables

$routeTables = Get-EC2RouteTable -Filter @{ Name='vpc-id'; Values=$vpc.VpcId },@{ Name='association.main'; Values='false' }
if ($routeTables)
{
    Write-Host "...removing route tables"

    foreach ($rt in $routeTables)
    {
        # we can remove route tables without needing to delete the routes they contain first
        foreach ($subnetAssoc in $rt.Associations)
        {
            Write-Host "......disassocating route table $($rt.RouteTableId) from subnet $($subnetAssoc.SubnetId)"
            Unregister-EC2RouteTable -AssociationId $subnetAssoc.RouteTableAssociationId -Force
        }

        Write-Host "......removing route table $($rt.RouteTableId)"
        Remove-EC2RouteTable -RouteTableId $rt.RouteTableId -Force
    }
}

#==============================================================================
# Delete the public and private subnets

$subnets = Get-EC2Subnet -Filter @{ Name='vpc-id'; Values=$vpc.VpcId }
if ($subnets)
{
    Write-Host "...removing subnets"

    foreach ($subnet in $subnets)
    {
        Write-Host "...removing subnet $($subnet.SubnetId)"
        Remove-EC2Subnet -SubnetId $subnet.SubnetId -Force
    }
}

#==============================================================================
# Delete the internet gateway

try
{
    $igw = Get-EC2InternetGateway -Filter @{ Name='tag:Name'; Values="$VpcName" }
}
catch
{
    Write-Warning "Internet Gateway not found, assuming already deleted"
}

if ($igw)
{
    Write-Host "...removing internet gateway"

    Dismount-EC2InternetGateway -InternetGatewayId $igw.InternetGatewayId -VpcId $vpc.VpcId -Force
    Remove-EC2InternetGateway -InternetGatewayId $igw.InternetGatewayId -Force
}

#==============================================================================
# Final step now all resources are removed, delete the VPC

Write-Host "...removing VPC"

Remove-EC2Vpc -VpcId $vpc.VpcId -Force

#==============================================================================
# Done!