function venv {
    param (
        [string]$VENV_PATH = ".venv"  # Default to .venv if no argument is given
    )

    if (-not (Test-Path -Path $VENV_PATH)) {
        Write-Host "Creating virtual environment at $VENV_PATH..."
        python -m venv $VENV_PATH
    }

    Write-Host "Activating virtual environment at $VENV_PATH..."
    # For Windows
    if ($IsWindows) {
        & "$VENV_PATH\Scripts\Activate.ps1"
    }
    # For macOS/Linux
    else {
        & "$VENV_PATH/bin/activate"
    }
}

# Alias to call the function easily
Set-Alias vv venv

# Alias to deactivate virtual environment (on Windows)
Set-Alias dd "deactivate"
