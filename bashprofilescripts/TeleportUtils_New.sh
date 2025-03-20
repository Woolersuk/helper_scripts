#!/bin/bash
# Teleport CLI shortcuts for Bash

# Define role map with app names and other metadata
declare -A role_map
role_map[admin, RO]="admin"
role_map[admin, RW]="sudo_admin"
role_map[admin, APP]="yl-admin"

role_map[dev, RO]="development"
role_map[dev, RW]="sudo_dev"
role_map[dev, APP]="yl-development"

role_map[staging, RO]="staging"
role_map[staging, RW]="sudo_staging"
role_map[staging, APP]="yl-staging"

role_map[sandbox, RO]="sandbox"
role_map[sandbox, RW]="sudo_sandbox"
role_map[sandbox, APP]="yl-sandbox"

role_map[prod, RO]="prod"
role_map[prod, RW]="sudo_prod"
role_map[prod, APP]="yl-production"

role_map[usprod, RO]="usprod"
role_map[usprod, RW]="sudo_usprod"
role_map[usprod, APP]="yl-usproduction"

# Configuration variables with defaults
TP_PROXY="${TP_PROXY:-youlend.teleport.sh:443}"
TP_AUTH="${TP_AUTH:-ad}"

# Unified function to switch AWS roles through Teleport
tp_switch_role() {
  local account="$1"
  local access_level="$2"
  local app_name="${role_map[$account, APP]}"
  local role="${role_map[$account, $access_level]}"

  # Validate inputs
  if [[ -z "$app_name" || -z "$role" ]]; then
    echo -e "\e[31mError: Invalid account '$account' or access level '$access_level'.\e[0m"
    return 1
  fi

  # Get current app to handle logout if needed
  local current_app=$(tsh apps ls -f text | grep "^>" | awk '{print $2}')
  if [[ -n "$current_app" && "$current_app" != "$app_name" ]]; then
    echo -e "\e[33mLogging out of current app: $current_app...\e[0m"
    tsh apps logout "$current_app" >/dev/null 2>&1
  fi

  # Login to the app with the specified role
  echo -e "\e[36mLogging into Teleport App: $app_name with role: $role...\e[0m"
  tsh apps login "$app_name" --aws-role "$role" >/dev/null 2>&1

  echo -e "\e[32mAWS credentials set for $account ($access_level).\e[0m"
}

# Generate tp* functions for all environments
for account in admin dev staging sandbox prod usprod; do
  # Create RW function (tpadminRW, tpdevRW, etc.)
  eval "tp${account}RW() { tp_switch_role \"$account\" \"RW\"; }"

  # Create RO function (tpadminRO, tpdevRO, etc.)
  eval "tp${account}RO() { tp_switch_role \"$account\" \"RO\"; }"

  # Create default function (tpadmin, tpdev, etc.) - points to RW
  eval "tp$account() { tp_switch_role \"$account\" \"RW\"; }"
done

# Basic Teleport commands
alias tl="tsh login --auth=${TP_AUTH} --proxy=${TP_PROXY}"
alias tla='tsh logout apps'
alias tlo='tsh logout'
alias tstat='tsh status'
alias taws='tsh aws'

# Kubernetes cluster login shortcuts
alias tkadmin="tsh kube login headquarter-admin-eks-green --proxy=${TP_PROXY} --auth=${TP_AUTH}"
alias tkdev="tsh kube login aslive-dev-eks-green --proxy=${TP_PROXY} --auth=${TP_AUTH}"
alias tkprod="tsh kube login live-prod-eks-green --proxy=${TP_PROXY} --auth=${TP_AUTH}"
alias tksandbox="tsh kube login aslive-sandbox-eks-green --proxy=${TP_PROXY} --auth=${TP_AUTH}"
alias tkstaging="tsh kube login aslive-staging-eks-green --proxy=${TP_PROXY} --auth=${TP_AUTH}"
alias tkusprod="tsh kube login live-usprod-eks-green --proxy=${TP_PROXY} --auth=${TP_AUTH}"

