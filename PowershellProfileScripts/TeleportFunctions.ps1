# Teleport CLI shortcuts for PowerShell
function Get-TeleportStatus { tsh status }
function Set-TeleportLogin { tsh login --auth=ad --proxy=youlend.teleport.sh:443 }
function Set-TeleportLoginKubeAdmin { tsh kube login headquarter-admin-eks-green --proxy=youlend.teleport.sh:443 --auth=ad }
function Set-TeleportLoginKubeDev { tsh kube login aslive-dev-eks-green --proxy=youlend.teleport.sh:443 --auth=ad }
function Set-TeleportLoginKubeProd { tsh kube login live-prod-eks-green --proxy=youlend.teleport.sh:443 --auth=ad }
function Set-TeleportLoginKubeSandbox { tsh kube login aslive-sandbox-eks-green --proxy=youlend.teleport.sh:443 --auth=ad }
function Set-TeleportLoginKubeStaging { tsh kube login aslive-staging-eks-green --proxy=youlend.teleport.sh:443 --auth=ad }
function Set-TeleportLoginKubeUSProd { tsh kube login live-usprod-eks-green --proxy=youlend.teleport.sh:443 --auth=ad }
function Set-TeleportLogout { tsh logout }
function Set-TeleportLogoutApps { tsh apps logout }

# Role mapping with account IDs
$roleMap = @{
    "admin"     = @{ RO = "admin"; RW = "sudo_admin"; ACCOUNT_ID = "310920692287"; APP_NAME = "yl-admin" }
    "corepl"    = @{ RO = "coreplayground"; RW = $null; ACCOUNT_ID = "997382069558"; APP_NAME = "yl-coreplayground" }
    "datapl"    = @{ RO = "dataplayground"; RW = $null; ACCOUNT_ID = "937787910409"; APP_NAME = "yl-dataplayground" }
    "dev"       = @{ RO = "development"; RW = "sudo_dev"; ACCOUNT_ID = "777909771556"; APP_NAME = "yl-development" }
    "prod"      = @{ RO = "prod"; RW = "sudo_prod"; ACCOUNT_ID = "902371465413"; APP_NAME = "yl-prod" }
    "sandbox"   = @{ RO = "sandbox"; RW = "sudo_sandbox"; ACCOUNT_ID = "517395983949"; APP_NAME = "yl-sandbox" }
    "staging"   = @{ RO = "staging"; RW = "sudo_staging"; ACCOUNT_ID = "871980946913"; APP_NAME = "yl-staging" }
    "usprod"    = @{ RO = "usprod"; RW = "sudo_usprod"; ACCOUNT_ID = "359939295825"; APP_NAME = "yl-usprod" }
    "usstaging" = @{ RO = "usstaging"; RW = "sudo_usstaging"; ACCOUNT_ID = "973302516471"; APP_NAME = "yl-usstaging" }
}

# Generate all the tp* shortcut functions dynamically
foreach ($account in $roleMap.Keys) {
    # Generate RW function
    $rwFunctionScript = "function global:tp${account}RW { Switch-TeleportAWSRole -Account '$account' -AccessLevel 'RW' }"
    Invoke-Expression $rwFunctionScript
    
    # Generate RO function
    $roFunctionScript = "function global:tp${account}RO { Switch-TeleportAWSRole -Account '$account' -AccessLevel 'RO' }"
    Invoke-Expression $roFunctionScript
    
    # For backward compatibility, make tp$account point to the RW version
    $aliasFunctionScript = "function global:tp$account { Switch-TeleportAWSRole -Account '$account' -AccessLevel 'RW' }"
    Invoke-Expression $aliasFunctionScript
}

# Quickly obtain AWS credentials via Teleport
function Get-TeleportAWS { tsh aws }

