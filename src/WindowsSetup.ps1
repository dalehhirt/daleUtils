#requires -version 4.0
#requires -RunAsAdministrator
<#
.SYNOPSIS
  Set up a machine for SysAdmin responsibilities
.DESCRIPTION
  This script will install chocolatey and several utilities to get you started setting up a sysadmin box.
  This is intended to be installed on your personal machine where you will do your sysadmin work from.
  It will not work on a SAW.
.EXAMPLE
  ./SysadminSetupScript.ps1
.NOTES
  It requires Administrator privileges and at least Powershell 4.0.
.LINK
  http://www.microsoft.com
#>
[CmdletBinding()]
param (
)

function Add-ChocolateyPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $PackageName,
        $Parameters,
        [switch]$Force
    )
    
    begin {
        $chocoExe = "$($env:ProgramData)\chocolatey\bin\choco.exe"
        $packages = &$chocoExe list --local-only --limit-output  | foreach {($_ -split '\|')[0]}
    }
    
    process {
        If(($packages -notcontains $PackageName) -or ($Force)){
            $cmd = "$chocoExe install $PackageName --confirm"
            if (!([System.String]::IsNullOrWhiteSpace($Parameters))) {
                $cmd += " --parameters ""$Parameters"""
            }
            if([System.Management.Automation.ActionPreference]::SilentlyContinue -ne $VerbosePreference) {
                $cmd += " --verbose"
            }
            if($Force) {
                $cmd += " --force"
            }
            write-verbose ">>> Running $cmd"
            Invoke-Expression -Command $cmd
        }
    }
    
    end {
        
    }
}

write-host ">>> Starting $(get-date)"

# install Chocolatey
if (!(Test-Path "$($env:ProgramData)\chocolatey\bin\choco.exe")) {
    write-host ">>> Installing chocolatey"
    Set-ExecutionPolicy Bypass -Scope Process -Force;
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# If any of the below fail with 429, wait one hour
# https://chocolatey.org/docs/community-packages-disclaimer#what-to-do-when-you-are-rate-limited

# install Powershell 7
Add-ChocolateyPackage -PackageName "pwsh"

# Visual Studio Code and various extensions
Add-ChocolateyPackage -PackageName "vscode"
Add-ChocolateyPackage -PackageName "vscode-powershell"
Add-ChocolateyPackage -PackageName "vscode-gitignore"
Add-ChocolateyPackage -PackageName "vscode-gitlens"
Add-ChocolateyPackage -PackageName "vscode-icons"
Add-ChocolateyPackage -PackageName "vscode-kubernetes-tools"
Add-ChocolateyPackage -PackageName "vscode-mssql"
Add-ChocolateyPackage -PackageName "vscode-powershell"
Add-ChocolateyPackage -PackageName "vscode-yaml"

Add-ChocolateyPackage -PackageName "sysinternals"

Add-ChocolateyPackage -PackageName "git"

# remote server admin tools
Add-ChocolateyPackage -PackageName "rsat"

# SQL Server tools
Add-ChocolateyPackage -PackageName "azure-data-studio"
Add-ChocolateyPackage -PackageName "azure-data-studio-sql-server-admin-pack"
Add-ChocolateyPackage -PackageName "azuredatastudio-powershell"
Add-ChocolateyPackage -PackageName "ssms"

# Kubernetes client
Add-ChocolateyPackage -PackageName "kubernetes-cli"
Add-ChocolateyPackage -PackageName "kubernetes-helm"

# Azure clients
Add-ChocolateyPackage -PackageName "azure-cli"
Add-ChocolateyPackage -PackageName "microsoftAzureStorageExplorer"

Add-ChocolateyPackage -PackageName "7zip"
Add-ChocolateyPackage -PackageName "beyondcompare"

Add-ChocolateyPackage -PackageName "cascadiacodepl"
Add-ChocolateyPackage -PackageName "dropbox"
Add-ChocolateyPackage -PackageName "box-drive"
Add-ChocolateyPackage -PackageName "google-drive-file-stream"


Add-ChocolateyPackage -PackageName "darktable"
Add-ChocolateyPackage -PackageName "thunderbird"
Add-ChocolateyPackage -PackageName "microsoft-windows-terminal"
Add-ChocolateyPackage -PackageName "firefox"
Add-ChocolateyPackage -PackageName "discord"
Add-ChocolateyPackage -PackageName "choco-cleaner"
Add-ChocolateyPackage -PackageName "choco-upgrade-all-at" -Parameters "'/DAILY:yes /TIME:07:00 /ABORTTIME:10:00'"

write-host ">>> Finished $(get-date)"
