function venv {
    param (
        [string]$VENV_PATH = ".venv"  # Default to .venv if no argument is given
    )

    if (-not (Test-Path -Path $VENV_PATH)) {
        Write-Host "Creating virtual environment at $VENV_PATH..."
        python3 -m venv $VENV_PATH
    }

    Write-Host "Activating virtual environment at $VENV_PATH..."
    # For Windows
    if ($IsWindows) {
        & "$VENV_PATH\Scripts\Activate.ps1"
						if (Test-Path requirements.txt -PathType Leaf) {
							uv pip install -r requirements.txt
						}
    }
    # For macOS/Linux
    else {
        & "$VENV_PATH/bin/activate"
    }
}

$env:Path = "C:\Users\AlexWoolsey\.local\bin;$env:Path"

# Alias to call the function easily
Set-Alias vv venv

# Alias to deactivate virtual environment (on Windows)
Set-Alias dd "deactivate"
Set-Alias python3 py