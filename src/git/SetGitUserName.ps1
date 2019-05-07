
#Make sure we have set up Git
$ScriptToRun= $PSScriptRoot+"\SetupGit.ps1"
&$ScriptToRun

$hashRemotes = @{}
Write-Host Working in (Get-Location)
$setValue = $false
git remote -v | foreach{$splitVals = $_.Split();$hashRemotes[$splitVals[0]] = $splitVals[1]}
if($hashRemotes.ContainsKey("origin")) {
    
    if($hashRemotes["origin"].ToString().StartsWith("https://github.com")) {
        Write-Host Setting to personal email
        git githubemail
        $setValue = $true
    }

    if($hashRemotes["origin"].ToString().StartsWith("https://gist.github.com")) {
        Write-Host Setting to personal email
        git githubemail
        $setValue = $true
    }

    if($hashRemotes["origin"].ToString().StartsWith("https://devdiv.visualstudio.com")) {
        Write-Host Setting to work email
        git msemail
        $setValue = $true
    }
}
if(!$setValue) {
    write-host Unknown email to set.
    git remote -v
}
