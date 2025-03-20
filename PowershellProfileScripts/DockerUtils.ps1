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
          $newEntry = "$ipAddress $hostname"
          Add-Content -Path $hostsFilePath -Value $newEntry
          Write-Host "Entry for $hostname added to the hosts file."
      }
  }
  else {
      Write-Host "Hosts file not found."
  }
}

# Function to stop all running containers and save their IDs
function Stop-RunningContainers {
  $global:RunningContainers = docker ps -q
  if ($RunningContainers) {
      Write-Host "Stopping running containers..."
      docker stop $RunningContainers
      Write-Host "Containers stopped."
  } else {
      Write-Host "No running containers found."
  }
}

# Function to restart only the previously running containers
function Start-PreviouslyRunningContainers {
  if ($global:RunningContainers) {
      Write-Host "Restarting previously running containers..."
      docker start $RunningContainers
      Write-Host "Containers restarted."
  } else {
      Write-Host "No previously running containers to start."
  }
}

# Function to start all stopped containers
function Start-AllContainers {
  Write-Host "Starting all stopped containers..."
  docker start $(docker ps -aq)
  Write-Host "All containers started."
}

Set-Alias AHE Add-HostsEntry
Set-Alias DStopAll Stop-RunningContainers
Set-Alias DStartAll Start-AllContainers
Set-Alias DStartStopped Start-PreviouslyRunningContainers