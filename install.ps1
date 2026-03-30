<#
.SYNOPSIS
    Install Risify MCP server on Windows
.DESCRIPTION
    Downloads and installs the latest risify-mcp binary for Windows.
    Installs to $env:LOCALAPPDATA\risify-mcp and adds it to PATH.
.EXAMPLE
    irm https://raw.githubusercontent.com/analyzify/risify-mcp-public/main/install.ps1 | iex
#>

$ErrorActionPreference = "Stop"

$REPO = "analyzify/risify-mcp-public"
$BINARY = "risify-mcp"
$INSTALL_DIR = Join-Path $env:LOCALAPPDATA "risify-mcp"

# Detect architecture (with fallback for 32-bit PowerShell on 64-bit Windows)
$ProcessorArch = $env:PROCESSOR_ARCHITECTURE
if ($ProcessorArch -eq "x86" -and $env:PROCESSOR_ARCHITEW6432) {
    $ProcessorArch = $env:PROCESSOR_ARCHITEW6432
}

$ARCH = switch ($ProcessorArch) {
    "AMD64" { "amd64" }
    "ARM64" { "arm64" }
    "x86" { 
        Write-Host "Error: 32-bit x86 is not supported. Please use a 64-bit Windows version." -ForegroundColor Red
        exit 1
    }
    default {
        Write-Host "Warning: Unknown architecture '$ProcessorArch', assuming amd64..." -ForegroundColor Yellow
        "amd64"
    }
}

Write-Host "Detected architecture: $ARCH"

# Fetch latest release
Write-Host "Fetching latest release from GitHub..."
try {
    $RELEASE = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases/latest" -TimeoutSec 30
    $TAG = $RELEASE.tag_name
} catch {
    Write-Host "Error: Failed to fetch latest release from GitHub." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

if (-not $TAG) {
    Write-Host "Error: No release found." -ForegroundColor Red
    exit 1
}

Write-Host "Latest version: $TAG"

# Download asset
$ASSET = "${BINARY}_windows_${ARCH}.zip"
$URL = "https://github.com/$REPO/releases/download/$TAG/$ASSET"

Write-Host "Downloading $ASSET..."
$TempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

$ZipFile = Join-Path $TempDir $ASSET

try {
    Invoke-WebRequest -Uri $URL -OutFile $ZipFile -TimeoutSec 60 -UseBasicParsing
} catch {
    Write-Host "Error: Failed to download $ASSET" -ForegroundColor Red
    Write-Host "URL: $URL" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Extract
try {
    Write-Host "Extracting archive..."
    Expand-Archive -Path $ZipFile -DestinationPath $TempDir -Force

    # Check if binary exists in extracted contents
    $BinaryFile = Get-ChildItem -Path $TempDir -Filter "$BINARY.exe" -Recurse | Select-Object -First 1
    if (-not $BinaryFile) {
        Write-Host "Error: Binary '$BINARY.exe' not found in downloaded archive." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Error: Failed to extract archive or find binary." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Install to target directory
Write-Host "Installing to $INSTALL_DIR..."
if (Test-Path $INSTALL_DIR) {
    # Remove old version
    Remove-Item $INSTALL_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null

# Move binary to install directory
Move-Item $BinaryFile.FullName -Destination $INSTALL_DIR

# Cleanup
Remove-Item $TempDir -Recurse -Force

# Add to PATH if not already present (normalize trailing slashes for comparison)
$UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$NormalizedInstallDir = $INSTALL_DIR.TrimEnd('\').ToLowerInvariant()
$NormalizedPath = $UserPath.TrimEnd('\').ToLowerInvariant()

if (-not ($NormalizedPath -split ';' | Where-Object { $_.TrimEnd('\') -eq $NormalizedInstallDir })) {
    Write-Host "Adding $INSTALL_DIR to your PATH..."
    $NewPath = $UserPath + ";$INSTALL_DIR"
    [Environment]::SetEnvironmentVariable("PATH", $NewPath, "User")
    
    # Also update current session
    $env:PATH = $env:PATH + ";$INSTALL_DIR"
    Write-Host "PATH updated. You may need to restart your terminal for changes to take full effect." -ForegroundColor Yellow
} else {
    Write-Host "$INSTALL_DIR is already in your PATH."
}

Write-Host ""
Write-Host "Risify MCP server installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Installed to: $INSTALL_DIR\$BINARY.exe"
Write-Host ""
Write-Host "Verify installation by running:"
Write-Host "  risify-mcp.exe version" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Configure your MCP client (Claude Code, Cursor, VS Code, or Windsurf)"
Write-Host "2. Set up your RISIFY_USER_ID and RISIFY_API_KEY environment variables"
Write-Host ""
Write-Host "For detailed setup instructions, visit the documentation at:"
Write-Host "https://github.com/$REPO" -ForegroundColor Cyan
