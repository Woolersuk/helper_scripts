venv() {
    local VENV_PATH="${1:-.venv}"  # Default to .venv if no argument is given

    if [ ! -d "${VENV_PATH}" ]; then
        echo "Creating virtual environment at ${VENV_PATH}..."
        uv venv "${VENV_PATH}"
    fi

    echo "Activating virtual environment at ${VENV_PATH}..."
    source "${VENV_PATH}/bin/activate"
}

# Alias to call the function easily
alias vv="venv"
alias dd="deactivate"