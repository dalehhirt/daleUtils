#requires -version 3
<#
.SYNOPSIS
  Merge master into current branch.

.DESCRIPTION
  This script makes sure master is up to date, then merges those changes into the current branch.
  If it is on the master branch, it will create a new branch with the name of the computer, otherwise, it will move back to the current branch.

.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Version:        1.0
  Author:         Dale Hirt
  Creation Date:  10/28/2015
  Purpose/Change: Initial script development
  
.EXAMPLE
  .\gitmergefrommaster.ps1
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

#Dot Source required Function Libraries
. (Join-Path $PSScriptRoot "Logging_Functions.ps1")

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "1.5"

$global:LOGDEBUG = $false

#Log File Info
$sLogPath = $PSScriptRoot
$sLogName = "gitmergefrommaster.log"
$sLogFile = [System.IO.Path]::GetTempFileName()

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

Log-Start -LogFile $sLogFile -ScriptVersion $sScriptVersion

Log-Write -LogPath $sLogFile -LineValue ("Updating in {0}" -f (Get-Location))

Log-Write -LogPath $sLogFile -LineValue "Get current branch"
$currentBranch = git symbolic-ref --short HEAD

if($currentBranch -ne "master") {
    Log-Write -LogPath $sLogFile -LineValue "Checkout master branch"
    git checkout master
}

Log-Write -LogPath $sLogFile -LineValue "Pull master branch"
git pull

Log-Write -LogPath $sLogFile -LineValue "Push master branch"
git push

if($currentBranch -ne "master") {
    Log-Write -LogPath $sLogFile -LineValue "Checkout $currentBranch branch"
    git checkout $currentBranch

    # we should always be tracking an upstream branch.  If not, we'll make sure we are.
    if(!(Get-GitStatus).Upstream){
        git push --set-upstream origin $currentBranch   
    }

    Log-Write -LogPath $sLogFile -LineValue "Merging master branch"
    git merge master

    Log-Write -LogPath $sLogFile -LineValue "Push $currentBranch back up"
    git push
}
else {
    # Get all local Branches
    $allBranches = git branch --list | foreach {$_.Substring(2).Trim()}
    if(($allbranches | where{$_ -eq $env:COMPUTERNAME})) {
        git checkout $env:COMPUTERNAME
    }
    else {
        git checkout -b $env:COMPUTERNAME
    }

    if(!(Get-GitStatus).Upstream){
        git push --set-upstream origin $env:COMPUTERNAME   
    }
}

Log-Finish -LogPath $sLogFile
Get-Content $sLogFile
git status
