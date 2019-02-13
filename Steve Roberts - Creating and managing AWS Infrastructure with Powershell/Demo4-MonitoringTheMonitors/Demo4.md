# Demo 4: Monitoring the Monitors

Scenario: *With our agents and servers configured we want to now monitor the various stats around the health of our fleet. In this example we'll write a serverless function, in PowerShell, that will respond to AWS CloudWatch Log stream notifications and scan for items of interest (in this case the word 'ERROR' appearing in our custom app logs). If found, an alert will be raised from the Lambda function using a Simple Notification Service topic that has an email subscription.*

Having installed the [AWS Lambda Tools for Powershell](https://www.powershellgallery.com/packages/AWSLambdaPSCore/) module, we can inspect the available 'blueprint' templates to get us started:

```powershell
Get-AWSPowerShellLambdaTemplate
```

A sample Lambda function to process CloudWatch Logs events is in the LogWatcher folder. The Lambda inspects the new log streams coming from our deployed application looking for 'significant' information that we might want to alarm on (in this case, it looks for the word 'ERROR' in the log message).

First create the SNS topic

```powershell
New-SNSTopic -Name 'DemoAppLogNotifications'
```

Configure the topic to send email notifications

```powershell
Connect-SNSNotification -TopicArn 'TOPIC-ARN-HERE' -Protocol 'email' -Endpoint 'YOUR-EMAIL-HERE'
```

Be sure to check the email to confirm the subscription!

The *AWSLambdaPSCore* module also contains cmdlets to deploy the Lambda function. The deployed Lambda needs permissions to call the Systems Manager GetParameters api, and the Publish api for SNS.

```powershell
Publish-AWSPowerShellLambda -Name 'LogWatcher' -ScriptPath '.\LogWatcher.ps1' -IAMRoleArn 'FUNCTION-ROLE-HERE'
```

Once deployed configure the Lambda function to permit CloudWatch Logs to invoke it (this is done only once). $StoredAWSRegion is set when we use *Set-DefaultAWSRegion* to set a default region for the shell or script.

```powershell
Add-LMPermission -FunctionName LogWatcher -Action 'lambda:InvokeFunction' -StatementId 'LogWatcherPolicy' -Principal "logs.$StoredAWSRegion.amazonaws.com"
```

Create the subscription filter that will cause the Lambda function to be invoked when log streams are updated:

```powershell
Write-CWLSubscriptionFilter -LogGroupName "nic2019" -FilterName "demoapp" -FilterPattern "" -DestinationArn (Get-LMFunctionConfiguration -FunctionName "LogWatcher").FunctionArn
```

Test by accessing the deployed demo ASP.NET application and clicking the Send Logs link on the home page.
