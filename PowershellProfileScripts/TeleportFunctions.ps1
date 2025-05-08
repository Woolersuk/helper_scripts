# Teleport CLI shortcuts for PowerShell
function Get-TeleportStatus { tsh status }
function Set-TeleportLogin { tsh login --auth=ad --proxy=youlend.teleport.sh:443 }
function Set-TeleportLoginKubeAdmin { tsh kube login headquarter-admin-eks-blue --proxy=youlend.teleport.sh:443 --auth=ad }
function Set-TeleportLoginKubeDev { tsh kube login aslive-dev-eks-blue --proxy=youlend.teleport.sh:443 --auth=ad }
function Set-TeleportLoginKubeProd { tsh kube login live-prod-eks-blue --proxy=youlend.teleport.sh:443 --auth=ad }
function Set-TeleportLoginKubeSandbox { tsh kube login aslive-sandbox-eks-blue --proxy=youlend.teleport.sh:443 --auth=ad }
function Set-TeleportLoginKubeStaging { tsh kube login aslive-staging-eks-blue --proxy=youlend.teleport.sh:443 --auth=ad }
function Set-TeleportLoginKubeUSProd { tsh kube login live-usprod-eks-blue --proxy=youlend.teleport.sh:443 --auth=ad }
function Set-TeleportLogout { tsh logout }
function Set-TeleportLogoutApps { tsh apps logout }
function Login-TPAdmin { tl && tsh apps login yl-admin --aws-role sudo_admin }
function Login-TPDev { tl && tsh apps login yl-development --aws-role sudo_dev }
function Login-TPProd { tl && tsh apps login yl-production --aws-role sudo_prod }
function Login-TPUSProd { tl && tsh apps login yl-usproduction --aws-role sudo_usprod }
function Login-TPSandbox { tl && tsh apps login yl-sandbox --aws-role sudo_sandbox }
function Login-TPStaging { tl && tsh apps login yl-staging --aws-role sudo_staging }
function Login-TPUSStaging { tl && tsh apps login yl-usstaging --aws-role sudo_usstaging }

# Helper function to check if user is logged in
function Test-TeleportLogin {
    $status = tsh status 2>&1
    return -not ($status -match "ERROR: Not logged in.")
}

# Helper function to ensure user is logged in before executing commands
function Ensure-TeleportLogin {
    if (-not (Test-TeleportLogin)) {
        Write-Host "Not logged in to Teleport. Logging in now..." -ForegroundColor Yellow
        Set-TeleportLogin
        
        # Verify login was successful
        if (-not (Test-TeleportLogin)) {
            Write-Host "Login failed. Please try manually with 'tl'" -ForegroundColor Red
            return $false
        }
        Write-Host "Login successful" -ForegroundColor blue
    }
    return $true
}

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

# Function specifically for RO access that doesn't attempt to assume role
function Switch-TeleportAWSRoleRO {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Account
    )

    # Ensure user is logged in
    if (-not (Ensure-TeleportLogin)) {
        return
    }

    # Validate account
    if (-not $roleMap.ContainsKey($Account)) {
        Write-Host "Error: Invalid account name '$Account'." -ForegroundColor Red
        return
    }

    $accountData = $roleMap[$Account]
    $role = $accountData["RO"]
    $appName = $accountData["APP_NAME"]

    if (-not $role -or -not $appName) {
        Write-Host "Error: Missing role or app name for '$Account' (RO)." -ForegroundColor Red
        return
    }

    # Get current app to handle logout if needed
    $currentApp = tsh apps ls -f text | Select-String "^> (\S+)" | ForEach-Object { $_.Matches.Groups[1].Value }
    if ($currentApp -and $currentApp -ne $appName) {
        Write-Host "Logging out of current app: $currentApp" -ForegroundColor Yellow
        tsh apps logout $currentApp | Out-Null
    }

    # Login to the appropriate app with the specified role (without trying to assume role)
    Write-Host "Logging into Teleport App: $appName with role: $role" -ForegroundColor Cyan
    tsh apps login $appName --aws-role $role

    Write-Host "Logged Into: $Account - (RO)." -ForegroundColor blue
}

# Unified function to login to Teleport app and assume AWS role
function Switch-TeleportAWSRole {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Account,
        
        [Parameter()]
        [ValidateSet("RW", "RO")]
        [string]$AccessLevel = "RW"
    )

    # Ensure user is logged in
    if (-not (Ensure-TeleportLogin)) {
        return
    }

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
        Write-Host "Logging out of current app: $currentApp" -ForegroundColor Yellow
        tsh apps logout $currentApp | Out-Null
    }

    # Login to the appropriate app with the specified role
    Write-Host "Logging into Teleport App: $appName with role: $role" -ForegroundColor Cyan
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

    Write-Host "Logged Into: $Account - ($AccessLevel)." -ForegroundColor blue
}

