# Run to set up Git properly
# ---------------------------
git config --global core.safecrlf true
git config --global core.preloadindex true
git config --global core.fscache true
# makes notepad++ work properly with Git for commit messages
git config --global core.editor "'C:/Program Files (x86)/Notepad++/notepad++.exe' -multiInst -nosession"

git config --global push.default simple

# Takes care of credential issues with VSO
git config --global credential.helper wincred
git config --global remote.origin.prune true

#Alias commands
git config --global alias.add-alias !'f() { [ $# = 3 ] && git config $1 alias.\"$2\" \"$3\" && return 0 || echo \"Usage: git add-(local|global)-alias <new alias> <original command>\" >&2 && return 1; }; f'
git config --global alias.add-global-alias !"git add-alias --global"
git config --global alias.add-local-alias !"git add-alias --local"

git add-global-alias aliases !"git config --get-regexp '^alias\.' | cut -c 7- | sed 's/ / = /'"

# Git Config aliases
git add-global-alias configfile 'config --global -l --show-origin'

# Get the current branch name
git add-global-alias branch-name 'rev-parse --abbrev-ref HEAD'

git add-global-alias c commit
git add-global-alias ci commit
git add-global-alias co checkout
git add-global-alias cob 'checkout -b'

#Diff/merge aliases
git add-global-alias df diff
git add-global-alias dt difftool
git add-global-alias mt mergetool
git add-global-alias ff 'merge --ff-only'

git add-global-alias praise blame

git add-global-alias st status

#Pull/Fetch/Push/Merge Aliases
git add-global-alias sync !"git pull && git push"
git add-global-alias pu !"git fetch origin -v; git fetch upstream -v; git merge upstream/master"
git add-global-alias mm !"git fetch origin -v; git merge origin/master"

git add-global-alias br branch
git add-global-alias branches 'branch -a'

# stash aliases
git add-global-alias stashes 'stash list'

# Get the top level directory, regardless of what subdirectory we're in.
# root = ! pwd # this one is funny but slow
git add-global-alias root 'rev-parse --show-toplevel'

# Log aliases
git add-global-alias lg "log --graph --pretty=format:'%Cred%h -%C(yellow)%d%Creset %s %Cgreen(%ci) %C(bold blue)<%an>'"
git add-global-alias lol "log --graph --decorate --pretty=oneline --abbrev-commit"
git add-global-alias lola "log --graph --decorate --pretty=oneline --abbrev-commit --all"
git add-global-alias llog "log --date=local"
git add-global-alias who "shortlog --summary --"
git add-global-alias lc "log ORIG_HEAD.. --stat --no-merges"
git add-global-alias last 'log -1 HEAD'
git add-global-alias whorank 'shortlog --summary --numbered --no-merges'

# Not sure yet how to make this work in Powershell/CMD.  Comment out for the moment
#git add-global-alias lg50 !"git log --graph --abbrev-commit --date=relative --pretty=format:'%x00%h%x00%s%x00%cd%x00%an%x00%d' | gawk -F '\0' '{ printf "%s\033[31m%s\033[0m %-50s \033[32m%14s\033[0m \033[30;1m%s\033[0m\033[33m%s\n", $1, $2, gensub(/(.{49}).{2,}/, "\\1…","g",$3), $4, $5, $6 }' | less -R"
#git add-global-alias lg80 !"git log --graph --abbrev-commit --date=relative --pretty=format:'%x00%h%x00%s%x00%cd%x00%an%x00%d' | gawk -F '\0' '{ printf "%s\033[31m%s\033[0m %-80s \033[32m%14s\033[0m \033[30;1m%s\033[0m\033[33m%s\n", $1, $2, gensub(/(.{79}).{2,}/, "\\1…","g",$3), $4, $5, $6 }' | less -R"

#LS Aliases
git add-global-alias ls ls-files
git add-global-alias ign "ls-files -o -i --exclude-standard"
git add-global-alias ignored "ls-files -o -i --exclude-standard"

# Reset aliases
git add-global-alias undo 'reset --hard'
git add-global-alias unstage 'reset HEAD --'
git add-global-alias startover !'git undo && git clean -f -d -x'

#Email config aliases
git add-global-alias githubemail !"git config user.name 'Dale Hirt' && git config user.email 'dalehhirt@users.noreply.github.com'"

# Config aliases
git add-global-alias lconfig 'config --local --list'
git add-global-alias gconfig 'config --global --list'

# Publishing
git add-global-alias publish !'git push --set-upstream origin $(git branch-name)'

# From: https://github.com/GitAlias/gitalias/blob/master/gitalias.txt

# pruner: prune everything that is unreachable now.
#
# This command takes a long time to run, perhaps even overnight.
#
# This is useful for removing unreachable objects from all places.
#
# By [CodeGnome](http://www.codegnome.com/)
#
git add-global-alias pruner !"git prune --expire=now; git reflog expire --expire-unreachable=now --rewrite --all"

# repacker: repack a repo the way Linus recommends.
# This command takes a long time to run, perhaps even overnight.
#
# It does the equivalent of "git gc --aggressive"
# but done *properly*,  which is to do something like:
#
#     git repack -a -d --depth=250 --window=250
#
# The depth setting is about how deep the delta chains can be;
# make them longer for old history - it's worth the space overhead.
#
# The window setting is about how big an object window we want
# each delta candidate to scan.
#
# And here, you might well want to add the "-f" flag (which is
# the "drop all old deltas", since you now are actually trying
# to make sure that this one actually finds good candidates.
#
# And then it's going to take forever and a day (ie a "do it overnight"
# thing). But the end result is that everybody downstream from that
# repository will get much better packs, without having to spend any effort
# on it themselves.
#
# http://metalinguist.wordpress.com/2007/12/06/the-woes-of-git-gc-aggressive-and-how-git-deltas-work/
#
# We also add the --window-memory limit of 1 gig, which helps protect
# us from a window that has very large objects such as binary blobs.
#
git add-global-alias repacker 'repack -a -d -f --depth=300 --window=300 --window-memory=1g'

# Stash snapshot - from http://blog.apiaxle.com/post/handy-git-tips-to-stop-you-getting-fired/
# Take a snapshot of your current working tree without removing changes.
# This is handy for refactoring where you can't quite fit what you've done
# into a commit but daren't stray too far from now without a backup.
#
# Running this:
#
#    $ git snapshot
#
# Creates this stash:
#
#    stash@{0}: On feature/handy-git-tricks: snapshot: Mon Apr 8 12:39:06 BST 2013
#
# And seemingly no changes to your working tree.
#
git add-global-alias snapshot !'git stash save \"snapshot: $(date)\" && git stash apply "stash@{0}"'
