# Demo 2: Using PowerShell with AWS CloudFormation

Scenario: *Illustrate opportunities to use PowerShell in AWS CloudFormation templates (cfn-init and user data statements), and how to manage templates from the PowerShell command line. Additionally the demo shows how to proxy the AWS cmdlets to get a console/VS toolkit-like experience with respect to prompting for template parameters when using the New-CFNStack cmdlet from the AWS Tools for PowerShell modules.*

## PowerShell inside the template

- Powershell template (json & yaml) can run PowerShell cmds in cfn-init statements and we can set userdata
  - Editing PowerShell in json can be awkward and error prone, so consider keeping (large) scripts in S3 and downloading to the instance (relying on Read-S3Object being present) to then execute.

## Using PowerShell to instantiate stacks

Parameterized templates allow us to write reusable scripts, much like our PowerShell functions in the previous demo.

In the console, and for JSON-format templates in CloudFormation projects created with the AWS Toolkit for Visual Studio, you are prompted to supply parameter values when you create or update a stack. The PowerShell cmdlet to create a stack is New-CFNStack. If we load our template (yaml or json) using Get-Content, we'll see that New-CFNStack fails:

```powershell
$template = Get-Content '.\cfn_template.json' -Raw
New-CFNStack -StackName test -TemplateBody $template  # this fails!
```

The failure is a side effect of mapping cmdlets 1:1 to service APIs - additional functionality provided by the console or other tools is not present and the service fails our request because we did not supply parameters. We can solve this using a proxy function.

First get the metadata for the New-CFNStack cmdlet:

```powershell
$MetaData = New-Object System.Management.Automation.CommandMetaData (Get-Command New-CFNStack)
```

From the metadata we generate the proxy:

```powershell
[System.Management.Automation.ProxyCommand]::Create($MetaData)
```

We capture and wrap the generated content in a function with the same name as the cmdlet, and extend to suit. We can see the captued and edited content in the New-CFNStack.ps1 script file.

Dot-source the script (or do this in our profile)

```powershell
. .\New-CFNStack.ps1
```

Get the latest Windows Server 2016 image in our region

```powershell
Get-EC2ImageByName WINDOWS_2016_BASE
```

Run the proxy cmdlet (note we are re-using the template content we loaded earlier)

```powershell
New-CFNStack -StackName demo2 -TemplateBody $template
```

Check progress (can also use Wait-CFNStack)

```powershell
Get-CFNStack demo2
```

We can employ this practice in other places to 'value add' to the built-in cmdlets, for example

- Update-CFNStack
- New-ASLaunchConfiguration in previous section needed the user data to be base 64 encoded, unlike New-EC2Instance. We could wrapper with a proxy function to do this for us.