# Unified function to login to Teleport app and assume AWS role
function Switch-TeleportAWSRole {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Account,
        
        [Parameter()]
        [ValidateSet("RW", "RO")]
        [string]$AccessLevel = "RW"
    )

    # Validate account
    if (-not $roleMap.ContainsKey($Account)) {
        Write-Host "Error: Invalid account name '$Account'." -ForegroundColor Red
        return
    }

    $accountData = $roleMap[$Account]
    $role = $accountData[$AccessLevel]
    $accountId = $accountData["ACCOUNT_ID"]
    $appName = $accountData["APP_NAME"]

    if (-not $role -or -not $accountId -or -not $appName) {
        Write-Host "Error: Missing role, account ID, or app name for '$Account' ($AccessLevel)." -ForegroundColor Red
        return
    }

    # Get current app to handle logout if needed
    $currentApp = tsh apps ls -f text | Select-String "^> (\S+)" | ForEach-Object { $_.Matches.Groups[1].Value }
    if ($currentApp -and $currentApp -ne $appName) {
        Write-Host "Logging out of current app: $currentApp..." -ForegroundColor Yellow
        tsh apps logout $currentApp | Out-Null
    }

    # Login to the appropriate app with the specified role
    Write-Host "Logging into Teleport App: $appName with role: $role..." -ForegroundColor Cyan
    tsh apps login $appName --aws-role $role | Out-Null

    # Assume the AWS role
    $result = tsh aws sts assume-role --role-arn "arn:aws:iam::${accountId}:role/$role" --role-session-name $role | ConvertFrom-Json

    if (-not $result.Credentials) {
        Write-Host "Error: Failed to assume role." -ForegroundColor Red
        return
    }

    # Set credentials in environment variables
    $env:AWS_ACCESS_KEY_ID = $result.Credentials.AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $result.Credentials.SecretAccessKey
    $env:AWS_SESSION_TOKEN = $result.Credentials.SessionToken

    Write-Host "Logged Into: $Account - ($AccessLevel)." -ForegroundColor Green
}

