<#
.DESCRIPTION
  PowerShell Profile file.
.EXAMPLE
# Open a powershell terminal and run the following code.  Copy this file into that file.
code $profile.CurrentUserAllHosts
#>


#-------------------------
# Functions
#-------------------------

function log() {
  write-host ">>> [$($env:COMPUTERNAME)]" ((Get-Date).ToUniversalTime().ToString('u')) "$args" -ForeGroundColor Green
}

function addto-Env () {
   param($path)
   $paths = $env:path -split ";"

   if (!(Test-Path $path)) {
    log "$Path does not exist.  Not adding to `$env:path."
    return
  }

  if ($paths -contains $path) {
    log "`$env:path already contains $path"
    return
  }

  log "Adding to `$env:path: $path"
  $env:path += ";$path"

}

# Each instance of Powershell gets its own stack name
function foreach-directory() {
  param ($scriptBlock)
  $ForeachDirectoryStackName = (New-Guid).ToString()
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

function Format-Terraform {
  [CmdletBinding()]
  param (
    # Specifies a path to one or more locations.
    [Parameter(Mandatory=$true,
               Position=0,
               ParameterSetName="Path",
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true,
               HelpMessage="Path to one or more locations.")]
    [Alias("PSPath")]
    [ValidateNotNullOrEmpty()]
    [string[]]
    $Path
  )
  
  begin {
    $stackName = "terraform-fmt-$(New-Guid)"
  }
  
  process {
    foreach ($currentPath in $Path) {
      <# $currentPath is the current item #>
      if(!(Test-Path $currentPath)) {
        Write-Error "$CurrentPath does not exist!"
        return
      }

      try {
        Push-Location -Path $Path -StackName $stackName
        terraform fmt --recursive
      }
      catch {
        # Display the primary exception message
        log "An error occurred:" "$($_.Exception.Message)" 

        # Display the full error object for detailed logging
        log "Full Error Details: $_"
      }
      finally {
        Pop-Location -StackName $stackName
      }
    }    
  }
  
  end {
    
  }
}

function Loop-Command {
  [CmdletBinding()]
  param (
    $scriptBlock,
    $retryTimeoutInSeconds = 20,
    [switch]$DontClearScreen
  )
  
  begin {
    
  }
  
  process {
    while ($true) {
      if (!$DontClearScreen) {
        Clear-Host
        log "Cleared Screen."
      }
      try {
        log "Running $scriptBlock"
        & $scriptBlock
      }
      catch {
        # Display the primary exception message
        log "An error occurred:" "$($_.Exception.Message)" 

        # Display the full error object for detailed logging
        log "Full Error Details: $_"
      }
      finally {
        log "Waiting $retryTimeoutInSeconds..."
        log "Press Ctrl+C to stop looping"
        Start-Sleep -Seconds $retryTimeoutInSeconds
      }
    }
  }
  
  end {
    
  }
}

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

function pd() {
  if($args.Count) {
    $location = $args[0]
    if(Test-Path $location -ErrorAction SilentlyContinue){
      Push-Location $location
    }
    else {
      Write-Error "No such location: $location"
    }
  }
  else {
    Pop-Location
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

#-------------------------
# Main
#-------------------------
log "Loading $PSCommandPath"
# log "Setting up `$Profile.CurrentUserAllHosts $($Profile.CurrentUserAllHosts)"

if ($null -ne (get-module -Name Posh-Git -ListAvailable -ErrorAction SilentlyContinue)) {
  log "Loading posh-git"
  Import-Module posh-git
}

# We do this because portable git might be redirected to the wrong .gitconfig
if($env:HOME -ne $env:USERPROFILE) {
  log "Resetting `$env:HOME from $($env:home) to $($env:USERPROFILE)"
  $env:HOME = $env:USERPROFILE
}

addto-Env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\azcli\bin"
addto-Env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\terraform"
addto-Env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\Graphviz\bin"
addto-env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\sysinternals"
addto-env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\go\bin"
addto-env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\github\bin"
addto-env "$($env:USERPROFILE)\OneDrive - Mavis Tire\Documents\tools\git\cmd"
