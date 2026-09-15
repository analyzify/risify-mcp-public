<#
.SYNOPSIS
    Install Risify MCP server on Windows
.DESCRIPTION
    Downloads and installs the risify-mcp binary for Windows, verifying it
    against the checksums.txt published with the release before installing.

    Overrides, all optional:
      RISIFY_MCP_VERSION       install this tag instead of the latest release
      RISIFY_MCP_INSTALL_DIR   install somewhere other than %LOCALAPPDATA%
      RISIFY_MCP_BASE_URL      release download base, for testing
      RISIFY_MCP_API_URL       latest-release API endpoint, for testing
.EXAMPLE
    irm https://raw.githubusercontent.com/analyzify/risify-mcp-public/main/install.ps1 | iex
#>

$ErrorActionPreference = "Stop"

$REPO = "analyzify/risify-mcp-public"
$BINARY = "risify-mcp"

$INSTALL_DIR = if ($env:RISIFY_MCP_INSTALL_DIR) {
    $env:RISIFY_MCP_INSTALL_DIR
} else {
    Join-Path $env:LOCALAPPDATA "risify-mcp"
}

$BASE_URL = if ($env:RISIFY_MCP_BASE_URL) {
    $env:RISIFY_MCP_BASE_URL
} else {
    "https://github.com/$REPO/releases/download"
}

$API_URL = if ($env:RISIFY_MCP_API_URL) {
    $env:RISIFY_MCP_API_URL
} else {
    "https://api.github.com/repos/$REPO/releases/latest"
}

$TempDir = $null

function Fail($message) {
    Write-Host "Error: $message" -ForegroundColor Red
    exit 1
}

