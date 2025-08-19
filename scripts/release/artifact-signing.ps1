# Artifact signing and verification system for Windows
# Provides cryptographic signing and verification of release artifacts

param(
    [Parameter(Position=0)]
    [ValidateSet("generate-keys", "sign", "verify", "sign-file", "verify-file", "help")]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [string]$Path
)

$ErrorActionPreference = "Stop"

# Get script and repository paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Configuration
$ArtifactsDir = Join-Path $RepoRoot "artifacts"
$SignaturesDir = Join-Path $RepoRoot "signatures"
$KeysDir = Join-Path $RepoRoot ".keys"
$GpgKeyId = $env:GPG_KEY_ID
$CosignKey = if ($env:COSIGN_KEY) { $env:COSIGN_KEY } else { Join-Path $KeysDir "cosign.key" }

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Ensure required directories exist
function Ensure-Directories {
    @($ArtifactsDir, $SignaturesDir, $KeysDir) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
}

# Check if required tools are installed
function Test-Dependencies {
    $missingTools = @()
    
    $tools = @("gpg", "cosign")
    foreach ($tool in $tools) {
        try {
            & $tool --version | Out-Null
        } catch {
            $missingTools += $tool
        }
    }
    
    # Check for Get-FileHash (built-in PowerShell cmdlet)
    if (-not (Get-Command Get-FileHash -ErrorAction SilentlyContinue)) {
        $missingTools += "Get-FileHash"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Error "Missing required tools: $($missingTools -join ', ')"
        Write-Info "Please install the missing tools and try again"
        exit 1
    }
}

# Generate GPG key for signing (if not exists)
function New-GpgKey {
    if ($GpgKeyId -and (gpg --list-secret-keys $GpgKeyId 2>$null)) {
        Write-Info "GPG key $GpgKeyId already exists"
        return
    }
    
    Write-Info "Generating new GPG key for artifact signing..."
    
    # Create GPG key generation config
    $gpgConfig = @"
%echo Generating GPG key for artifact signing
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Release Signing Key
Name-Email: release@example.com
Expire-Date: 2y
Passphrase: 
%commit
%echo GPG key generation complete
"@
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempFile -Value $gpgConfig
    
    try {
        gpg --batch --generate-key $tempFile
        
        # Get the generated key ID
        $keyOutput = gpg --list-secret-keys --keyid-format LONG
        $GpgKeyId = ($keyOutput | Select-String "sec.*\/([A-F0-9]+)" | ForEach-Object { $_.Matches[0].Groups[1].Value } | Select-Object -First 1)
        
        Write-Success "Generated GPG key: $GpgKeyId"
        Write-Info "Export GPG_KEY_ID=$GpgKeyId to your environment"
    } finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}

# Generate Cosign key pair (if not exists)
function New-CosignKey {
    if (Test-Path $CosignKey) {
        Write-Info "Cosign key already exists at $CosignKey"
        return
    }
    
    Write-Info "Generating Cosign key pair..."
    
    # Generate key pair without password for automation
    $env:COSIGN_PASSWORD = ""
    $keyPrefix = Join-Path $KeysDir "cosign"
    cosign generate-key-pair --output-key-prefix $keyPrefix
    
    Write-Success "Generated Cosign key pair at $KeysDir/"
    Write-Warning "Keep the private key secure and never commit it to version control"
}

# Create checksums for artifacts
function New-Checksum {
    param([string]$ArtifactPath)
    
    $checksumFile = "$ArtifactPath.sha256"
    
    Write-Info "Creating checksum for $(Split-Path -Leaf $ArtifactPath)"
    
    $hash = Get-FileHash -Path $ArtifactPath -Algorithm SHA256
    $filename = Split-Path -Leaf $ArtifactPath
    $checksumContent = "$($hash.Hash.ToLower())  $filename"
    
    Set-Content -Path $checksumFile -Value $checksumContent
    
    Write-Success "Created checksum: $checksumFile"
}

