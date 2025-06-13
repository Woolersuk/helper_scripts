function th {
    $Command = $args[0]
	if ($args.Count -gt 1) {
		$SubArgs = $args[1..($args.Count - 1)]
	} else {
		$SubArgs = @()
	}

	function th_login {
		
		# Check if already logged in
		if (tsh status 2>$null | Select-String -Quiet 'Logged in as:') {
			Write-Host
			Write-Host "Already logged in to Teleport." 
			return
		}

		Write-Host "`nLogging you into Teleport..."
		
		# Start login in background
		Start-Process tsh -ArgumentList 'login', '--auth=ad', '--proxy=youlend.teleport.sh:443' -WindowStyle Hidden
		# Wait up to 15 seconds (30 x 0.5s) for login to complete
		for ($i = 0; $i -lt 60; $i++) {
			Start-Sleep -Milliseconds 500
			if (tsh status 2>$null | Select-String -Quiet 'Logged in as:') {
				Write-Host "`nLogged in successfully" -ForegroundColor Green
				return
			}
		}

		Write-Host "`nTimed out waiting for Teleport login."
		return
	}

	# ===========================
	# Helper - Clean up session  
	# ===========================
	function th_kill {
		# Unset AWS environment variables
		Remove-Item Env:AWS_ACCESS_KEY_ID -ErrorAction SilentlyContinue
		Remove-Item Env:AWS_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
		Remove-Item Env:AWS_CA_BUNDLE -ErrorAction SilentlyContinue
		Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
		Remove-Item Env:ACCOUNT -ErrorAction SilentlyContinue
		Remove-Item Env:AWS_DEFAULT_REGION -ErrorAction SilentlyContinue

		Write-Host "`nCleaning up Teleport session..." -ForegroundColor White

		# Kill all running processes related to tsh
		Get-NetTCPConnection -State Listen |
			ForEach-Object {
				$tshPid = $_.OwningProcess
				$proc = Get-Process -Id $tshPid -ErrorAction SilentlyContinue
				if ($proc -and $proc.Name -match "tsh") {
					Stop-Process -Id $tshPid -Force
				}
			}

		tsh logout *>$null
		Write-Host "`nKilled all running tsh proxies"

		# Remove all profile files from temp
		$tempDir = $env:TEMP
		$patterns = @("yl*", "tsh*", "admin_*", "launch_proxy*")
		foreach ($pattern in $patterns) {
			Get-ChildItem -Path (Join-Path $tempDir $pattern) -ErrorAction SilentlyContinue | Remove-Item -Force
		}

		Write-Host "Removed all tsh files from /tmp"

		# Remove related lines from PowerShell profile
		if (Test-Path $PROFILE) {
			$profileLines = Get-Content $PROFILE
			$filteredLines = $profileLines | Where-Object {
				$_ -notmatch 'Temp\\yl-.*\.ps1'
			}
			$filteredLines | Set-Content -Path $PROFILE -Encoding UTF8
			Write-Output "Removed all .PROFILE inserts."
		}

		# Log out of all TSH apps
		tsh apps logout 2>$null
		Write-Host "`nLogged out of all apps & proxies.`n" -ForegroundColor Green
	}
    # ============================================================
    # ======================= Kubernetes =========================
    # ============================================================
    function tkube_elevated_login {
		while ($true) {
			Write-Host "`n==================== Privileged Access =====================" -ForegroundColor White
			Write-Host
			Write-Host "Do you require elevated access? (y/n): " -ForegroundColor White -NoNewLine
			$elevated = Read-Host
			
			if ($elevated -match '^[Yy]$') {
				# Placeholder: Add checks for new Kubernetes roles here if needed
				Write-Host "`nEnter your reason for request: " -ForegroundColor White -NoNewLine
				$reason = Read-Host

				Write-Host "`nAccess request sent for: " -ForegroundColor White -NoNewLine
				Write-Host "production-eks-clusters" -ForegroundColor Green
				tsh request create --roles production-eks-clusters --reason "$reason"
				$env:ELEVATED = "true"
				return
			}
			elseif ($elevated -match '^[Nn]$') {
				Write-Host
				Write-Host "Request creation skipped."
				return
			}
			else {
				Write-Host "Invalid input. Please enter Y or N."
			}
		}
	}
    # Interactive helper function
    function tkube_interactive_login {
		th_login
		Write-Host $env:ELEVATED
		if($env:ELEVATED -ne "true"){
			tkube_elevated_login
		}
		
		# Get the output of the Kubernetes cluster list
		$output = tsh kube ls -f text
		if (-not $output) {
			Write-Host "No Kubernetes clusters available."
			return
		}

		# Split into lines
		$lines = $output -split "`n"
		if ($lines.Count -le 2) {
			Write-Host "No Kubernetes clusters available."
			return
		}

		$header = $lines[0..1] -join "`n"
		$clusters = $lines[2..($lines.Count - 1)]
		$clusters = $clusters | Where-Object { $_.Trim() -ne '' }

		# Display header and numbered list
		Write-Host "`n======================= Kubernetes =========================" -ForegroundColor White
		Write-Host "`nAvailable Clusters:`n" -ForegroundColor White
		Write-Host $header
		for ($i = 0; $i -lt $clusters.Count; $i++) {
			Write-Host ("{0,2}. {1}" -f ($i + 1), $clusters[$i]) 
		}

		# Prompt for selection
		Write-Host "`nChoose cluster to login (number): " -ForegroundColor White -NoNewLine 
		$choice = Read-Host

		if (-not $choice -or -not ($choice -match '^\d+$')) {
			Write-Host "No valid selection made. Exiting."
			return
		}

		$index = [int]$choice - 1

		if ($index -lt 0 -or $index -ge $clusters.Count) {
			Write-Host "Invalid selection." -ForegroundColor Red
			return
		}

		# Extract cluster name (first column of the selected line)
		$chosenLine = $clusters[$index]
		$cluster = ($chosenLine -split '\s+')[0]

		if (-not $cluster) {
			Write-Host "Invalid selection." -ForegroundColor Red
			return
		}

		Write-Host "`nLogging you into cluster: " -ForegroundColor White -NoNewLine 
		Write-Host $cluster -ForegroundColor Green
		tsh kube login $cluster 1>$null
		Write-Host "`nLogged in successfully." -ForegroundColor Green
		$env:ELEVATED = "false"
		return
    }

    # th kube handler function 
    function tkube {
		param (
			[string[]]$Args
		)

		if ($Args.Count -eq 0) {
			tkube_interactive_login
			return
		}

		switch ($Args[0]) {
			"-l" {
			tsh kube ls -f text
			}
			"-s" {
			tsh sessions ls --kind=kube 
			}
			"-e" {
			$restArgs = $Args[1..($Args.Length - 1)]
			tsh kube exec @restArgs
			}
			"-j" {
			$restArgs = $Args[1..($Args.Length - 1)]
			tsh kube join @restArgs
			}
			default {
			Write-Output "Usage:"
			Write-Output "`t-l : List all Kubernetes clusters"
			Write-Output "`t-s : List all current sessions"
			Write-Output "`t-e : Execute a command"
			Write-Output "`t-j : Join a session"
			}
		}
    }

    # ============================================================
    # =========================== AWS ============================
    # ============================================================

	function Get-Credentials {
		# Get active app
		$app = & tsh apps ls -f text | ForEach-Object {
			if ($_ -match '^>\s+(\S+)') { $matches[1] }
		}

		if (-not $app) {
			Write-Host "No active app found. Run 'tsh apps login <app>' first."
			return 1
		}

		Write-Host "`nPreparing environment for app: $app"

		$tempDir = $env:TEMP
		$logFile = Join-Path $tempDir "tsh_proxy_output_$app.log"
		$envSnapshot = Join-Path $tempDir "$app.ps1"
		$scriptPath = Join-Path $tempDir "launch_proxy_$app.ps1"
		$pidFile = Join-Path $tempDir "tsh_proxy_$app.pid"

		# Assign port
		$port = 60000 + ([Math]::Abs($app.GetHashCode()) % 1000)
		Write-Host "Using port " -NoNewLine
		Write-Host $port -ForegroundColor Green -NoNewLine
		Write-Host " for local proxy..."

		# Build proxy command
		$command = "tsh proxy aws --app `"$app`" --port $port 2>&1 | Tee-Object -FilePath `"$logFile`""
		Set-Content -Path $scriptPath -Value $command

		# Start proxy in background
		$proc = Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden", "-ExecutionPolicy Bypass", "-File `"$scriptPath`"" -PassThru
		$proc.Id | Out-File -FilePath $pidFile

		# Wait for credentials
		$timeout = 20
		$waitCount = 0
		while ($true) {
			Start-Sleep -Milliseconds 500
			if ((Test-Path $logFile) -and (Select-String -Path $logFile -Pattern '\$Env:AWS_ACCESS_KEY_ID=' -Quiet)) {
				break
			}
			$waitCount++
			if ($waitCount -ge $timeout) {
				Write-Host "Timed out waiting for AWS credentials."
				return
			}
		}

		# Confirm port is listening
		Start-Sleep -Milliseconds 500
		$tcpListening = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
		if (-not $tcpListening) {
			Write-Host "Proxy process failed to bind to port $port."
			return
		}

		# Extract and apply environment variables
		$exports = Get-Content $logFile | Where-Object { $_ -match '^\s*\$Env:\w+=' }
		Remove-Item -Path $envSnapshot -ErrorAction SilentlyContinue

		foreach ($line in $exports) {
			if ($line -match '\$Env:(\w+)="([^"]+)"') {
				$name = $matches[1]
				$val = $matches[2]
				Set-Item -Path "Env:$name" -Value $val
				"`$env:${name} = '$val'" | Out-File -Append -FilePath $envSnapshot
			}
		}

		# Add ACCOUNT and REGION
		"`$env:ACCOUNT = '$app'" | Out-File -Append -FilePath $envSnapshot
		Set-Item -Path Env:ACCOUNT -Value $app

		$region = if ($app -like "yl-us*") { "us-east-2" } else { "eu-west-1" }
		"`$env:AWS_DEFAULT_REGION = '$region'" | Out-File -Append -FilePath $envSnapshot
		Set-Item -Path Env:AWS_DEFAULT_REGION -Value $region

		# Clean and update PowerShell profile
		$profilePath = $PROFILE
		$sourceLine = "if (Test-Path '$envSnapshot') { . '$envSnapshot' }"

		if (Test-Path $profilePath) {
			$existingLines = Get-Content $profilePath
			$filteredLines = $existingLines | Where-Object { $_ -notmatch 'Temp\\yl-.*\.ps1' }
			$updatedLines = $filteredLines + $sourceLine
			Set-Content -Path $profilePath -Value $updatedLines -Encoding UTF8
		} else {
			Set-Content -Path $profilePath -Value $sourceLine -Encoding UTF8
		}

		Write-Host "`nCredentials applied and stored for: " -ForegroundColor White -NoNewLine
		Write-Host $app -ForegroundColor Green
		Write-Host
	}

	function Create-Proxy {
		while ($true) {
			Write-Host "`n======================== Proxy Creation =========================" 
			Write-Host "`nUsing a proxy will allow you to use aws commands without needing"
			Write-Host "to prefix with tsh..."
			Write-Host "`nWould you like to create a proxy? (y/n): " -ForegroundColor White -NoNewLine
			$proxy = Read-Host 

			switch -Regex ($proxy) {
				'^[Yy]$' {
					Get-Credentials
					break
				}
				'^[Nn]$' {
					Write-Host "`nProxy creation skipped.`n"
					return
				}
				default {
					Write-Host "Invalid input. Please enter Y or N."
				}
			}
		}
	}

	function Raise-Request {
		param (
			[string]$App
		)

		while ($true) {
			Write-Host "`nWould you like to raise a privilege request? (y/n): " -ForegroundColor White -NoNewLine
			$request = Read-Host 

			switch -Regex ($request) {
				'^[Yy]$' {
					Write-Host "`nEnter request reason: " -ForegroundColor White -NoNewLine
					$reason = Read-Host 

					switch ($App) {
						"yl-production" {
							Write-Host "`nAccess request sent for sudo_prod." -ForegroundColor Green
							tsh request create --roles sudo_prod_role --reason $reason
							$script:RAISED_ROLE = "sudo_prod"
							return $true
						}
						"yl-usproduction" {
							Write-Host
							Write-Host "Access request sent for sudo_usprod." -ForegroundColor Green
							tsh request create --roles sudo_usprod_role --reason $reason
							$script:RAISED_ROLE = "sudo_usprod"
							return $true
						}
						default {
							return $false
						}
					}
				}
				'^[Nn]$' {
					return $false
				}
				default {
					Write-Host "Invalid input. Please enter Y or N."
				}
			}
		}
	}

    function tawsp_interactive_login {
		th_login
		# Get the list of apps
		$output = tsh apps ls -f text
		if (-not $output) {
			Write-Host "No apps available."
			return
		}

		$lines = $output -split "`n"
		if ($lines.Count -le 2) {
			Write-Host "No apps available."
			return
		}

		
		$header = $lines[0..1] -join "`n" 
		$apps = $lines[2..($lines.Count - 1)]
		$apps = $apps | Where-Object { $_.Trim() -ne '' } 
		# Display numbered list of apps

		Write-Host "`n========================= AWS ===========================" -ForegroundColor White
		Write-Host "`nAvailable Apps:`n" -ForegroundColor White
		Write-Host $header
		for ($i = 0; $i -lt $apps.Count; $i++) {
			Write-Host ("{0,2}. {1}" -f ($i + 1), $apps[$i])
		}

		# Prompt for app selection
		Write-Host "`nSelect app (number): " -ForegroundColor White -NoNewLine
		$appChoice = Read-Host 
		if (-not $appChoice -or -not ($appChoice -match '^\d+$')) {
			Write-Host "No valid selection made. Exiting."
			return 1
		}

		$appIndex = [int]$appChoice - 1
		if ($appIndex -lt 0 -or $appIndex -ge $apps.Count) {
			Write-Host "Invalid selection." -ForegroundColor Red
			return 1
		}

		# Determine selected app name
		$chosenLine = $apps[$appIndex]
		$columns = $chosenLine -split '\s+'
		$app = if ($columns[0] -eq ">") { $columns[1] } else { $columns[0] }

		if (-not $app) {
			Write-Host "Invalid selection."
			return 1
		}

		Write-Host "`nSelected app: " -ForegroundColor White -NoNewLine
		Write-Host $app -ForegroundColor Green

		tsh apps logout *> $null

		# Attempt login to get AWS role info (expecting error but want the printed roles)
		$loginOutput = tsh apps login $app 2>&1

		# Extract AWS roles section
		$startMarker = "Available AWS roles:"
		$endMarker = "ERROR: --aws-role flag is required"
		$inSection = $false
		$roleSection = @()

		foreach ($line in $loginOutput -split "`n") {
			if ($line -match $startMarker) {
			$inSection = $true
			continue
			}
			if ($line -match $endMarker) {
			$inSection = $false
			break
			}
			if ($inSection -and $line.Trim() -ne "" -and $line -notmatch "ERROR:") {
			$roleSection += $line
			}
		}

		if (-not $roleSection) {
			$defaultRole = ($loginOutput | Select-String -Pattern 'arn:aws:iam::[^ ]*').Matches.Value -replace '^.*role/', ''
			Write-Host "`n======================= Privilege Request =========================" -ForegroundColor White
			Write-Host "`nNo privileged roles found. Your only available role is: " -ForegroundColor White -NoNewLine
			Write-Host $defaultRole -ForegroundColor Green

			if (Raise-Request -App $app) {
				$role = $RAISED_ROLE
				Write-Host "`nLogging you into " -ForegroundColor White -NoNewLine
				Write-Host $app -ForegroundColor Green -NoNewLine
				Write-Host " as " -ForegroundColor White -NoNewLine
				Write-Host $role -ForegroundColor Green
				tsh apps login $app --aws-role $role *>$null
				Write-Host "`nLogged in successfully!" -ForegroundColor Green
				Create-Proxy
			} else {
				Write-Host "`nLogging you into " -ForegroundColor White -NoNewLine
				Write-Host $app -ForegroundColor Green -NoNewLine
				Write-Host " as " -ForegroundColor White -NoNewLine
				Write-Host $defaultRole -ForegroundColor Green
				tsh apps login $app --aws-role $defaultRole *>$null
				Write-Host "`nLogged in successfully!" -ForegroundColor Green
				return
			}

			return
		}

		$roleHeader = $roleSection[0..1] -join "`n"
		$rolesList = $roleSection[2..($roleSection.Count - 1)]

		if (-not $rolesList) {
			Write-Host "No roles found in the AWS roles listing."
			Write-Host "Logging you into app '$app' without specifying an AWS role."
			tsh apps login $app
			return
		}

		Write-Host "`nAvailable roles:`n" -ForegroundColor White
		Write-Host $roleHeader
		for ($i = 0; $i -lt $rolesList.Count; $i++) {
			Write-Host ("{0,2}. {1}" -f ($i + 1), $rolesList[$i])
		}

		# Prompt for role selection
		Write-Host "`nSelect role (number): " -ForegroundColor White -NoNewLine
		$roleChoice = Read-Host 
		if (-not $roleChoice -or -not ($roleChoice -match '^\d+$')) {
			Write-Host "No valid selection made. Exiting."
			return 1
		}

		$roleIndex = [int]$roleChoice - 1
		if ($roleIndex -lt 0 -or $roleIndex -ge $rolesList.Count) {
			Write-Host "Invalid selection."
			return 1
		}

		$roleLine = $rolesList[$roleIndex]
		$roleName = ($roleLine -split '\s+')[0]

		if (-not $roleName) {
			Write-Host "Invalid selection."
			return 1
		}

		Write-Host "`nLogging you into " -ForegroundColor White -NoNewLine
		Write-Host $app -ForegroundColor Green -NoNewLine
		Write-Host " as " -ForegroundColor White -NoNewLine
		Write-Host $roleName -ForegroundColor Green
		tsh apps login $app --aws-role $roleName *>$null
		Write-Host "`nLogged in successfully!" -ForegroundColor Green

		while ($true) {
			Write-Host "`n======================= Proxy Creation ========================" -ForegroundColor White
			Write-Host "`nUsing a proxy will allow you to use aws commands without needing"
			Write-Host "to prefix with tsh..."
			Write-Host "`nWould you like to create a proxy? (y/n): " -ForegroundColor White -NoNewLine
			$response = Read-Host 

			if ($response -match '^[Yy]$') {
				Get-Credentials
				break
			} elseif ($response -match '^[Nn]$') {
				Write-Host "Proxy creation skipped."
				break
			} else {
				Write-Host "Invalid input. Please enter Y or N." -ForegroundColor Red
			}
		}
	}
	

	function tawsp {
		if ($Args.Count -eq 0) {
			tawsp_interactive_login
			return
		}

		switch ($Args[0]) {
			"-l" {
				tsh apps ls -f text
			}
			default {
				Write-Host "Usage:"
				Write-Host "`t-l : List all accounts"
			}
		}
	}

	# ============================================================
    # ======================== Terraform =========================
    # ============================================================
	function Terraform-Login {
		th_login
		tsh apps logout *>$null
		Write-Host "`nLogging into " -ForegroundColor White -NoNewLine
		Write-Host "yl-admin " -ForegroundColor Green -NoNewLine
		Write-Host "as " -ForegroundColor White -NoNewLine
		Write-Host "sudo_admin" -ForegroundColor Green
		tsh apps login "yl-admin" --aws-role "sudo_admin" *>$null
		Get-Credentials
		Write-Output "`nLogged in successfully" -ForegroundColor Green
	}

    # ============================================================
    # ======================== Main Handler ======================
    # ============================================================
    switch ($Command) {
		{ $_ -in @("kube", "k") } {
			if ($SubArgs[0] -eq "-h") {
			Write-Output "Usage:"
			Write-Output "-l : List all Kubernetes clusters"
			Write-Output "-s : List all current sessions"
			Write-Output "-e : Execute a command"
			Write-Output "-j : Join a session"
			} else {
			tkube @SubArgs
			}
		}
		{ $_ -in @("terra", "t") } {
			if ($SubArgs[0] -eq "-h") {
			Write-Output "Logs into yl-admin as sudo-admin"
			} else {
			Terraform-Login @SubArgs
			}
		}
		{ $_ -in @("aws", "a") } {
			if ($SubArgs[0] -eq "-h") {
			Write-Output "Usage:"
			Write-Output "-l : List all accounts"
			} else {
			tawsp @SubArgs
			}
		}
		{ $_ -in @("logout", "l") } {
			if ($SubArgs[0] -eq "-h") {
			Write-Output "Logout from all proxies."
			} else {
			th_kill
			}
		}
		{ $_ -in @("login") } {
			if ($SubArgs[0] -eq "-h") {
			Write-Output "Simple log in to Teleport."
			} else {
			tsh login --auth=ad --proxy=youlend.teleport.sh:443
			}
		}
		default {
			Write-Host "`nUsage:" -ForegroundColor White
			Write-Output "`nth kube   | k : Kubernetes login options"
			Write-Output "th aws    | a : AWS login options"
			Write-Output "th terra  | t : Log into yl-admin as sudo-admin"
			Write-Output "th logout | l : Logout from all proxies"
			Write-Output "th login      : Simple login to Teleport"
			Write-Output "--------------------------------------------------------------------------"
			Write-Output "For specific instructions on any of the above, run: th <option> -h"
			Write-Host "`nPages:" -ForegroundColor White
			Write-Host "`nQuickstart: " -ForegroundColor White -NoNewLine
			Write-Host "https://youlend.atlassian.net/wiki/spaces/ISS/pages/1384972392/TH+-+Teleport+Helper+Quick+Start" -ForegroundColor Blue
			Write-Host "Docs: " -ForegroundColor White -NoNewLine
			Write-Host "https://youlend.atlassian.net/wiki/spaces/ISS/pages/1378517027/TH+-+Teleport+Helper+Docs" -ForegroundColor Blue
			Write-Host "`n--> (Hold CRTL + Click to open links)`n" -ForegroundColor White
		}
    }
}