try {
    # Detect architecture (with fallback for 32-bit PowerShell on 64-bit Windows)
    $ProcessorArch = $env:PROCESSOR_ARCHITECTURE
    if ($ProcessorArch -eq "x86" -and $env:PROCESSOR_ARCHITEW6432) {
        $ProcessorArch = $env:PROCESSOR_ARCHITEW6432
    }

    $ARCH = switch ($ProcessorArch) {
        "AMD64" { "amd64" }
        "ARM64" { "arm64" }
        "x86" { Fail "32-bit x86 is not supported. Please use a 64-bit Windows version." }
        default {
            Write-Host "Warning: Unknown architecture '$ProcessorArch', assuming amd64..." -ForegroundColor Yellow
            "amd64"
        }
    }

    Write-Host "Detected architecture: $ARCH"

    $TAG = $env:RISIFY_MCP_VERSION
    if (-not $TAG) {
        Write-Host "Fetching latest release from GitHub..."
        try {
            $TAG = (Invoke-RestMethod -Uri $API_URL -TimeoutSec 30).tag_name
        } catch {
            Fail "failed to fetch the latest release: $($_.Exception.Message)"
        }
        if (-not $TAG) { Fail "no release found at $API_URL" }
    }

    Write-Host "Version: $TAG"

    $ASSET = "${BINARY}_windows_${ARCH}.zip"
    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    $ZipFile = Join-Path $TempDir $ASSET
    $ChecksumFile = Join-Path $TempDir "checksums.txt"

    Write-Host "Downloading $ASSET..."
    try {
        Invoke-WebRequest -Uri "$BASE_URL/$TAG/$ASSET" -OutFile $ZipFile -TimeoutSec 120 -UseBasicParsing
        Invoke-WebRequest -Uri "$BASE_URL/$TAG/checksums.txt" -OutFile $ChecksumFile -TimeoutSec 30 -UseBasicParsing
    } catch {
        Fail "download failed: $($_.Exception.Message)"
    }

    # Whole field, not a substring: a "<asset>.sig" line contains the asset name
    # and would supply the wrong hash. Leading "*" is sha256sum's binary marker.
    $Expected = $null
    foreach ($line in Get-Content $ChecksumFile) {
        $parts = $line -split '\s+', 2
        if ($parts.Count -lt 2) { continue }
        if ($parts[1].Trim().TrimStart('*') -eq $ASSET) {
            $Expected = $parts[0].Trim()
            break
        }
    }
    if (-not $Expected) { Fail "$ASSET is not listed in checksums.txt for $TAG" }

    # Get-FileHash returns uppercase, checksums.txt is lowercase; compared in
    # one case rather than relying on -ne being case-insensitive.
    $Actual = (Get-FileHash -Path $ZipFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $Expected = $Expected.ToLowerInvariant()
    if ($Expected -ne $Actual) {
        Fail "checksum mismatch for $ASSET`n  expected $Expected`n  actual   $Actual`nThe download was corrupted or tampered with; nothing has been installed."
    }

    Write-Host "Checksum verified."

    # Inspected before extraction: an absolute or traversing path would be
    # written wherever it points.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipFile)
    try {
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName
            if ([System.IO.Path]::IsPathRooted($name) -or $name -match '^[A-Za-z]:' -or $name -match '(^|[\\/])\.\.([\\/]|$)') {
                Fail "archive contains an unsafe path: $name"
            }
        }
        $hasBinary = $zip.Entries | Where-Object { $_.FullName -eq "$BINARY.exe" }
        if (-not $hasBinary) { Fail "archive does not contain the expected $BINARY.exe" }
    } finally {
        $zip.Dispose()
    }

    $Extract = Join-Path $TempDir "extract"
    New-Item -ItemType Directory -Path $Extract -Force | Out-Null
    try {
        Expand-Archive -Path $ZipFile -DestinationPath $Extract -Force
    } catch {
        Fail "failed to extract $ASSET"
    }

    $Staged = Join-Path $Extract "$BINARY.exe"
    if (-not (Test-Path $Staged)) { Fail "$BINARY.exe is missing after extraction" }

    # A reparse point would make the install copy whatever it points at.
    if ((Get-Item $Staged).Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        Fail "$BINARY.exe in the archive is a link rather than a file"
    }

    if (-not (Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    }

    # Staged beside the target so the last step replaces it in one move: either
    # the new binary is in place or the previous one still is, never neither.
    $Target = Join-Path $INSTALL_DIR "$BINARY.exe"
    $Pending = Join-Path $INSTALL_DIR "$BINARY.exe.new"

    Write-Host "Installing to $INSTALL_DIR..."
    try {
        Copy-Item $Staged -Destination $Pending -Force
        Move-Item $Pending -Destination $Target -Force
    } catch {
        Remove-Item $Pending -Force -ErrorAction SilentlyContinue
        Fail "cannot install to ${Target}: $($_.Exception.Message)"
    }

    # Windows-only; skipped elsewhere so the script stays testable.
    if ($env:OS -eq "Windows_NT") {
        $UserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        $NormalizedInstallDir = $INSTALL_DIR.TrimEnd('\').ToLowerInvariant()

        if (-not ($UserPath -split ';' | Where-Object { $_.TrimEnd('\').ToLowerInvariant() -eq $NormalizedInstallDir })) {
            Write-Host "Adding $INSTALL_DIR to your PATH..."
            [Environment]::SetEnvironmentVariable("PATH", "$UserPath;$INSTALL_DIR", "User")
            $env:PATH = "$env:PATH;$INSTALL_DIR"
            Write-Host "PATH updated. You may need to restart your terminal." -ForegroundColor Yellow
        } else {
            Write-Host "$INSTALL_DIR is already in your PATH."
        }
    }

    Write-Host ""
    Write-Host "Risify MCP server $TAG installed successfully!" -ForegroundColor Green
    Write-Host "Installed to: $Target"
    Write-Host ""
    Write-Host "Verify installation by running:"
    Write-Host "  risify-mcp.exe version" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Configure your MCP client (Claude Code, Cursor, VS Code, or Windsurf)"
    Write-Host "2. Set up your RISIFY_USER_ID and RISIFY_API_KEY environment variables"
    Write-Host ""
    Write-Host "For detailed setup instructions, visit:"
    Write-Host "https://github.com/$REPO" -ForegroundColor Cyan
} finally {
    if ($TempDir -and (Test-Path $TempDir)) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
