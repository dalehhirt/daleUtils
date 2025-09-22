# From laptop
function log() {
  write-host ">>> [$($env:COMPUTERNAME)]" ((Get-Date).ToUniversalTime().ToString('u')) "$args" -ForeGroundColor Yellow
}

function addto-Env () {
   param($path)
   $paths = $env:path -split ";"
   if($paths -notcontains $path) {
       log "Adding to `$env:path: $path"
       $env:path += ";$path"
   }
}

# Each instance of Powershell gets its own stack name
$ForeachDirectoryStackName = (New-Guid).ToString()
function foreach-directory() {
  param ($scriptBlock)
  Get-ChildItem -path . -Directory | ForEach-Object {
    try {
        # Code that might throw an error
        Push-Location -Path $_ -StackName $ForeachDirectoryStackName
        log "In " $_.FullName
        &$scriptBlock
    } finally {
      Pop-Location -StackName $ForeachDirectoryStackName
    }
  }
}

function Create-terraform() {
  param($moduleName = "")

  if("" -ne $moduleName) {
    mkdir $moduleName
    Push-Location $moduleName
  }

  write-output @"
# This is a minimal main.tf

# ---------------------
# Local Variables
# ---------------------
locals {
}

# ---------------------
# Resources
# ---------------------
"@ | Out-File -FilePath .\main.tf -Force
  write-output @"
# This is a minimal variables.tf

# ---------------------
# Module Variables
# ---------------------
variable "name" {
  type        = string
  description = "The name of the Azure resource."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group to create the Azure Resource in."
}

variable "location" {
  type        = string
  description = "The location of the Azure resource."
}

variable "tags" {
  type        = map(string)
  description = "Tags to be applied to the Azure resource"
  default     = {}
}

"@ | Out-File -FilePath .\variables.tf -Force
  
  write-output @"
# This is a minimal outputs.tf

output "id" {
  description = "The ID of the Azure resource."
  value       = <resource>.id
}

output "name" {
  value = <resource>.name
}

"@ | Out-File -FilePath .\outputs.tf -Force

  if("" -ne $moduleName) {
    Pop-Location
  }
}

log "Loading $PSCommandPath"
log "Setting up `$Profile.CurrentUserAllHosts $($Profile.CurrentUserAllHosts)"
addto-Env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\azcli\bin"
addto-Env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\terraform"
addto-Env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\Graphviz\bin"
addto-env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\sysinternals"
addto-env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\go\bin"
addto-env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\github\bin"
addto-env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\git\bin"


<#
.DESCRIPTION
  PowerShell Profile file.
.EXAMPLE
# Open a powershell terminal and run the following code.  Copy this file into that file.
code $profile.CurrentUserAllHosts
#>

function Using-Object() {
    <#
    .DESCRIPTION
    Allows for disposal of objects
    .EXAMPLE
    Using-Object ($sw = [System.IO.StreamWriter]::new("some file.txt")) {
      $sw.WriteLine('some text')
    }
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [AllowNull()]
        [Object]
        $InputObject,
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    try {
        . $ScriptBlock
    }
    finally {
        if ($null -ne $InputObject -and $InputObject -is [System.IDisposable]) {
            $InputObject.Dispose()
        }
    }
}

function prompt {

    $host.ui.RawUI.WindowTitle = "Current Folder: $pwd"
    $CmdPromptUser = [Security.Principal.WindowsIdentity]::GetCurrent();
    $IsAdmin = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    Write-Host ""
    Write-Host "`u{1F9D9} $($CmdPromptUser.Name.split("\")[1]) " -ForegroundColor Green -NoNewline
    Write-host ($(if ($IsAdmin) { '(as admin) ' } else { '' })) -ForegroundColor Red -NoNewLine
    Write-Host "on `u{1F4BB}" $env:COMPUTERNAME"."$env:USERDNSDOMAIN

    Write-Host "`u{1F4C1} $pwd"  -ForegroundColor Yellow 
    
    $defaultPrompt = " `u{25B6}"
    $now = "$([DateTime]::now.ToString("yyyy-MM-dd HH:mm:ss"))"

    $GitPromptSettings.DefaultPromptPath = ''
    $GitPromptSettings.DefaultPromptPrefix.Text = $now
    $GitPromptSettings.DefaultPromptSuffix = $defaultPrompt
    $GitPromptSettings.DefaultPromptPrefix.ForegroundColor = [ConsoleColor]::Magenta
    
    # Have posh-git display its default prompt
    $prompt = & $GitPromptScriptBlock
    if ($prompt) { return "$prompt " }
    else { return "$now $defaultPrompt "}
}

Import-Module posh-git
