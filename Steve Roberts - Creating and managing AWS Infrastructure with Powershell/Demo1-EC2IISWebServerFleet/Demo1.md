# Demo 1: Infrastructure from script - launching and configuring EC2 instances

Scenario: *Using cmdlets from the AWS Tools for PowerShell launch a VPC with an application load balancer, public and private subnets, and an auto scaling group to host an IIS web server fleet. The web server fleet is launched into the private subnets as a best practice and uses stock Windows Server 2016 images from AWS. In addition to the script to configure and launch the VPC resources Powershell is also used to configure each stock instance that is launched with the software and tools we need via User Data. Once the VPC is created, additional scripts can be used to create and configure an AWS CodeDeploy application targeting the instances in the Auto Scaling group to deploy a simple ASP.NET sample app from a WebDeploy package file.*

## Demo commands

Create the VPC and EC2 instance infrastructure. The InstanceProfileName parameter is the name of an EC2 instance profile wrapping an Identity and Access Management (IAM) Role granting AWS permissions to the running EC2 instances.

```powershell
.\New-IISWebServerFleet.ps1 -VpcName 'VPC-NAME-HERE' -InstanceProfileName 'INSTANCE-PROFILE-HERE'
```

Create the AWS CodeDeploy infrastructure targeting our instances. The ServiceRoleName parameter is the name of an Identity and Access Management (IAM) Role granting permissions to AWS CodeDeploy to access your EC2 instances. It has the AWS-provided AWSCodeDeployRole policy attached.

```powershell
.\New-CodeDeployApplication.ps1 -ApplicationName 'APP-NAME-HERE' -AutoScalingGroupName 'VPC-SCALING-GROUP-NAME-HERE' -ServiceRoleName 'SERVICE-ROLE-HERE'
```

Perform a deployment of a sample app contained in a WebDeploy package archive. The app being deployed here is a sample ASP.NET application generated using the Visual Studio project wizards, prebuilt into a WebDeploy archive. The appspec.yml file and any supporting scripts needed by AWS CodeDeploy can be found in the root of the zip file.

```powershell
".\DemoApp.webdeploy.zip" | .\New-CodeDeployment.ps1 -ApplicationName 'APP-NAME-HERE' -ArchiveKey codedeploy/DemoApp.webdeploy.zip -BucketName 'BUCKET-NAME-HERE'
```

Check deployment status

```powershell
Get-CDDeployment -DeploymentId 'DEPLOYMENT-ID-HERE'
```

To access the deployed application, first get the url associated with the load balancer (if you know the Amazon Resource Name (ARN) of the load balancer, pass it as -LoadBalancerArn otherwise all load balancer instances are returned)

```powershell
Get-ELB2LoadBalancer
```

Use the url to access the IIS root page. Add /sample to the url to reach the deployed application.

### Additional notes

WebDeploy packaging can lead to file paths in the package zip with lengths in excess of what is permitted in Windows, so I perform the packaging step as high in my folder structure as possible! Symptoms of excessive path errors are deployment failures claiming a missing file that is actually in the build area.

```powershell
msbuild .\SampleApp.csproj /t:Package /p:WebPublishMethod=Package /p:PackageAsSingleFile=false /p:SkipInvalidConfigurations=true /p:PackageLocation="..\publish.webdeploy\app" /p:DeployIISAppPath="Default Web Site/Sample"
Compress-Archive -Path ..\publish.webdeploy\* -DestinationPath ..\DemoApp.webdeploy.zip
```

