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

function log() {
  write-host ">>> [$($env:COMPUTERNAME)]" ((Get-Date).ToUniversalTime().ToString('u')) "$args" -ForeGroundColor Yellow
}

log "Loading $PSCommandPath"
