function Get-DockerPorts { docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}" }

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

Set-Alias DPorts Get-DockerPorts
Set-Alias DStopAll Stop-RunningContainers
Set-Alias DStartAll Start-AllContainers
Set-Alias DStartStopped Start-PreviouslyRunningContainers