# Sign artifact with GPG
function Invoke-GpgSign {
    param([string]$ArtifactPath)
    
    if (-not $GpgKeyId) {
        Write-Error "GPG_KEY_ID not set. Please set it or run 'generate-keys' first"
        return $false
    }
    
    $signatureFile = "$ArtifactPath.sig"
    
    Write-Info "Signing $(Split-Path -Leaf $ArtifactPath) with GPG key $GpgKeyId"
    
    try {
        gpg --armor --detach-sign --default-key $GpgKeyId --output $signatureFile $ArtifactPath
        Write-Success "Created GPG signature: $signatureFile"
        return $true
    } catch {
        Write-Error "Failed to create GPG signature: $_"
        return $false
    }
}

# Sign artifact with Cosign
function Invoke-CosignSign {
    param([string]$ArtifactPath)
    
    if (-not (Test-Path $CosignKey)) {
        Write-Error "Cosign key not found at $CosignKey. Please run 'generate-keys' first"
        return $false
    }
    
    Write-Info "Signing $(Split-Path -Leaf $ArtifactPath) with Cosign"
    
    try {
        $env:COSIGN_PASSWORD = ""
        cosign sign --key $CosignKey --upload=$false $ArtifactPath
        Write-Success "Created Cosign signature for $(Split-Path -Leaf $ArtifactPath)"
        return $true
    } catch {
        Write-Warning "Failed to create Cosign signature: $_"
        return $false
    }
}

# Verify GPG signature
function Test-GpgSignature {
    param([string]$ArtifactPath)
    
    $signatureFile = "$ArtifactPath.sig"
    
    if (-not (Test-Path $signatureFile)) {
        Write-Error "GPG signature file not found: $signatureFile"
        return $false
    }
    
    Write-Info "Verifying GPG signature for $(Split-Path -Leaf $ArtifactPath)"
    
    try {
        gpg --verify $signatureFile $ArtifactPath 2>$null
        Write-Success "GPG signature verification passed"
        return $true
    } catch {
        Write-Error "GPG signature verification failed"
        return $false
    }
}

# Verify Cosign signature
function Test-CosignSignature {
    param([string]$ArtifactPath)
    
    $publicKey = "$CosignKey.pub"
    
    if (-not (Test-Path $publicKey)) {
        Write-Error "Cosign public key not found: $publicKey"
        return $false
    }
    
    Write-Info "Verifying Cosign signature for $(Split-Path -Leaf $ArtifactPath)"
    
    try {
        cosign verify --key $publicKey $ArtifactPath 2>$null
        Write-Success "Cosign signature verification passed"
        return $true
    } catch {
        Write-Error "Cosign signature verification failed"
        return $false
    }
}

# Verify checksums
function Test-Checksum {
    param([string]$ArtifactPath)
    
    $checksumFile = "$ArtifactPath.sha256"
    
    if (-not (Test-Path $checksumFile)) {
        Write-Error "Checksum file not found: $checksumFile"
        return $false
    }
    
    Write-Info "Verifying checksum for $(Split-Path -Leaf $ArtifactPath)"
    
    try {
        $expectedHash = (Get-Content $checksumFile).Split()[0]
        $actualHash = (Get-FileHash -Path $ArtifactPath -Algorithm SHA256).Hash.ToLower()
        
        if ($expectedHash -eq $actualHash) {
            Write-Success "Checksum verification passed"
            return $true
        } else {
            Write-Error "Checksum verification failed"
            return $false
        }
    } catch {
        Write-Error "Failed to verify checksum: $_"
        return $false
    }
}

# Sign all artifacts in directory
function Invoke-SignArtifacts {
    param([string]$ArtifactsDirectory = $ArtifactsDir)
    
    if (-not (Test-Path $ArtifactsDirectory)) {
        Write-Error "Artifacts directory not found: $ArtifactsDirectory"
        return
    }
    
    Write-Info "Signing all artifacts in $ArtifactsDirectory"
    
    $signedCount = 0
    $artifacts = Get-ChildItem -Path $ArtifactsDirectory -File | Where-Object { $_.Extension -notin @('.sig', '.sha256') }
    
    foreach ($artifact in $artifacts) {
        Write-Info "Processing artifact: $($artifact.Name)"
        
        # Create checksums
        New-Checksum -ArtifactPath $artifact.FullName
        
        # Sign with GPG
        if (Invoke-GpgSign -ArtifactPath $artifact.FullName) {
            $signedCount++
        }
        
        # Sign with Cosign (for supported formats)
        if ($artifact.Extension -in @('.tar', '.gz', '.bz2', '.zip')) {
            Invoke-CosignSign -ArtifactPath $artifact.FullName | Out-Null
        }
    }
    
    Write-Success "Signed $signedCount artifacts"
}

