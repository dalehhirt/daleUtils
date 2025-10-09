<#
.Description
This script runs.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param()
begin {
  function log() {
    write-host ">>> [$($env:COMPUTERNAME)]" ((Get-Date).ToUniversalTime().ToString('u')) "$args" -ForeGroundColor Green
  }
  
  function log-error() {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '',
      Justification='Log error is more accurate')]
    param()
  
    Write-Error ">>> [$($env:COMPUTERNAME)] $((Get-Date).ToUniversalTime().ToString('u')) $args"
  }

  function ForceCopy-File {
    param (
        $currentFile,
        $newFile,
        $backupFile
    )
    if(Test-Path $currentFile) {
        log "Found existing $currentFile"

        $tempValue = 0
        $backupFileFormat = "{0}.{1}"
        while(Test-Path $backupFile) {
            if(Test-Path ($backupFileFormat -f $backupFile, $tempValue)) {
                log "Found existing backup file $backupFile"
                $tempValue++
            }
            else {
                $backupFile = $backupFileFormat -f $backupFile, $tempValue
            }
        }

        log "Moving $currentFile to $backupFile"
        Move-Item -Path $currentFile -Destination $backupFile
    }

    log "Copying $newFile to $currentFile"
    Copy-Item -Path $newFile -Destination $currentFile -Force
  }
}
process {
    $dateString = (Get-Date).ToUniversalTime().ToString('u').Replace(":", "").Replace("-","").Replace(" ", "")

    $repoGitConfig = Join-Path $PSScriptRoot "config/.gitconfig"
    $currentGitConfig = Join-Path $env:USERPROFILE ".gitconfig"
    $backupGitConfig = "{0}.{1}" -f $currentGitConfig, $dateString

    ForceCopy-File -currentFile $currentGitConfig -newFile $repoGitConfig -backupFile $backupGitConfig
    
    $repoGitConfig = Join-Path $PSScriptRoot "config/personal/personal.gitconfig"
    $currentGitConfig = "c:\personal\personal.gitconfig"
    $backupGitConfig = "{0}.{1}" -f $currentGitConfig, $dateString

    ForceCopy-File -currentFile $currentGitConfig -newFile $repoGitConfig -backupFile $backupGitConfig

    $repoGitConfig = Join-Path $PSScriptRoot "config/work/work.gitconfig"
    $currentGitConfig = "c:\work\work.gitconfig"
    $backupGitConfig = "{0}.{1}" -f $currentGitConfig, $dateString

    ForceCopy-File -currentFile $currentGitConfig -newFile $repoGitConfig -backupFile $backupGitConfig

}
end {
}