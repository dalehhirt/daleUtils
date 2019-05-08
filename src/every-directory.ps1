param(  [parameter(Mandatory=$true, ParameterSetName = "ScriptBlock")]
        [scriptblock]
        $ScriptBlock,

        [parameter(Mandatory=$true, ParameterSetName = "ScriptFile")]
        [string] 
        $ScriptFile, 
        
        [switch]
        $TestFirstOnly)

switch ($PsCmdlet.ParameterSetName) 

{ 

    "ScriptBlock" {
        if(![System.String]::IsNullOrWhiteSpace($ScriptBlock)) {
            $currentDirectories = dir | where {$_.PSIsContainer}
            if($TestFirstOnly) { $currentDirectories = $currentDirectories | Select-Object -First 1 }

            $currentDirectories | ForEach-Object {
                Push-Location $_
                write-host -----------
                write-host $_.FullName
                write-host -----------
                &$ScriptBlock
                Pop-Location
            } 
        }
        break
    }

    "ScriptFile"  {
        if(Test-Path $ScriptFile) {
            $currentDirectories = dir | where {$_.PSIsContainer}
            if($TestFirstOnly) { $currentDirectories = $currentDirectories | Select-Object -First 1 }

            $currentDirectories | ForEach-Object {
                Push-Location $_
                write-host -----------
                write-host $_.FullName
                write-host -----------
                &$ScriptFile
                Pop-Location
            } 
        }
        break
    }
} 

