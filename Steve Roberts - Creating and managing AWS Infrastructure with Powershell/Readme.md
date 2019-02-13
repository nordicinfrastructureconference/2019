# Creating and Managing AWS Infrastructure with PowerShell

This session presented a deep dive into techniques and services to create and manage AWS cloud infrastructure using PowerShell. The demonstrations included use of the [AWS Tools for PowerShell](https://aws.amazon.com/powershell/), together with the use of PowerShell in conjunction with other AWS services and technologies such as AWS Systems Manager, AWS CloudFormation and AWS Lambda.

## Introduction to PowerShell on AWS

This section covered the 'first 5 minutes' getting started with the AWS Tools for PowerShell modules. The demo included setting up credentials, how to set default credentials and region for a shell or script, and how to navigate the tools to find the cmdlets you need including:

- What services are supported and what is the 'noun prefix' for a service?

```powershell
Get-AWSPowerShellVersion -ListServiceVersionInfo
```

- What cmdlets are available for service X?

```powershell
Get-AWSCmdletName -Service 'EC2'
Get-AWSCmdletName -Service 'Compute Cloud'
```

- What cmdlet maps to API Y for service X?

```powershell
Get-AWSCmdletName -ApiOperation 'DescribeInstances'
```

- What cmdlet maps to this AWS CLI command?

```powershell
Get-AWSCmdletName -AwsCliCommand 'aws ec2 describe-instances'
Get-AWSCmdletName -AwsCliCommand 'ec2 describe-instances'
```

## Demo 1: Infrastructure from script - launching and configuring EC2 instances

This demo used pure PowerShell script containing cmdlets from the AWS Tools for PowerShell to construct a VPC with public and private subnets and associated route tables and security groups, an Application Load Balancer, and an Auto Scaling group with launch configuration to place EC2 instances into the private subnets. The EC2 instances are configured from PowerShell script in User Data to self-configure as IIS web servers.

The second part of the demo used additional scripts to create [AWS CodeDeploy](https://aws.amazon.com/codedeploy/) infrastructure targeting the EC2 instances in the VPC, and showed how to deploy an ASP.NET application built into a webdeploy archive using CodeDeploy.

The scripts and more details are contained in the Demo1-EC2IISWebServerFleet folder.

## Demo 2: Using PowerShell with AWS CloudFormation

This demo illustrated how to use PowerShell in [AWS CloudFormation](https://aws.amazon.com/cloudformation/) templates. It also illustrated how to proxy the cmdlets contained in the AWS Tools for PowerShell modules to emulate console and AWS Toolkit for Visual Studio behavior when launching CloudFormation stacks to prompt for missing parameters.

The scripts and more details are contained in the Demo2-CloudFormation folder.

## Demo 3: Using PowerShell with AWS Systems Manager

This demo illustrated the use of PowerShell in conjunction with several components of the [AWS Systems Manager](https://aws.amazon.com/systems-manager/), including Parameter Store, Run Command and Session Manager.

The scripts and more details are contained in the Demo3-SystemsManager folder.

## Demo 4: Monitoring the monitors with a serverless PowerShell function in AWS Lambda

The final demo illustrated the use of an [AWS Lambda](https://aws.amazon.com/lambda/) function, written in PowerShell and deployed using the [AWS Lambda Tools for PowerShell](https://www.powershellgallery.com/packages/AWSLambdaPSCore/), to monitor [AWS CloudWatch](https://aws.amazon.com/cloudwatch/) Logs data coming from the EC2 instances deployed earlier in the session.

The scripts and more details are contained in the Demo4-MonitoringTheMonitors folder.

## Wrap and links

Useful links from the final wrap-up slides in PowerPoint:

- [AWS Tools for Windows PowerShell](https://www.powershellgallery.com/packages/AWSPowerShell/)
- [AWS Tools for PowerShell Core](https://www.powershellgallery.com/packages/AWSPowerShell.NetCore/)
- [AWS Tools for PowerShell Cmdlet Reference](https://docs.aws.amazon.com/powershell/latest/reference)
- [.NET/PowerShell homepage on AWS](https://aws.amazon.com/net/)
- [AWS Developer Blog articles on PowerShell](https://aws.amazon.com/blogs/developer/category/programing-language/powershell/)