# Main Kubernetes function
function Invoke-TeleportKube {
    param(
        [Parameter()]
        [switch]$c,
        
        [Parameter()]
        [switch]$l,
        
        [Parameter(Position = 0)]
        [string]$Command,
        
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    # Handle switches first
    if ($c) { 
        Invoke-TeleportKubeInteractiveLogin
        return 
    }
    if ($l) { 
        tsh kube ls -f text
        return 
    }

    # Handle commands
    switch ($Command) {
        "ls" { tsh kube ls -f text }
        "login" {
            if ($Arguments -and $Arguments[0] -eq "-c") {
                Invoke-TeleportKubeInteractiveLogin
            }
            else {
                tsh kube login $Arguments
            }
        }
        "sessions" { tsh kube sessions $Arguments }
        "exec" { tsh kube exec $Arguments }
        "join" { tsh kube join $Arguments }
        $null { Write-Host "Usage: tkube {-c | -l | ls | login [cluster_name | -c] | sessions | exec | join }" }
        default {
            Write-Host "Usage: tkube {-c | -l | ls | login [cluster_name | -c] | sessions | exec | join }"
        }
    }
}

# Main function for Teleport apps
function Invoke-TeleportAWS {
    param(
        [Parameter()]
        [switch]$c,
        
        [Parameter()]
        [switch]$l,
        
        [Parameter(Position = 0)]
        [string]$Command,
        
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    # Handle switches first
    if ($c) { 
        Invoke-TeleportAWSInteractiveLogin
        return 
    }
    if ($l) { 
        tsh apps ls -f text
        return 
    }

    # Handle commands
    switch ($Command) {
        "login" {
            if ($Arguments -and $Arguments[0] -eq "-c") {
                Invoke-TeleportAWSInteractiveLogin
            }
            else {
                tsh apps login $Arguments
            }
            return
        }
        $null { Write-Host "Usage: tawsp { -c | -l | login [app_name | -c] }" }
        default {
            Write-Host "Usage: tawsp { -c | -l | login [app_name | -c] }"
        }
    }
}

# Helper function for interactive app login with AWS role selection
function Invoke-TeleportAWSInteractiveLogin {
    # Get the list of apps
    $output = tsh apps ls -f text
    if (-not $output) {
        Write-Host "No apps available."
        return 1
    }

    $lines = $output -split "`n"
    $header = $lines[0..1]
    $apps = $lines[2..($lines.Length-1)]

    if (-not $apps) {
        Write-Host "No apps available."
        return 1
    }

    # Display header and numbered list of apps
    $header | ForEach-Object { Write-Host $_ }
    $apps | Where-Object { $_ -match '\S' } | ForEach-Object -Begin {$i=1} -Process {
        Write-Host ("{0,2}. {1}" -f $i++, $_)
    }

    # Prompt for app selection
    $appChoice = Read-Host "Choose app to login (number)"
    if (-not $appChoice) {
        Write-Host "No selection made. Exiting."
        return 1
    }

    $chosenLine = $apps[$appChoice - 1]
    if (-not $chosenLine) {
        Write-Host "Invalid selection."
        return 1
    }

    # If the first column is ">", use the second column; otherwise, use the first
    $app = if ($chosenLine -match '^>') {
        ($chosenLine -split '\s+')[1]
    } else {
        ($chosenLine -split '\s+')[0]
    }

    Write-Host "Selected app: $app"

    # Log out of the selected app to force fresh AWS role output
    Write-Host "Logging out of app: $app..."
    tsh apps logout $app > $null 2>&1

    # Run tsh apps login to capture the AWS roles listing
    $loginOutput = tsh apps login $app 2>&1

    # Extract the AWS roles section
    $roleSection = $loginOutput | Select-String -Pattern "Available AWS roles:" -Context 0,20
    if (-not $roleSection) {
        Write-Host "No AWS roles info found. Attempting direct login..."
        tsh apps login $app
        return
    }

    $roleLines = $roleSection.Context.PostContext | Where-Object { $_ -match '\S' -and $_ -notmatch 'ERROR:' }
    $roleHeader = $roleLines[0..1]
    $rolesList = $roleLines[2..($roleLines.Length-1)]

    if (-not $rolesList) {
        Write-Host "No roles found in the AWS roles listing."
        Write-Host "Logging you into app '$app' without specifying an AWS role."
        tsh apps login $app
        return
    }

    Write-Host "Available AWS roles:"
    $roleHeader | ForEach-Object { Write-Host $_ }
    $rolesList | ForEach-Object -Begin {$i=1} -Process {
        Write-Host ("{0,2}. {1}" -f $i++, $_)
    }

    # Prompt for role selection
    $roleChoice = Read-Host "Choose AWS role (number)"
    if (-not $roleChoice) {
        Write-Host "No selection made. Exiting."
        return 1
    }

    $chosenRoleLine = $rolesList[$roleChoice - 1]
    if (-not $chosenRoleLine) {
        Write-Host "Invalid selection."
        return 1
    }

    $roleName = ($chosenRoleLine -split '\s+')[0]
    if (-not $roleName) {
        Write-Host "Invalid selection."
        return 1
    }

    Write-Host "Logging you into app: $app with AWS role: $roleName"
    tsh apps login $app --aws-role $roleName
}

# Helper function for interactive Kubernetes login
function Invoke-TeleportKubeInteractiveLogin {
    $output = tsh kube ls -f text
    if (-not $output) {
        Write-Host "No Kubernetes clusters available."
        return 1
    }

    $lines = $output -split "`n"
    $header = $lines[0..1]
    $clusters = $lines[2..($lines.Length-1)]

    if (-not $clusters) {
        Write-Host "No Kubernetes clusters available."
        return 1
    }

    # Show header and numbered list of clusters
    $header | ForEach-Object { Write-Host $_ }
    $clusterList = $clusters | Where-Object { $_ -match '\S' } | ForEach-Object -Begin {$i=1} -Process {
        Write-Host ("{0,2}. {1}" -f $i++, $_)
    }

    # Prompt for selection
    $choice = Read-Host "Choose cluster to login (number)"
    if (-not $choice) {
        Write-Host "No selection made. Exiting."
        return 1
    }

    $chosenLine = $clusters[$choice - 1]
    if (-not $chosenLine) {
        Write-Host "Invalid selection."
        return 1
    }

    $cluster = ($chosenLine -split '\s+')[0]
    if (-not $cluster) {
        Write-Host "Invalid selection."
        return 1
    }

    Write-Host "Logging you into cluster: $cluster"
    tsh kube login $cluster
}

# Set up standard aliases
Set-Alias -Name taws -Value Get-TeleportAWS
Set-Alias -Name tawsp -Value Invoke-TeleportAWS
Set-Alias -Name tkube -Value Invoke-TeleportKube
Set-Alias -Name tl -Value Set-TeleportLogin
Set-Alias -Name tla -Value Set-TeleportLogoutApps
Set-Alias -Name tlo -Value Set-TeleportLogout

Set-Alias -Name tkadmin -Value Set-TeleportLoginKubeAdmin
Set-Alias -Name tkdev -Value Set-TeleportLoginKubeDev
Set-Alias -Name tkprod -Value Set-TeleportLoginKubeProd
Set-Alias -Name tksandbox -Value Set-TeleportLoginKubeSandbox
Set-Alias -Name tkstaging -Value Set-TeleportLoginKubeStaging
Set-Alias -Name tkusprod -Value Set-TeleportLoginKubeUSProd

Set-Alias -Name tstat -Value Get-TeleportStatus

#Write-Host "Available tp* functions:" -ForegroundColor Cyan
#Get-Command -Name tp* | ForEach-Object {
#    Write-Host "$($_.Name)" -ForegroundColor Cyan
#}