# Verify all artifacts in directory
function Test-Artifacts {
    param([string]$ArtifactsDirectory = $ArtifactsDir)
    
    if (-not (Test-Path $ArtifactsDirectory)) {
        Write-Error "Artifacts directory not found: $ArtifactsDirectory"
        return
    }
    
    Write-Info "Verifying all artifacts in $ArtifactsDirectory"
    
    $verifiedCount = 0
    $failedCount = 0
    $artifacts = Get-ChildItem -Path $ArtifactsDirectory -File | Where-Object { $_.Extension -notin @('.sig', '.sha256') }
    
    foreach ($artifact in $artifacts) {
        Write-Info "Verifying artifact: $($artifact.Name)"
        
        $verificationPassed = $true
        
        # Verify checksums
        if (-not (Test-Checksum -ArtifactPath $artifact.FullName)) {
            $verificationPassed = $false
        }
        
        # Verify GPG signature
        if (-not (Test-GpgSignature -ArtifactPath $artifact.FullName)) {
            $verificationPassed = $false
        }
        
        # Verify Cosign signature (if exists)
        if ($artifact.Extension -in @('.tar', '.gz', '.bz2', '.zip')) {
            Test-CosignSignature -ArtifactPath $artifact.FullName | Out-Null
        }
        
        if ($verificationPassed) {
            $verifiedCount++
            Write-Success "Verification passed for $($artifact.Name)"
        } else {
            $failedCount++
            Write-Error "Verification failed for $($artifact.Name)"
        }
    }
    
    Write-Info "Verification complete: $verifiedCount passed, $failedCount failed"
    
    if ($failedCount -gt 0) {
        exit 1
    }
}

# Show usage information
function Show-Usage {
    @"
Usage: .\artifact-signing.ps1 [COMMAND] [OPTIONS]

Commands:
    generate-keys              Generate GPG and Cosign key pairs
    sign [artifacts_dir]       Sign all artifacts in directory (default: ./artifacts)
    verify [artifacts_dir]     Verify all artifacts in directory (default: ./artifacts)
    sign-file <file>          Sign a specific file
    verify-file <file>        Verify a specific file
    help                      Show this help message

Environment Variables:
    GPG_KEY_ID               GPG key ID to use for signing
    COSIGN_KEY              Path to Cosign private key (default: .keys/cosign.key)

Examples:
    .\artifact-signing.ps1 generate-keys          # Generate signing keys
    .\artifact-signing.ps1 sign                   # Sign all artifacts in ./artifacts
    .\artifact-signing.ps1 verify                 # Verify all artifacts in ./artifacts
    .\artifact-signing.ps1 sign-file app.tar.gz   # Sign specific file

"@
}

# Main script logic
Ensure-Directories
Test-Dependencies

switch ($Command) {
    "generate-keys" {
        New-GpgKey
        New-CosignKey
    }
    "sign" {
        $artifactsPath = if ($Path) { $Path } else { $ArtifactsDir }
        Invoke-SignArtifacts -ArtifactsDirectory $artifactsPath
    }
    "verify" {
        $artifactsPath = if ($Path) { $Path } else { $ArtifactsDir }
        Test-Artifacts -ArtifactsDirectory $artifactsPath
    }
    "sign-file" {
        if (-not $Path) {
            Write-Error "File path required for sign-file command"
            Show-Usage
            exit 1
        }
        New-Checksum -ArtifactPath $Path
        Invoke-GpgSign -ArtifactPath $Path
    }
    "verify-file" {
        if (-not $Path) {
            Write-Error "File path required for verify-file command"
            Show-Usage
            exit 1
        }
        Test-Checksum -ArtifactPath $Path
        Test-GpgSignature -ArtifactPath $Path
    }
    "help" {
        Show-Usage
    }
    default {
        Write-Error "Unknown command: $Command"
        Show-Usage
        exit 1
    }
}