# Helper function for interactive app login with AWS role selection
tawsp_interactive_login() {
  local output header apps

  # Get the list of apps.
  output=$(tsh apps ls -f text)
  header=$(echo "$output" | head -n 2)
  apps=$(echo "$output" | tail -n +3)

  if [ -z "$apps" ]; then
    echo "No apps available."
    return 1
  fi

  # Display header and numbered list of apps.
  echo "$header"
  echo "$apps" | nl -w2 -s'. '

  # Prompt for app selection.
  read -p "Choose app to login (number): " app_choice
  if [ -z "$app_choice" ]; then
    echo "No selection made. Exiting."
    return 1
  fi

  local chosen_line app
  chosen_line=$(echo "$apps" | sed -n "${app_choice}p")
  if [ -z "$chosen_line" ]; then
    echo "Invalid selection."
    return 1
  fi

  # If the first column is ">", use the second column; otherwise, use the first.
  app=$(echo "$chosen_line" | awk '{if ($1==">") print $2; else print $1;}')
  if [ -z "$app" ]; then
    echo "Invalid selection."
    return 1
  fi

  echo "Selected app: $app"

  # Log out of the selected app to force fresh AWS role output.
  echo "Logging out of app: $app..."
  tsh apps logout "$app" >/dev/null 2>&1

  # Run tsh apps login to capture the AWS roles listing.
  # (This command will error out because --aws-role is required, but it prints the available AWS roles.)
  local login_output
  login_output=$(tsh apps login "$app" 2>&1)

  # Extract the AWS roles section.
  # The section is expected to start after "Available AWS roles:" and end before the error message.
  local role_section
  role_section=$(echo "$login_output" | awk '/Available AWS roles:/{flag=1; next} /ERROR: --aws-role flag is required/{flag=0} flag')

  # Remove lines that contain "ERROR:" or that are empty.
  role_section=$(echo "$role_section" | grep -v "ERROR:" | sed '/^\s*$/d')

  if [ -z "$role_section" ]; then
    echo "No AWS roles info found. Attempting direct login..."
    tsh apps login "$app"
    return
  fi

  # Assume the first 2 lines of role_section are headers.
  local role_header roles_list
  role_header=$(echo "$role_section" | head -n 2)
  roles_list=$(echo "$role_section" | tail -n +3 | sed '/^\s*$/d')

  if [ -z "$roles_list" ]; then
    echo "No roles found in the AWS roles listing."
    echo "Logging you into app \"$app\" without specifying an AWS role."
    tsh apps login "$app"
    return
  fi

  echo "Available AWS roles:"
  echo "$role_header"
  echo "$roles_list" | nl -w2 -s'. '

  # Prompt for role selection.
  read -p "Choose AWS role (number): " role_choice
  if [ -z "$role_choice" ]; then
    echo "No selection made. Exiting."
    return 1
  fi

  local chosen_role_line role_name
  chosen_role_line=$(echo "$roles_list" | sed -n "${role_choice}p")
  if [ -z "$chosen_role_line" ]; then
    echo "Invalid selection."
    return 1
  fi

  role_name=$(echo "$chosen_role_line" | awk '{print $1}')
  if [ -z "$role_name" ]; then
    echo "Invalid selection."
    return 1
  fi

  echo "Logging you into app: $app with AWS role: $role_name"
  tsh apps login "$app" --aws-role "$role_name"
}

# Helper function for interactive login (choose)
tkube_interactive_login() {
  local output header clusters
  output=$(tsh kube ls -f text)
  header=$(echo "$output" | head -n 2)
  clusters=$(echo "$output" | tail -n +3)

  if [ -z "$clusters" ]; then
    echo "No Kubernetes clusters available."
    return 1
  fi

  # Show header and numbered list of clusters
  echo "$header"
  echo "$clusters" | nl -w2 -s'. '

  # Prompt for selection
  read -p "Choose cluster to login (number): " choice

  if [ -z "$choice" ]; then
    echo "No selection made. Exiting."
    return 1
  fi

  local chosen_line cluster
  chosen_line=$(echo "$clusters" | sed -n "${choice}p")
  if [ -z "$chosen_line" ]; then
    echo "Invalid selection."
    return 1
  fi

  cluster=$(echo "$chosen_line" | awk '{print $1}')
  if [ -z "$cluster" ]; then
    echo "Invalid selection."
    return 1
  fi

  echo "Logging you into cluster: $cluster"
  tsh kube login "$cluster"
}

