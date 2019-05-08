#requires -version 3
<#
.SYNOPSIS
  Sync all Github repositories with their upstream fork

.DESCRIPTION
  Runs through all 

.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>

.INPUTS
  <Inputs if any, otherwise state None>

.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>

.NOTES
  Version:        1.0
  Author:         <Name>
  Creation Date:  <Date>
  Purpose/Change: Initial script development
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

#Dot Source required Function Libraries
. "C:\Scripts\Functions\Logging_Functions.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "1.0"

#Log File Info
$sLogPath = "C:\Windows\Temp"
$sLogName = "<script_name>.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#-----------------------------------------------------------[Functions]------------------------------------------------------------

<#

Function <FunctionName>{
  Param()
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue "<description of what is going on>..."
  }
  
  Process{
    Try{
      <code goes here>
    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}

#>

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
#Script Execution goes here
#Log-Finish -LogPath $sLogFile

# Go up two directories to base Github directory
Push-Location
Set-Location (get-item $PSScriptRoot).parent.parent.FullName

function Sync-Repository() {
    param($Repository)
    if (Test-Path $Repository.name) {
        Push-Location
        Set-Location $Repository.name

        write-host Updating $Repository.name
        $gitUrl = ("""https://github.com/{0}/{1}.git""" -f $Repository.OriginalUser, $Repository.name)
        
        $upstream = git remote | where {$_ -eq "upstream"}
        if($upstream -eq $null) {
            Write-Host Creating upstream repository: $gitUrl
            git remote add upstream $gitUrl
        }

        # Checkout the master branch and update from the server
        git fetch upstream

        git checkout master
        
        git merge ("upstream/{0}" -f $Repository.OriginalBranch)
        #git pull

        # Pull the desired branch from the remote upstream repository
        #$gitUrl = ("""https://github.com/{0}/{1}.git""" -f $Repository.OriginalUser, $Repository.name)
        #git pull $gitUrl $Repository.OriginalBranch

        #git push

        # just in case we need to do anything
        Start-Process powershell -WorkingDirectory (Get-Location).Path
        Pop-Location
    }
}

$repos = Import-Csv -LiteralPath (Join-Path $PSScriptRoot Upstream.txt) -Header name,OriginalUser,OriginalBranch
$repos | ForEach-Object {Sync-Repository $_}

Pop-Location