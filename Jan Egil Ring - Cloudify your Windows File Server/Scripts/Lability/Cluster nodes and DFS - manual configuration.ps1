# Script to manually configure a file server cluster and DFS - used for Azure File Sync demo

# Cluster

Install-WindowsFeature -Name RSAT-Clustering
Test-Cluster -Node FS1,FS2 -Ignore Storage

New-Cluster -Node FS1,FS2 -StaticAddress 192.168.147.104/28 -NoStorage -Name DemoCluster

# DFS

Install-WindowsFeature -Name RSAT-DFS-Mgmt-Con

$cred = Get-Credential -UserName azurelab\administrator -Message .

Enable-WSManCredSSP -DelegateComputer *.azurelab.local -Role Client
Invoke-Command -ComputerName FS1,FS2 -ScriptBlock {Enable-WSManCredSSP -Role Server -Force}

Set-DfsnServerConfiguration -UseFqdn $true -ComputerName FS1
Set-DfsnServerConfiguration -UseFqdn $true -ComputerName FS2

Invoke-Command -ComputerName FS1.azurelab.local -ScriptBlock {
    
    
    New-Item -Path C:\DFSRoots -Name Public -ItemType Directory
    New-SmbShare C:\DFSRoots\Public -Name Public -ReadAccess Everyone
    New-DfsnRoot -TargetPath "\\fs1.azurelab.local\Public" -Type DomainV2 -Path "\\azurelab.local\Public" -EnableAccessBasedEnumeration $true

} -Credential $cred -Authentication Credssp


Invoke-Command -ComputerName FS2.azurelab.local -ScriptBlock {
        
    New-Item -Path C:\DFSRoots -Name Public -ItemType Directory
    New-SmbShare C:\DFSRoots\Public -Name Public -ReadAccess Everyone
    New-DfsnRootTarget -TargetPath "\\fs2.azurelab.local\Public" -Path "\\azurelab.local\Public"

} -Credential $cred -Authentication Credssp


New-SmbShare D:\NICDemoData -Name NICDemoData -FullAccess Everyone
New-DfsnFolder -Path "\\azurelab.local\Public\DemoData" -EnableTargetFailback $True -TargetPath \\BranchFS1.azurelab.local\NICDemoData
New-DfsnFolderTarget -Path "\\azurelab.local\Public\DemoData" -TargetPath \\DemoCluster.azurelab.local\NICDemoData

# AzureRM

Install-Module -Name AzureRM -Force

Invoke-Command -ComputerName FS1.azurelab.local,FS2.azurelab.local -ScriptBlock {

    Install-Module -Name AzureRM -Force

}