# Main tkube function
tkube() {
  # Check for top-level flags:
  # -c for choose (interactive login)
  # -l for list clusters
  if [ "$1" = "-c" ]; then
    tkube_interactive_login
    return
  elif [ "$1" = "-l" ]; then
    tsh kube ls -f text
    return
  fi

  local subcmd="$1"
  shift
  case "$subcmd" in
  ls)
    tsh kube ls -f text
    ;;
  login)
    if [ "$1" = "-c" ]; then
      tkube_interactive_login
    else
      tsh kube login "$@"
    fi
    ;;
  sessions)
    tsh kube sessions "$@"
    ;;
  exec)
    tsh kube exec "$@"
    ;;
  join)
    tsh kube join "$@"
    ;;
  logout)
    tsh kube logout "$@"
    ;;
  status)
    kubectl config current-context
    ;;
  *)
    echo "Usage: tkube {[-c | -l] | ls | login [cluster_name | -c] | sessions | exec | join | logout | status}"
    ;;
  esac
}

# Main function for Teleport apps
tawsp() {
  # Top-level flags:
  # -c: interactive login (choose app and then role)
  # -l: list available apps
  if [ "$1" = "-c" ]; then
    tawsp_interactive_login
    return
  elif [ "$1" = "-l" ]; then
    tsh apps ls -f text
    return
  elif [ "$1" = "login" ]; then
    shift
    if [ "$1" = "-c" ]; then
      tawsp_interactive_login
    else
      tsh apps login "$@"
    fi
    return
  elif [ "$1" = "logout" ]; then
    shift
    if [ -z "$1" ]; then
      tsh logout apps
    else
      tsh apps logout "$@"
    fi
    return
  elif [ "$1" = "status" ]; then
    echo "Current Teleport applications:"
    tsh apps ls -f text | grep "^>"
    return
  fi

  echo "Usage: tawsp { -c | -l | login [app_name | -c] | logout [app_name] | status }"
}

# Create shorthand alias for staging
alias tpstage='tpstaging'

# Helper function to show available commands and shortcuts
tp_help() {
  echo -e "\e[1mTeleport CLI Shortcuts Help\e[0m"
  echo -e "\e[36m=========================\e[0m"
  echo -e "\e[33mGeneral Teleport Commands:\e[0m"
  echo "  tl          - Login to Teleport"
  echo "  tla         - Logout from all apps"
  echo "  tlo         - Logout from Teleport"
  echo "  tstat       - Show Teleport status"

  echo -e "\n\e[33mAWS Role Commands:\e[0m"
  echo "  tpENVIRONMENT       - Login to environment with RW access (e.g., tpdev, tpprod)"
  echo "  tpENVIRONMENTRO     - Login to environment with RO access (e.g., tpdevRO, tpprodRO)"
  echo "  tpENVIRONMENTRW     - Login to environment with RW access (e.g., tpdevRW, tpprodRW)"
  echo "  Available environments: admin, dev, staging, sandbox, prod, usprod"

  echo -e "\n\e[33mKubernetes Commands:\e[0m"
  echo "  tkube -c             - Interactive Kubernetes cluster selection"
  echo "  tkube -l             - List available Kubernetes clusters"
  echo "  tkube login CLUSTER  - Login to specific Kubernetes cluster"
  echo "  tkube status         - Show current Kubernetes context"
  echo "  tkENVIRONMENT        - Login to specific environment cluster (e.g., tkdev, tkprod)"

  echo -e "\n\e[33mApp Commands:\e[0m"
  echo "  tawsp -c             - Interactive app selection"
  echo "  tawsp -l             - List available apps"
  echo "  tawsp login APP      - Login to specific app"
  echo "  tawsp status         - Show current app status"
  echo "  tawsp logout [APP]   - Logout from specific app or all apps"
}

