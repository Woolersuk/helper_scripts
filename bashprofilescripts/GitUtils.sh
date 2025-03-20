function gco() {
	BRANCH=$(gb)
	FUNCTION=$1
	COMMENT="${@:2}"
	git commit -m "$FUNCTION: $BRANCH: $COMMENT"
}

function nb {
    local BRANCH=$1;
    git stash;
    git checkout master;
    git pull;
    git checkout -b $BRANCH;
    git stash apply;
    git status
}

function gar {
  CURRENTDIR=$(pwd)
  for i in $(az repos list --org https://youlend.visualstudio.com -p youlend-infrastructure | jq '.[].name' -r); do
    gcl $i
    cd $CURRENTDIR/$i
    pre-commit install
    cd $CURRENTDIR
  done
}

parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/:(\1)/'
}

# Function to update your branch with latest from a specified base branch (rebase)
git_update_branch_rebase() {
    local base_branch="$1"
    
    # If no branch specified, check which one exists
    if [ -z "$base_branch" ]; then
        # Check if main exists
        if git ls-remote --heads origin main | grep -q main; then
            base_branch="main"
        else
            base_branch="master"
        fi
    fi
    
    current_branch=$(git branch --show-current)
    git fetch origin
    
    # Check if the specified branch exists
    if ! git ls-remote --heads origin $base_branch | grep -q $base_branch; then
        echo "Error: Branch 'origin/$base_branch' does not exist."
        return 1
    fi
    
    git rebase origin/$base_branch
    echo "Updated $current_branch with latest changes from $base_branch via rebase"
}

#!/bin/bash

# Function to clone a YL Data Analytics repo
gitCloneYLDataRepo() {
  local repo_name="$1"
  if [[ -z "$repo_name" ]]; then
    echo "Usage: gitCloneYLDataRepo <repo_name>"
    return 1
  fi
  git clone "https://dev.azure.com/Youlend/Youlend-DataAnalytics/_git/$repo_name" "/Git/YL.Data.Repos/$repo_name"
}

# Function to clone a YL Infrastructure repo
gitCloneYLInfraRepo() {
  local repo_name="$1"
  if [[ -z "$repo_name" ]]; then
    echo "Usage: gitCloneYLInfraRepo <repo_name>"
    return 1
  fi
  git clone "https://dev.azure.com/Youlend/Youlend-Infrastructure/_git/$repo_name" "/Git/YL.Infra.Repos/$repo_name"
}

# Function to clone a general YL repo
gitCloneYLRepo() {
  local repo_name="$1"
  if [[ -z "$repo_name" ]]; then
    echo "Usage: gitCloneYLRepo <repo_name>"
    return 1
  fi
  git clone "https://dev.azure.com/Youlend/Youlend/_git/$repo_name" "/Git/YL.Repos/$repo_name"
}


# Create aliases
alias gaa="git add -u"
alias gat="git ls-files --modified | xargs git add"
alias gb="git branch | grep \"*\" | cut -d ' ' -f2"
alias gc="git checkout $1"
alias gca="git commit --amend --no-edit"
alias gcl="git clone $1"
alias gcyl=gitCloneYLRepo
alias gcyld=gitCloneYLDataRepo
alias gcyli=gitCloneYLInfraRepo
alias gdm="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit master.."
alias gfo="git fetch origin"
alias gg='git grep -n '
alias gicl="git clone youlend@vs-ssh.visualstudio.com:v3/youlend/Youlend-Infrastructure/$1"
alias gitown="git log | grep "Author" | sort | uniq -c"
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gmm="git merge master"
alias gpob="git pull origin $1"
alias gpom="git pull origin master"
alias gprf="git config pull.rebase false"
alias gprt="git config pull.rebase true"
alias gr="cd $(git rev-parse --show-toplevel)"
alias grebase="git_update_branch_rebase"
alias grm="git rebase master"
alias gs="git status"