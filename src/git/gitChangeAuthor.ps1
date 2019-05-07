param(
$repoName,
$repoUrl,
$oldemail,
$newemail,
[switch]$SkipInit)

if(!$SkipInit) {
    git clone --bare $repoUrl
    cd "$repoName.git"
}

$env_filter = '
OLD_EMAIL="{0}"
CORRECT_EMAIL="{1}"
if [ "$GIT_COMMITTER_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_COMMITTER_EMAIL="$CORRECT_EMAIL"
fi
if [ "$GIT_AUTHOR_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_AUTHOR_EMAIL="$CORRECT_EMAIL"
fi
' -f $oldemail, $newemail

git filter-branch --env-filter $env_filter

git log --format="%ae" --all | sort -u
