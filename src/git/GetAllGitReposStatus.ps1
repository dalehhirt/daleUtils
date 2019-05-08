cls

# Go up two directories to base Github directory
Push-Location
Set-Location (get-item $PSScriptRoot).parent.parent.FullName

function Sync-Repository() {
    param($Repository)
    write-host "----------------- " $Repository.name

    if (Test-Path $Repository.name) {
        Push-Location
        Set-Location $Repository.name

        #Start-Process powershell -WorkingDirectory (Get-Location).Path -command "
        git status

        Pop-Location
    }
}

$repos = Get-Content (Join-Path $PSScriptRoot Repository.txt) | ConvertFrom-Json
$repos | ForEach-Object {Sync-Repository $_}

Pop-Location