# Quickly obtain AWS credentials via Teleport
function Get-TeleportAWS { 
    # Ensure user is logged in
    if (Ensure-TeleportLogin) {
        tsh aws 
    }
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

    # Ensure user is logged in
    if (-not (Ensure-TeleportLogin)) {
        return
    }

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

    # Ensure user is logged in
    if (-not (Ensure-TeleportLogin)) {
        return
    }

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
    # Ensure user is logged in
    if (-not (Ensure-TeleportLogin)) {
        return
    }

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
    # Ensure user is logged in
    if (-not (Ensure-TeleportLogin)) {
        return
    }

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

# Generate all the tp* shortcut functions dynamically
foreach ($account in $roleMap.Keys) {
    # Generate RW function - keep using the original function
    $rwFunctionScript = "function global:tp${account}RW { Switch-TeleportAWSRole -Account '$account' -AccessLevel 'RW' }"
    Invoke-Expression $rwFunctionScript
    
    # Generate RO function - use the new function that skips assume-role
    $roFunctionScript = "function global:tp${account}RO { Switch-TeleportAWSRoleRO -Account '$account' }"
    Invoke-Expression $roFunctionScript
    
    # For backward compatibility, make tp$account point to the RW version
    $aliasFunctionScript = "function global:tp$account { Switch-TeleportAWSRole -Account '$account' -AccessLevel 'RW' }"
    Invoke-Expression $aliasFunctionScript
}

function Start-TeleportProxy {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("admin", "dev", "prod", "usprod", "sandbox", "staging", "usstaging")]
        [string]$Environment
    )

    # Mapping environments to roles and apps
    $envMap = @{
        admin   	= @{ Role = "sudo_admin";      App = "yl-admin" }
        dev   		= @{ Role = "sudo_dev";        App = "yl-development" }
        prod    	= @{ Role = "sudo_prod";       App = "yl-production" }
        usprod  	= @{ Role = "sudo_usprod";     App = "yl-usproduction" }
        sandbox   = @{ Role = "sudo_sandbox";    App = "yl-sandbox" }
        staging   = @{ Role = "sudo_staging";    App = "yl-staging" }
        usstaging = @{ Role = "sudo_usstaging";  App = "yl-usstaging" }
    }

    $logPath = "C:\Tmp\tsh_proxy_$Environment.log"
    $proxyPidFile = "C:\Tmp\tsh_proxy_$Environment.pid"
    $port = 62000 + (Get-Random -Minimum 100 -Maximum 999)  # Random-ish but predictable range
    $timeoutSeconds = 10
    $startTime = Get-Date

    $role = $envMap[$Environment].Role
    $app = $envMap[$Environment].App

    # Run the login
		& tsh apps logout
    Write-Host "Logging into $Environment (role: $role, app: $app)..."
    & tawsp login $app --aws-role $role

    if ($LASTEXITCODE -ne 0) {
        Write-Error "tawsp login failed. Aborting proxy startup."
        return
    }

    # Clean previous log and PID
    if (Test-Path $logPath) { Remove-Item $logPath }
    if (Test-Path $proxyPidFile) { Remove-Item $proxyPidFile }

    # Start proxy in background
    $proxyProcess = Start-Process powershell -ArgumentList "-NoExit", "-Command", "tsh proxy aws --app $app --port $port | Tee-Object -FilePath '$logPath'" -WindowStyle Hidden -PassThru
    $proxyProcess.Id | Out-File $proxyPidFile

    # Wait for log to contain credentials
		while (
				(
						(-not (Test-Path $logPath)) -or 
						(-not ((Get-Content $logPath -Raw) -match 'AWS_ACCESS_KEY_ID='))
				) -and ((Get-Date) - $startTime).TotalSeconds -lt $timeoutSeconds
		) {
				Start-Sleep -Seconds 2
		}

    if (-not (Test-Path $logPath)) {
        Write-Error "Log file not created. Proxy may have failed to start."
        return
    }

    $output = Get-Content $logPath -Raw

    if ($output -match 'AWS_ACCESS_KEY_ID="([^"]+)"') {
        $env:AWS_ACCESS_KEY_ID = $matches[1]
    }
    if ($output -match 'AWS_SECRET_ACCESS_KEY="([^"]+)"') {
        $env:AWS_SECRET_ACCESS_KEY = $matches[1]
    }
    if ($output -match 'AWS_CA_BUNDLE="([^"]+)"') {
        $env:AWS_CA_BUNDLE = $matches[1]
    }
    if ($output -match 'HTTPS_PROXY="([^"]+)"') {
        $env:HTTPS_PROXY = $matches[1]
    }

    Write-Host "[$Environment] Teleport proxy running on port $port. AWS credentials set - kill the session when finished with stop$($Environment)" -Fore Yellow
}

