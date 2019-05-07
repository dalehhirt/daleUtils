# Get all latest info
git pull
git push

# Get branch names
$branchesToRemove = git branch -vv | where {$_ -match '\[origin/.*: gone\]'} | foreach {$_.split(" ", [StringSplitOptions]'RemoveEmptyEntries')[0]}

if($branchesToRemove -ne $null) {
    write-host "Branches to delete"
    write-host "=================="
    $branchesToRemove

    $message  = 'Delete Branches'
    $question = 'Are you sure you want to proceed?'

    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

    $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
    if ($decision -eq 0) {
        $branchesToRemove | foreach {write-host "Deleting " $_; git branch -D $_}
    }
}
else {
    write-host "No branches to delete."
}
write-host "Done"
