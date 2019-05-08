param($DefaultEmailAddress)

# Go up two directories to base Github directory
Push-Location
Set-Location (get-item $PSScriptRoot).parent.parent.FullName

function Sync-Repository() {
    param($Repository)
    if (!(Test-Path $Repository.name)) {
        write-host Creating $Repository.name
        git clone $Repository.clone_url
    }

    Push-Location
    Set-Location $Repository.name

    git config user.email $DefaultEmailAddress

    Pop-Location
}

$repos = Get-Content (Join-Path $PSScriptRoot Repository.txt) | ConvertFrom-Json
$repos | where {$_.name -ne "PublicDale"} | ForEach-Object {Sync-Repository $_}

Pop-Location