function Stop-TeleportProxy {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("admin", "dev", "prod", "usprod", "sandbox", "staging", "usstaging")]
        [string]$Environment
    )

    $proxyPidFile = "C:\Tmp\tsh_proxy_$Environment.pid"

    if (Test-Path $proxyPidFile) {
        $proxyPid = Get-Content $proxyPidFile
        try {
            Stop-Process -Id $proxyPid -Force
            Write-Host "Stopped Teleport proxy for $Environment (PID $proxyPid)."
        } catch {
            Write-Warning "Failed to stop process with PID $proxyPid. It may have already exited."
        } finally {
            Remove-Item $proxyPidFile -ErrorAction SilentlyContinue
        }
    } else {
        Write-Warning "No saved proxy PID found for $Environment."
    }
}


function Start-TPPAdmin { Start-TeleportProxy -Environment admin }
function Start-TPPDev { Start-TeleportProxy -Environment dev }
function Start-TPPProd { Start-TeleportProxy -Environment prod }
function Start-TPPUSProd { Start-TeleportProxy -Environment usprod }
function Start-TPPSandbox { Start-TeleportProxy -Environment sandbox }
function Start-TPPStaging { Start-TeleportProxy -Environment staging }
function Start-TPPUSStaging { Start-TeleportProxy -Environment usstaging }

function Stop-TPPAdmin { Stop-TeleportProxy -Environment admin }
function Stop-TPPDev { Stop-TeleportProxy -Environment dev }
function Stop-TPPProd { Stop-TeleportProxy -Environment prod }
function Stop-TPPUSProd { Stop-TeleportProxy -Environment usprod }
function Stop-TPPSandbox { Stop-TeleportProxy -Environment sandbox }
function Stop-TPPStaging { Stop-TeleportProxy -Environment staging }
function Stop-TPPUSStaging { Stop-TeleportProxy -Environment usstaging }

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
Set-Alias -Name tppadmin -Value Start-TPPAdmin
Set-Alias -Name tppdev -Value Start-TPPDev
Set-Alias -Name tppprod -Value Start-TPPProd
Set-Alias -Name tppusprod -Value Start-TPPUSProd
Set-Alias -Name tppsandbox -Value Start-TPPSandbox
Set-Alias -Name tppstaging -Value Start-TPPStaging
Set-Alias -Name tppusstaging -Value Start-TPPUSStaging

Set-Alias -Name tpadmin -Value Login-TPAdmin
Set-Alias -Name tpdev -Value Login-TPDev
Set-Alias -Name tpprod -Value Login-TPProd
Set-Alias -Name tpusprod -Value Login-TPUSProd
Set-Alias -Name tpsandbox -Value Login-TPSandbox
Set-Alias -Name tpstaging -Value Login-TPStaging
Set-Alias -Name tpusstaging -Value Login-TPUSStaging

Set-Alias -Name stopadmin -Value Stop-TPPAdmin
Set-Alias -Name stopdev -Value Stop-TPPDev
Set-Alias -Name stopprod -Value Stop-TPPProd
Set-Alias -Name stopusprod -Value Stop-TPPUSProd
Set-Alias -Name stopsandbox -Value Stop-TPPSandbox
Set-Alias -Name stopstaging -Value Stop-TPPStaging
Set-Alias -Name stopusstaging -Value Stop-TPPUSStaging

# Write-Host "Available tp* functions:" -ForegroundColor Cyan
# Get-Command -Name tp* | ForEach-Object {
#    Write-Host "$($_.Name)" -ForegroundColor Cyan
# }

function Show-TeleportAliasPatterns {
    $patterns = @(
        @{ Alias = "tl";          Description = "Teleport Login (base command)" }
        @{ Alias = "tp[env]";     Description = "Login to Teleport as sudo_[env]" }
        @{ Alias = "tpp[env]";    Description = "Start a Teleport proxy for [env]" }
        @{ Alias = "stop[env]";   Description = "Stop a Teleport proxy for [env]" }
        @{ Alias = "tk[env]";     Description = "Login to Kubernetes cluster for [env]" }
        @{ Alias = "tkube";       Description = "Run a generic Kube command via Teleport" }
        @{ Alias = "tla / tlo";   Description = "Logout from all apps or all Teleport sessions" }
    )

    foreach ($item in $patterns) {
        Write-Host ("{0,-12}  - {1}" -f $item.Alias, $item.Description) -ForegroundColor Green
    }
}

#aws sts assume-role <tsh role>