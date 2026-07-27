#Requires -Modules PSFramework
<#
.Description
This script takes a script and turns it into a snippet.
.NOTES
Requires PSFramework to be installed
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
  $scriptToUpdate
)
begin {
  $script:_ScriptName = 'ScriptToSnippet'

  # ------------------------------
  # Leave this section alone
  # ------------------------------
  
  $start = get-date
  
  $ErrorActionPreference = 'Stop'

  function Initialize-Logging() {
    Set-PSFConfig -Name PSFramework.Message.Style.Prefix -Value $true
    Set-PSFConfig -Name PSFramework.Message.Style.Prefix.Host -Value ">>> "
    Set-PSFConfig -Name PSFramework.Message.Info.Color -Value "Green"
    $defaultTimeFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'sszzzz"
    Set-PSFConfig -Name PSFramework.Message.Style.TimeFormat -Value $defaultTimeFormat

    log "Logging Initialized"
  }

  function log() {
    Write-PSFMessage -Level Host -Message "$args" -Target $env:COMPUTERNAME 
  }
  
  function log-error() {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification='Log error is more accurate')]
    param()
  
    Write-PSFMessage -Level Error -Message "$args" -Target $env:COMPUTERNAME 
  }
  
  function log-verbose() {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification='Log verbose is more accurate')]
    param()

    Write-PSFMessage -Level Verbose -Message "$args" -Target $env:COMPUTERNAME 
  }
  
  Initialize-Logging
  
  # ------------------------------
  # Write code starting here
  # ------------------------------
  log "Starting" $script:_ScriptName
}
process {
  if (Test-Path $scriptToUpdate) {
    log "Exporting $scriptToUpdate"
    get-content $scriptToUpdate | ForEach-Object {
      $line = $_
      """$((($line -replace '\\', '\\')-replace '\$', '\\$') -replace '"', '\"')"","
    }
  }
  else {
    log "$scriptToUpdate does not exist."
  }
}
end {
  $end = get-date
  log "Finished" (($end - $start).ToString("hh\h\:mm\m\:ss\s"))

  # This makes sure we wait for any lingering messages
  Wait-PSFMessage
}