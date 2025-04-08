
function ChangetoWifi {
  Get-NetAdapter -Name Laptop-Eth | Disable-NetAdapter -Confirm:$False
  Get-VM "ubuntu" | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName "Wifi"
}

function ChangetoLAN {
  Get-NetAdapter -Name Laptop-Eth | Enable-NetAdapter
  Get-VM "ubuntu" | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName "Eth-Switch"
}

function NicList { Get-NetIPInterface | Sort-Object ifIndex | Format-Table -AutoSize }

function GetMyExternalIP {
  $MyExternalIP = (Invoke-WebRequest -Uri "https://api.ipify.org/").Content + "/32"
  Write-Host "External IP: $MyExternalIP"
}

Function CleanDownloads {
  Remove-Item "C:\AlexW\Downloads\*.yaml"
  Remove-Item "C:\AlexW\Downloads\*.rdp"
  Remove-Item "C:\AlexW\Downloads\*.zip"
}


function FindInCurrentPath { param ([string] $i); Get-ChildItem -Recurse | Select-String -Pattern $i | Select-Object -Property FileName, Line }
function ApprovePullRequest { param ([string] $i); az repos pr set-vote --id $i --vote approve }
function getPrInfo { param ([string] $i); az repos pr show --id $i | ConvertFrom-Json | Format-List }
function getWorkItemFields {
  param ([string]$i)
  $workItem = az boards work-item show --id $i | ConvertFrom-Json
  $fields = $workItem.fields.PSObject.Properties | Select-Object Name, Value
  $fields | Sort-Object Name | Format-Table Name, Value -AutoSize
}
function removeMeasReviewer { param ([string] $i); az repos pr reviewer remove --id $i --reviewers alex.woolsey@youlend.com }
function AddWorkItemTask { 
  param (
    [string] $Parent,
    [string] $Title,
    [string] $N
  )
  $workItemOutput = az boards work-item create --type Task --title $Title --assigned-to alex.woolsey@youlend.com --area "Youlend-Infrastructure\Dev Enablement" --iteration "Youlend-Infrastructure\Dev Enablement Sprint $N"
  $workItem = $workItemOutput | ConvertFrom-Json
  $workItemId = $workItem.id
  Write-Host "Created: $workItemId" -Fore Cyan
  if ($workItemId) {
    az boards work-item relation add --id $workItemId --relation-type parent --target-id $Parent
  } else {
    Write-Error "Failed to create work item or retrieve its ID."
  }
}

function ListAllEnvVars {
	gci env:* | sort-object name
}

function Add-HostsEntry {
    param (
        [string]$hostname
    )
    
    $hostsFilePath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $ipAddress = "127.0.0.1"
    
    if (Test-Path $hostsFilePath) {
        $existingEntry = Get-Content $hostsFilePath | Where-Object { $_ -like "$ipAddress *$hostname*" }
        
        if ($existingEntry) {
            Write-Host "Entry for $hostname already exists in the hosts file."
        }
        else {
            $newEntry = "`r$ipAddress $hostname"  # Ensure a new line before adding
            Add-Content -Path $hostsFilePath -Value $newEntry
            Write-Host "Entry for $hostname added to the hosts file."
        }
    }
    else {
        Write-Host "Hosts file not found."
    }
}

function Remove-HostsEntry {
    param (
        [string]$hostname
    )

    $hostsFilePath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $ipAddress = "127.0.0.1"

    if (Test-Path $hostsFilePath) {
        $hostsContent = Get-Content $hostsFilePath
        $filteredContent = $hostsContent | Where-Object { $_ -notmatch "^$ipAddress\s+$hostname$" }

        if ($hostsContent.Count -eq $filteredContent.Count) {
            Write-Host "No entry found for $hostname in the hosts file."
        } else {
            $filteredContent | Set-Content -Path $hostsFilePath
            Write-Host "Entry for $hostname removed from the hosts file."
        }
    }
    else {
        Write-Host "Hosts file not found."
    }
}