# Auto-completion setup for teleport commands
_tp_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local cmd="${COMP_WORDS[0]}"

  if [[ "$cmd" == "tkube" ]]; then
    COMPREPLY=($(compgen -W "-c -l ls login sessions exec join logout status" -- "$cur"))
  elif [[ "$cmd" == "tawsp" ]]; then
    COMPREPLY=($(compgen -W "-c -l login logout status" -- "$cur"))
  fi
  return 0
}

# Register completion for our custom commands
complete -F _tp_complete tkube
complete -F _tp_complete tawsp

# Function to check Teleport status and warn if session is expiring soon
check_teleport_status() {
  local status_output expiry_time current_time time_left warning_threshold
  warning_threshold=3600 # Warning threshold in seconds (1 hour)

  # Get status output
  status_output=$(tsh status 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo -e "\e[31mWarning: Not logged into Teleport!\e[0m"
    return 1
  fi

  # Extract expiry time
  expiry_time=$(echo "$status_output" | grep "Valid until" | awk -F': ' '{print $2}')
  if [ -z "$expiry_time" ]; then
    return 0 # Can't determine expiry time
  fi

  # Convert times to seconds since epoch
  current_time=$(date +%s)
  expiry_seconds=$(date -d "$expiry_time" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$expiry_time" +%s 2>/dev/null)

  if [ -z "$expiry_seconds" ]; then
    return 0 # Can't parse expiry time
  fi

  # Calculate time left
  time_left=$((expiry_seconds - current_time))

  # Show warning if session is expiring soon
  if [ $time_left -le $warning_threshold ]; then
    hours=$((time_left / 3600))
    minutes=$(((time_left % 3600) / 60))
    echo -e "\e[33mWarning: Teleport session expires in ${hours}h ${minutes}m. Consider renewing with 'tl'.\e[0m"
  fi

  return 0
}

# Function to add command history for teleport commands
tp_history() {
  local count=${1:-10}
  history | grep -E "^[0-9]+\s+(tp|tsh|tkube|tawsp)" | tail -n "$count"
}

# Function to run a command across multiple clusters
tkube_exec_all() {
  local command="$1"
  local clusters output

  if [ -z "$command" ]; then
    echo "Usage: tkube_exec_all 'kubectl command'"
    return 1
  fi

  # Get list of available clusters
  output=$(tsh kube ls -f text)
  clusters=$(echo "$output" | tail -n +3 | awk '{print $1}')

  if [ -z "$clusters" ]; then
    echo "No Kubernetes clusters available."
    return 1
  fi

  # Execute command on each cluster
  for cluster in $clusters; do
    echo -e "\e[36mExecuting on cluster: $cluster\e[0m"
    echo "$ $command"
    tsh kube exec "$cluster" -- bash -c "$command"
    echo ""
  done
}

# Function to save/restore AWS profiles
tp_save_profile() {
  local profile_name="$1"
  local current_app current_role

  if [ -z "$profile_name" ]; then
    echo "Usage: tp_save_profile <profile_name>"
    return 1
  fi

  # Get current app and role
  current_app=$(tsh apps ls -f text | grep "^>" | awk '{print $2}')
  if [ -z "$current_app" ]; then
    echo "No active Teleport app found."
    return 1
  fi

  # Get current role from AWS credentials
  current_role=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null | grep -o 'assumed-role/[^/]*' | cut -d'/' -f2)
  if [ -z "$current_role" ]; then
    echo "Could not determine current AWS role."
    return 1
  fi

  # Save profile
  mkdir -p "$HOME/.teleport/profiles"
  echo "{\"app\":\"$current_app\",\"role\":\"$current_role\"}" >"$HOME/.teleport/profiles/$profile_name.json"
  echo "Saved profile '$profile_name' with app '$current_app' and role '$current_role'"
}

tp_load_profile() {
  local profile_name="$1"
  local profile_file="$HOME/.teleport/profiles/$profile_name.json"

  if [ -z "$profile_name" ]; then
    echo "Usage: tp_load_profile <profile_name>"
    return 1
  fi

  if [ ! -f "$profile_file" ]; then
    echo "Profile '$profile_name' not found."
    return 1
  fi

  # Load profile
  local app role
  app=$(jq -r '.app' "$profile_file")
  role=$(jq -r '.role' "$profile_file")

  if [ -z "$app" ] || [ -z "$role" ]; then
    echo "Invalid profile format."
    return 1
  fi

  # Switch to the profile
  echo "Loading profile '$profile_name' with app '$app' and role '$role'"
  tsh apps login "$app" --aws-role "$role"
}

tp_list_profiles() {
  local profiles_dir="$HOME/.teleport/profiles"

  if [ ! -d "$profiles_dir" ]; then
    echo "No saved profiles found."
    return 0
  fi

  echo "Available profiles:"
  for profile in "$profiles_dir"/*.json; do
    if [ -f "$profile" ]; then
      local name app role
      name=$(basename "$profile" .json)
      app=$(jq -r '.app' "$profile")
      role=$(jq -r '.role' "$profile")
      echo "  $name: $app ($role)"
    fi
  done
}

# Auto-completion for profiles
_tp_profile_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local cmd="${COMP_WORDS[0]}"
  local profiles_dir="$HOME/.teleport/profiles"

  if [[ "$cmd" == "tp_load_profile" ]]; then
    if [ -d "$profiles_dir" ]; then
      local profiles=$(ls "$profiles_dir" | grep '.json$' | sed 's/\.json$//')
      COMPREPLY=($(compgen -W "$profiles" -- "$cur"))
    fi
  fi
  return 0
}

# Register completion for profile commands
complete -F _tp_profile_complete tp_load_profile

# Function to add this script to bashrc/zshrc
tp_install() {
  local script_path="$1"
  local shell_type="$2"

  if [ -z "$script_path" ]; then
    script_path="$HOME/.teleport/teleport_shortcuts.sh"
    # Save current script to the location
    mkdir -p "$HOME/.teleport"
    cat "$0" >"$script_path"
    chmod +x "$script_path"
  fi

  if [ -z "$shell_type" ]; then
    if [ -n "$ZSH_VERSION" ]; then
      shell_type="zsh"
    else
      shell_type="bash"
    fi
  fi

  if [ "$shell_type" = "zsh" ]; then
    rc_file="$HOME/.zshrc"
  else
    rc_file="$HOME/.bashrc"
  fi

  if ! grep -q "source $script_path" "$rc_file"; then
    echo "" >>"$rc_file"
    echo "# Teleport CLI shortcuts" >>"$rc_file"
    echo "source $script_path" >>"$rc_file"
    echo "Added Teleport shortcuts to $rc_file"
  else
    echo "Teleport shortcuts already installed in $rc_file"
  fi
}

# Optional: Function to run after each command to check teleport status
# Add this to your PROMPT_COMMAND (bash) or precmd (zsh) if desired
# check_teleport_status

# Optional: Add a smart prompt that shows current teleport status
tp_prompt() {
  local app cluster role

  # Get current app
  app=$(tsh apps ls -f text 2>/dev/null | grep "^>" | awk '{print $2}')

  # Get current cluster
  cluster=$(kubectl config current-context 2>/dev/null | grep -o '[^@]*$')

  # Get current role
  role=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null | grep -o 'assumed-role/[^/]*' | cut -d'/' -f2)

  local prompt=""
  if [ -n "$app" ] || [ -n "$cluster" ] || [ -n "$role" ]; then
    prompt="("
    if [ -n "$app" ]; then prompt+="app:$app "; fi
    if [ -n "$role" ]; then prompt+="role:$role "; fi
    if [ -n "$cluster" ]; then prompt+="k8s:$cluster"; fi
    prompt+=")"
  fi

  echo "$prompt"
}

# Example PS1 integration (uncomment to use)
# PS1='$(tp_prompt)'"$PS1"
