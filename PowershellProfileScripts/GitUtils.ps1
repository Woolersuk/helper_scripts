function prompt {
    $gitBranch = ''
    if (Test-Path .git) {
        $gitBranch = git rev-parse --abbrev-ref HEAD
    }
    "$PWD [$gitBranch]>"
}

# Function gco (git commit)
function gco {
    $BRANCH = gb
    $FUNCTION = $args[0]
    $COMMENT = $args[1..($args.Length - 1)] -join ' '
    git commit -m "$($FUNCTION): $($BRANCH): $($COMMENT)"
}

# Function nb (git create new branch from master)
function nb {
    param($BRANCH)
    git stash
    git checkout master
    git pull
    git checkout -b $BRANCH
    git stash apply
    git status
}

# Function gar (git clone and pre-commit install for each repo)
function gar {
    $CURRENTDIR = Get-Location
    $repos = az repos list --org https://youlend.visualstudio.com -p youlend-infrastructure | jq '.[].name' -r
    foreach ($repo in $repos) {
        gcl $repo
        Set-Location "$CURRENTDIR\$repo"
        pre-commit install
        Set-Location $CURRENTDIR
    }
}

# Function to parse the current Git branch
function parse_git_branch {
    $branch = git branch 2> $null | Where-Object { $_ -match '^\*' } | ForEach-Object { $_ -replace '^\* ', '' }
    if ($branch) { ":($branch)" }
}

# Function to update your branch with latest from a specified base branch (rebase)
function Update-GitBranch-Rebase {
    param(
        [Parameter(Mandatory=$false)]
        [string]$BaseBranch = ""
    )
    
    # If no branch specified, check which one exists
    if ([string]::IsNullOrEmpty($BaseBranch)) {
        # Check if main exists
        $main_exists = git ls-remote --heads origin main
        if ($main_exists) {
            $BaseBranch = "main"
        } else {
            $BaseBranch = "master"
        }
    }
    
    $current_branch = git branch --show-current
    git fetch origin
    
    # Check if the specified branch exists
    $branch_exists = git ls-remote --heads origin $BaseBranch
    if (-not $branch_exists) {
        Write-Error "Error: Branch 'origin/$BaseBranch' does not exist."
        return
    }
    
    git rebase origin/$BaseBranch
    Write-Output "Updated $current_branch with latest changes from $BaseBranch via rebase"
}

function gitCloneYLDataRepo {
  param ([string]$i)
  git clone https://dev.azure.com/Youlend/Youlend-DataAnalytics/_git/$i C:\Work\YL.Data.Repos\$i
}

function gitCloneYLInfraRepo {
  param ([string]$i)
  git clone https://dev.azure.com/Youlend/Youlend-Infrastructure/_git/$i C:\Work\YL.Infra.Repos\$i
}

function gitCloneYLRepo {
  param ([string]$i)
  git clone https://dev.azure.com/Youlend/Youlend/_git/$i C:\Work\YL.Repos\$i
}

function RunPreCommit {
	pre-commit run -a
}

# Define aliases (PowerShell equivalent to bash aliases)
Set-Alias gaa "git add -u"
Set-Alias gat "git ls-files --modified | ForEach-Object { git add $_ }"
Set-Alias gb "git branch | Where-Object { $_ -match '^\*' } | ForEach-Object { $_ -replace '^\* ', '' }"
Set-Alias gca "git commit --amend --no-edit"
Set-Alias gcl "git clone $args"
Set-Alias gcyl gitCloneYLRepo
Set-Alias gcyld gitCloneYLDataRepo
Set-Alias gcyli gitCloneYLInfraRepo
Set-Alias gdm "git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit master.."
Set-Alias gfo "git fetch origin"
Set-Alias gg "git grep -n"
Set-Alias gicl "git clone youlend@vs-ssh.visualstudio.com:v3/youlend/Youlend-Infrastructure/$args"
Set-Alias gitown "git log | Select-String 'Author' | Sort-Object | Get-Unique"
Set-Alias gmm "git merge master"
Set-Alias gpob "git pull origin $args"
Set-Alias gpom "git pull origin master"
Set-Alias gprf "git config pull.rebase false"
Set-Alias gprt "git config pull.rebase true"
Set-Alias gr "cd (git rev-parse --show-toplevel)"
Set-Alias grm "git rebase master"
Set-Alias gs "git status"
Set-Alias grebase Update-GitBranch-Rebase
Set-Alias pcra RunPreCommit