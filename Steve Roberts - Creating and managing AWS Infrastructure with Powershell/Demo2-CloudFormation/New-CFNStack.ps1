function _promptForParameter([string]$paramName, [string]$paramDesc, [string]$paramDefault)
{
    $msg = "Parameter $paramName - $paramDesc "
    $hasDefaultValue = $false
    if ($paramDefault)
    {
        $msg += " ($paramDefault) "
        $hasDefaultValue = $true
    }

    $continueToPrompt = $true
    do
    {
        $pValue = Read-Host -Prompt $msg
        if ($pValue -Or $hasDefaultValue)
        {
            $continueToPrompt = $false
        }
    } while ($continueToPrompt)

    if ($pValue)
    {
        $pValue
    }
    else
    {
        $paramDefault
    }
}

function New-CFNStack
{
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Alias('Capabilities')]
        [string[]]
        ${Capability},

        [string]
        ${ClientRequestToken},

        [bool]
        ${DisableRollback},

        [bool]
        ${EnableTerminationProtection},

        [Alias('RollbackConfiguration_MonitoringTimeInMinutes')]
        [int]
        ${RollbackConfiguration_MonitoringTimeInMinute},

        [string[]]
        ${NotificationARNs},

        [Amazon.CloudFormation.OnFailure]
        ${OnFailure},

        [Alias('Parameters')]
        [Amazon.CloudFormation.Model.Parameter[]]
        ${Parameter},

        [Alias('ResourceTypes')]
        [string[]]
        ${ResourceType},

        [string]
        ${RoleARN},

        [Alias('RollbackConfiguration_RollbackTriggers')]
        [Amazon.CloudFormation.Model.RollbackTrigger[]]
        ${RollbackConfiguration_RollbackTrigger},

        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${StackName},

        [string]
        ${StackPolicyBody},

        [string]
        ${StackPolicyURL},

        [Alias('Tags')]
        [Amazon.CloudFormation.Model.Tag[]]
        ${Tag},

        [string]
        ${TemplateBody},

        [string]
        ${TemplateURL},

        [int]
        ${TimeoutInMinutes},

        [switch]
        ${Force},

        [string]
        ${EndpointUrl}
    )

    dynamicparam
    {
        try {
            if ($PSVersionTable.PSVersion.Major -ge 6)
            {
                $wrappedCommandName = 'AWSPowerShell.NetCore\New-CFNStack'
            }
            else
            {
                $wrappedCommandName = 'AWSPowerShell\New-CFNStack'
            }
            $targetCmd = $ExecutionContext.InvokeCommand.GetCommand($wrappedCommandName, [System.Management.Automation.CommandTypes]::Cmdlet, $PSBoundParameters)
            $dynamicParams = @($targetCmd.Parameters.GetEnumerator() | Microsoft.PowerShell.Core\Where-Object { $_.Value.IsDynamic })
            if ($dynamicParams.Length -gt 0)
            {
                $paramDictionary = [Management.Automation.RuntimeDefinedParameterDictionary]::new()
                foreach ($param in $dynamicParams)
                {
                    $param = $param.Value

                    if(-not $MyInvocation.MyCommand.Parameters.ContainsKey($param.Name))
                    {
                        $dynParam = [Management.Automation.RuntimeDefinedParameter]::new($param.Name, $param.ParameterType, $param.Attributes)
                        $paramDictionary.Add($param.Name, $dynParam)
                    }
                }
                return $paramDictionary
            }
        } catch {
            throw
        }
    }

    begin
    {
        try {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand($wrappedCommandName, [System.Management.Automation.CommandTypes]::Cmdlet)

            # if the user did not specify any parameters, inspect the template
            # to determine if any are needed and prompt for them
            if (!($PSBoundParameters['Parameter']))
            {
                if ($PSBoundParameters['TemplateBody'])
                {
                    $templateContent = $PSBoundParameters['TemplateBody']
                }
                else
                {
                    $templateContent = (Invoke-WebRequest $PSBoundParameters['TemplateUri']).Content
                }

                $templateParameters = [System.Collections.ArrayList]::new()

                # no 'test-yaml' or 'test-json' so try converting and if it fails, try as yaml
                $isYaml = $false
                try
                {
                    $template = ConvertFrom-Json $templateContent
                }
                catch
                {
                    try
                    {
                        $isYaml = $true
                        Import-Module powershell-yaml
                        $template = ConvertFrom-Yaml $templateContent -Ordered
                    }
                    catch
                    {
                        throw "Unrecognized or erroneous template content. Expected well-formed json or yaml."
                    }
                }


                if ($isYaml)
                {
                    foreach ($pkey in $template.Parameters.Keys)
                    {
                        $p = $template.Parameters[$pkey]
                        $pValue = _promptForParameter $pkey $($p.Description) $($p.Default)
                        [void] $templateParameters.Add(@{ ParameterKey="$pkey"; ParameterValue="$pValue" })
                    }
                }
                else
                {
                    foreach ($p in $template.Parameters.PSObject.Properties)
                    {
                        $pkey = $($p.Name)
                        $pValue = _promptForParameter $pkey $($p.Value.Description) $($p.Value.Default)
                        [void] $templateParameters.Add(@{ ParameterKey="$pkey"; ParameterValue="$pValue" })
                    }
                }

                $PSBoundParameters.Add('Parameter', $templateParameters)
            }

            $scriptCmd = {& $wrappedCmd @PSBoundParameters }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        }
    }

    process
    {
        try {
            $steppablePipeline.Process($_)
        } catch {
            throw
        }
    }

    end
    {
        try {
            $steppablePipeline.End()
        } catch {
            throw
        }
    }
<#
  .ForwardHelpTargetName $($wrappedCommandName)
  .ForwardHelpCategory Cmdlet
#>
}