# Teleport CLI shortcuts
alias tpadmin='tsh proxy aws --app yl-admin'
alias tpdev='tsh proxy aws --app yl-development'
alias tpstage='tsh proxy aws --app yl-staging'
alias tpsandbox='tsh proxy aws --app yl-sandbox'
alias tpprod='tsh proxy aws --app yl-production'
alias tpusprod='tsh proxy aws --app yl-usproduction'


# Easily log in to your Teleport cluster
alias tl='tsh login --auth=ad --proxy=youlend.teleport.sh:443'
alias tla='tsh logout apps'
alias tlo='tsh logout'

alias tkadmin='tsh kube login headquarter-admin-eks-green --proxy=youlend.teleport.sh:443 --auth=ad'
alias tkdev='tsh kube login aslive-dev-eks-green --proxy=youlend.teleport.sh:443 --auth=ad'
alias tkprod='tsh kube login live-prod-eks-green --proxy=youlend.teleport.sh:443 --auth=ad'
alias tksandbox='tsh kube login aslive-sandbox-eks-green --proxy=youlend.teleport.sh:443 --auth=ad'
alias tkstaging='tsh kube login aslive-staging-eks-green --proxy=youlend.teleport.sh:443 --auth=ad'
alias tkusprod='tsh kube login live-usprod-eks-green --proxy=youlend.teleport.sh:443 --auth=ad'

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
