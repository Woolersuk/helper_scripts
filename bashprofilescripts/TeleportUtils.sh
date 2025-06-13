#!/bin/bash

# ======== CONFIGURATION ========
declare -A ROLE_MAP_RO=(
  [admin]="headquarter-admin-eks-blue"
  [dev]="aslive-dev-eks-blue"
  [prod]="live-prod-eks-blue"
  [sandbox]="aslive-sandbox-eks-blue"
  [staging]="aslive-staging-eks-blue"
  [usprod]="live-usprod-eks-blue"
)

declare -A ENV_CONFIG=(
  [admin]="sudo_admin yl-admin 937787910409"
  [dev]="sudo_dev yl-development 777909771556"
  [prod]="sudo_prod yl-prod 902371465413"
  [sandbox]="sudo_sandbox yl-sandbox 517395983949"
  [staging]="sudo_staging yl-staging 871980946913"
  [usprod]="sudo_usprod yl-usprod 359939295825"
  [usstaging]="sudo_usstaging yl-usstaging 973302516471"
)

PROXY="youlend.teleport.sh:443"

# ======== FUNCTIONS ========

tsh_status() {
  tsh status
}

teleport_login() {
  tsh login --auth=ad --proxy=$PROXY
}

teleport_logout() {
  tsh logout
}

teleport_apps_logout() {
  tsh apps logout
}

login_kube_env() {
  local env="$1"
  cluster="${ROLE_MAP_RO[$env]}"
  tsh kube login "$cluster" --proxy=$PROXY --auth=ad
}

aws_role_login() {
  local account="$1"
  local level="$2"

  read -r ROLE APP ACCOUNT_ID <<< "${ENV_CONFIG[$account]}"

  if [[ "$level" == "RO" ]]; then
		tsh apps logout >/dev/null 2>&1
    echo "[INFO] Logging in (RO) to $APP with role $ROLE"
    tsh apps login "$APP" --aws-role "$ROLE"
    return
  fi

  echo "[INFO] Logging in (RW) to $APP with role $ROLE"
  tsh apps login "$APP" --aws-role "$ROLE"
  creds=$(tsh aws sts assume-role --role-arn "arn:aws:iam::$ACCOUNT_ID:role/$ROLE" --role-session-name "$ROLE")

  export AWS_ACCESS_KEY_ID=$(echo "$creds" | jq -r .Credentials.AccessKeyId)
  export AWS_SECRET_ACCESS_KEY=$(echo "$creds" | jq -r .Credentials.SecretAccessKey)
  export AWS_SESSION_TOKEN=$(echo "$creds" | jq -r .Credentials.SessionToken)
}

start_teleport_proxy() {
  local env="$1"
  read -r ROLE APP ACCOUNT_ID <<< "${ENV_CONFIG[$env]}"

  LOG_PATH="/tmp/tsh_proxy_$env.log"
  PID_FILE="/tmp/tsh_proxy_$env.pid"
  PORT=$((62000 + RANDOM % 1000))

  echo "[INFO] Logging into $APP with role $ROLE..."
  tsh apps logout >/dev/null 2>&1
  tsh apps login "$APP" --aws-role "$ROLE"

  nohup tsh proxy aws --app "$APP" --port "$PORT" > "$LOG_PATH" 2>&1 &
  echo $! > "$PID_FILE"

  echo "[INFO] Proxy started on port $PORT. Logs: $LOG_PATH"
}

stop_teleport_proxy() {
  local env="$1"
  PID_FILE="/tmp/tsh_proxy_$env.pid"

  if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    kill "$PID" && echo "[INFO] Proxy for $env stopped." || echo "[WARN] Failed to stop process."
    rm -f "$PID_FILE"
  else
    echo "[WARN] No proxy PID file for $env."
  fi
}

# ======== ALIASES ========
alias tl=teleport_login
alias tlo=teleport_logout
alias tla=teleport_apps_logout
alias tstat=tsh_status

alias tkadmin='login_kube_env admin'
alias tkdev='login_kube_env dev'
alias tkprod='login_kube_env prod'
alias tksandbox='login_kube_env sandbox'
alias tkstaging='login_kube_env staging'
alias tkusprod='login_kube_env usprod'

alias tppadmin='start_teleport_proxy admin'
alias tppdev='start_teleport_proxy dev'
alias tppprod='start_teleport_proxy prod'
alias tppusprod='start_teleport_proxy usprod'
alias tppsandbox='start_teleport_proxy sandbox'
alias tppstaging='start_teleport_proxy staging'
alias tppusstaging='start_teleport_proxy usstaging'

alias stopadmin='stop_teleport_proxy admin'
alias stopdev='stop_teleport_proxy dev'
alias stopprod='stop_teleport_proxy prod'
alias stopusprod='stop_teleport_proxy usprod'
alias stopsandbox='stop_teleport_proxy sandbox'
alias stopstaging='stop_teleport_proxy staging'
alias stopusstaging='stop_teleport_proxy usstaging'

# Quickly obtain AWS credentials via Teleport
alias taws='tsh aws'

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
    *)
      echo "Usage: tkube {[-c | -l] | ls | login [cluster_name | -c] | sessions | exec | join }"
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
  fi

  echo "Usage: tawsp { -c | -l | login [app_name | -c] }"
}


# /////////////////////////////////////////////
# /////////////// Helper functions ////////////
# /////////////////////////////////////////////

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
  tsh apps logout "$app" > /dev/null 2>&1

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

echo "[INFO] Teleport helper functions loaded. Use 'tl' to login, 'tpp[env]' to start proxies."