function GetPRStatus {
    param(
        [string]$PR
    )
    # Get PR data once and convert it
    $prData = az repos pr show --id $PR | ConvertFrom-Json
    
    # Extract required information
    $PRStat = $prData.status
    $WorkItem = $prData.workItemRefs.id -join ", "
    
    # Set color for PR status
    $statusColor = switch ($PRStat) {
        "active" { "Cyan" }
        "completed" { "Green" }
        "abandoned" { "DarkGray" }
        default { "Yellow" }
    }
    
    # Process reviewers' votes
    $reviewerStatus = @()
    foreach ($reviewer in $prData.reviewers) {
        $name = $reviewer.displayName
        $vote = $reviewer.vote
        
        # Determine approval status and color
        $approvalStatus = switch ($vote) {
            10 { "Approved" }
            5  { "Approved with suggestions" }
            0  { "No vote" }
            -5 { "Waiting" }
            -10 { "Rejected" }
            default { "Unknown" }
        }
        
        # Create reviewer status string with color coding
        $reviewerStatus += "$($name): $approvalStatus"
    }
    
    $approvalSummary = if ($reviewerStatus) {
        $reviewerStatus -join ", "
    } else {
        "No reviewers"
    }
    
    # Output PR header with status color
		Write-Host "---------------------------------------------------------------"
    Write-Host "`tWork Item: $WorkItem | " -NoNewline
    Write-Host "PR ($PR) Status: " -NoNewline
		Write-Host "$PRStat" -ForegroundColor $statusColor -NoNewline
    
    # Output reviewer section
    Write-Host "`nReviewers:" -ForegroundColor Green
    
    if ($reviewerStatus.Count -eq 0) {
        Write-Host "  No reviewers assigned" -ForegroundColor Yellow
    } else {
        foreach ($reviewer in $prData.reviewers) {
            $name = $reviewer.displayName
            $vote = $reviewer.vote
            
            # Determine color based on vote
            $voteColor = switch ($vote) {
                10 { "Green" }        # Approved
                5  { "Cyan" }         # Approved with suggestions
                0  { "Yellow" }       # No vote
                -5 { "DarkYellow" }   # Waiting
                -10 { "Red" }         # Rejected
                default { "Gray" }    # Unknown
            }
            
            $voteText = switch ($vote) {
                10 { "Approved" }
                5  { "Approved with suggestions" }
                0  { "No vote" }
                -5 { "Waiting" }
                -10 { "Rejected" }
                default { "Unknown" }
            }
            
            Write-Host "  $($name): " -NoNewline
            Write-Host $voteText -ForegroundColor $voteColor
						Write-Host "---------------------------------------------------------------"
        }
    }
}

function CompletePRRequest {
    param(
        [string]$PR,
        [switch]$CompleteWi
    )
    $params = @(
        'repos pr update'
        "--id $PR"
        '--status completed'
    )
    if ($CompleteWi) {
        $params += '--transition-work-items'
    }
    az @params
}

function Azure-Login {
	$AzureDevOpsPAT = [System.Environment]::GetEnvironmentVariable('PAT')
	Echo $AzureDevOpsPAT | az devops login
	az devops configure --defaults organization=https://dev.azure.com/YouLend project=Youlend-Infrastructure
	Write-Host "Logged into AZ" -Fore Green
}

Set-Alias AHE Add-HostsEntry
Set-Alias AZLogin Azure-Login
Set-Alias RHE Remove-HostsEntry
Set-Alias addtask AddWorkItemTask -Force
Set-Alias approvepr ApprovePullRequest -Force
Set-Alias cdc Clear-DnsClientCache -Force
Set-Alias cleandl -Value CleanDownloads -Force
Set-Alias dig Resolve-DNSName -Force
Set-Alias elan ChangetoLAN -Force
Set-Alias ewifi ChangetoWifi -Force
Set-Alias findit FindInCurrentPath -Force
Set-Alias getmyextip GetMyExternalIP -Force
Set-Alias getpr getPrInfo -Force
Set-Alias getticket getWorkItemFields -Force
Set-Alias getvars ListAllEnvVars -Force
Set-Alias ipcfg Get-NetIPConfiguration -Force
Set-Alias myextip GetMyExternalIP -Force
Set-Alias nsl Resolve-DNSName -Force
Set-Alias okpr CompletePRRequest
Set-Alias PRStat GetPRStatus
Set-Alias rdp StartRDP -Force
Set-Alias rdpb StartRDBuild -Force
Set-Alias rdt StartRDBuild2 -Force
Set-Alias rebootit RebootInstance -Force
Set-Alias removemepr removeMeasReviewer -Force
Set-Alias vmlan ChangeVMToLan -Force
Set-Alias vmwifi ChangeVMToWifi -Force