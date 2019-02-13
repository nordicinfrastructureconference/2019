# Demo 3: Using PowerShell with AWS Systems Manager

Scenario: *Using Parameter Store, Run Command, Session Manager and State Manager to access, control and monitor instances.*

## Why use Systems Manager

- Enables seamless, scalable, management of cloud and on-prem hardware
- Traditional on-prem tools don't scale to the cloud, may have licensing costs and complexity
- Avoids using multiple sets of tools -- want to use a single pane of glass
- No additional charge for Systems Manager
- Easy-to-write (and extend) automation
- Inherently secure due to built-in integrations with services such as IAM and CloudTrail

## Systems Manager Components

- Agent supports Windows and various flavors of Linux
  - Installed by default on Windows, not on Linux (simple user data script to install)
- Open source: https://github.com/aws/amazon-ssm-agent
- Documents are the core resource, you send documents to different services based on what you want to achive
- Ancillary services: parameter store, inventory, maintenance window
- Document is just a json document with a schema, description, optional parameters and one or more executable steps

## Parameter Store

### Parameter Store Demos

#### Demo: how to work with parameter store from the command line

Create simple string, string list and secure string parameters:

```powershell
Write-SSMParameter -name "/app/stringparam" -type String -Value "hello"
```

Note that the cmdlet emits the version number of the parameter. If a parameter exists you need to add the *-Overwrite $true* parameter.

To read a specific version of a parameter append the version number to the parameter name, for example

```powershell
(Get-SSMParameterValue -Name "/app/stringparam:1").Parameters
```

Store a string list:

```powershell
Write-SSMParameter -name "/app/stringlistparam" -type StringList -Value "hello,again"
```

Store a secure string:

```powershell
Write-SSMParameter -name "/app/securestringparam" -type SecureString -Value "this will be encrypted"
```

Read back a single parameter value (string, string list or secure string types). Note that secure strings are not decrypted:

```powershell
(Get-SSMParameterValue -Name "/app/stringparam").Parameters
```

Read a secure string with decryption

```powershell
(Get-SSMParameterValue -Name "/app/securestringparam" -WithDecryption $true).Parameters
```

Read a batch of pre-configured parameters under common path

```powershell
Get-SSMParametersByPath -Path "/app"
```

#### Demo: setup a CloudWatch agent configuration file that we'll use later

First get a pre-built configuration file for CloudWatch (generated using the wizard on an EC2 instance):

```powershell
$cwconfig = Get-Content .\CloudWatchConfiguration.AppAndIISLogs.json -Raw
```

Upload the configuration data to a parameter store value:

```powershell
Write-SSMParameter -Name "/nic2019/CloudWatchConfiguration.AppAndIISLogs.json" -Type String -Value $cwconfig -Overwrite $true
```

## Run Command

- Can use a document or just specify a command
- Run across multiple instances, optional rate (how many parallel exectutions) and error control (how many errors before fail?)
- Support for on-prem and cloud infrastructure
- Output can be viewed from console, cli, api or s3
- Integration with CloudTrail tells us what ran, and who did it
- Access to run command can be controlled through IAM -- provides for curated documents available to different users
- Use cases
  - no ssh or rdp access (can close inbound access and bastion hosts)
  - run Bash or PowerShell scripts
  - operating system changes
  - directory join on startup
  - application management (config update, version update) at scale
  - execute third party configuration management scripts (DSC, Ansible, Salt etc)

### Running an AWS-provided document

We can look at the document to determine parameters - think of this as 'Get-Help' on a document!

```powershell
Get-SSMDocumentDescription -Name "AWS-RunPowerShellScript"
```

Select the instances we want to to targe with our command (assumes name tag value):

```powershell
$instances = (Get-EC2Instance -Filter @{Name='tag:Name';Value='nic2019-demo3'},@{Name='instance-state-name';Value='running'}).Instances | select -ExpandProperty InstanceId
```

Execute the document, passing in the ad-hoc script we want to run:

```powershell
Send-SSMCommand -DocumentName "AWS-RunPowerShellScript" -InstanceId $instances -OutputS3BucketName YOUR-BUCKET-HERE -OutputS3KeyPrefix runcommandlogs -Parameter @{
    'commands'=@("Install-WindowsFeature -Name Web-Server -IncludeManagementTools", "Start-IISSite 'Default Web Site'")}
```

We can check overall command status:

```powershell
Get-SSMCommand -CommandId "COMMAND-ID-HERE"
```

Or we can dive into per-instance detail:

```powershell
Get-SSMCommandInvocation -CommandId "COMMAND-ID-HERE" -InstanceId $instances[0] -Detail $true
```

We also specified the command output should be sent to S3 - take a look using Visual Studio to show structure

#### Creating and running your own document

The first demo of the session used EC2 instance user data to configure the stock Amazon-provided images as IIS web servers during instance launch. This demo instead uses a Run Command document that also adds in the CloudWatch agent which will be configured using the configuration file we posted to Parameter Store earlier in this section.

Get the document content we want to register with Systems Manager:

**note** the document makes use of the CloudWatch configurationd document we uploaded to Parameter Store above

```powershell
$doc = Get-Content .\IISWebServerConfiguration.json -Raw
```

Register the document with the service:

```powershell
New-SSMDocument -DocumentType Command -Name 'nic2019-demo3-SetupIISWebServer' -Content $doc -TargetType '/AWS::EC2::Instance' -DocumentFormat JSON
```

Run the document (which has no parameters) to configure our fleet:

```powershell
Send-SSMCommand -DocumentName "nic2019-demo3-SetupIISWebServer" -InstanceId $instances -OutputS3BucketName YOUR-BUCKET-HERE -OutputS3KeyPrefix runcommandlogs
```

## Session Manager

The commands we just ran will take a few minutes to complete, so let's poke around our servers using Session Manager.

### Setup a new web site on only one instance in the fleet

- connect to one of the instances in the vpc
- cd inetpub\wwwroot
- mkdir test
- cd test

```html
<html><head><title>Test page</title></head><body><h1>Hello world!</h1></body></html>
```

- Set-Content -Value "html-from-above" -Path ".\index.html"
- New-IISSite -Name "hello" -BindingInformation "*:80:" –PhysicalPath "c:\inetpub\wwwroot\test"

Now access the ELB url + /test/index.html- one instance should respond with the new page, the other should yield a 404 (refresh to have the ALB cycle through the instances).
