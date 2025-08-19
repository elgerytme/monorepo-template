#!/bin/bash
# Artifact signing and verification system
# Provides cryptographic signing and verification of release artifacts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
ARTIFACTS_DIR="$REPO_ROOT/artifacts"
SIGNATURES_DIR="$REPO_ROOT/signatures"
KEYS_DIR="$REPO_ROOT/.keys"
GPG_KEY_ID="${GPG_KEY_ID:-}"
COSIGN_KEY="${COSIGN_KEY:-$KEYS_DIR/cosign.key}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Ensure required directories exist
ensure_directories() {
    mkdir -p "$ARTIFACTS_DIR" "$SIGNATURES_DIR" "$KEYS_DIR"
}

# Check if required tools are installed
check_dependencies() {
    local missing_tools=()
    
    if ! command -v gpg &> /dev/null; then
        missing_tools+=("gpg")
    fi
    
    if ! command -v cosign &> /dev/null; then
        missing_tools+=("cosign")
    fi
    
    if ! command -v sha256sum &> /dev/null; then
        missing_tools+=("sha256sum")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again"
        exit 1
    fi
}

# Generate GPG key for signing (if not exists)
generate_gpg_key() {
    if [[ -n "$GPG_KEY_ID" ]] && gpg --list-secret-keys "$GPG_KEY_ID" &> /dev/null; then
        log_info "GPG key $GPG_KEY_ID already exists"
        return
    fi
    
    log_info "Generating new GPG key for artifact signing..."
    
    # Create GPG key generation config
    local gpg_config=$(mktemp)
    cat > "$gpg_config" << EOF
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
EOF
    
    gpg --batch --generate-key "$gpg_config"
    rm "$gpg_config"
    
    # Get the generated key ID
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep sec | head -1 | sed 's/.*\/\([A-F0-9]*\).*/\1/')
    
    log_success "Generated GPG key: $GPG_KEY_ID"
    log_info "Export GPG_KEY_ID=$GPG_KEY_ID to your environment"
}

# Generate Cosign key pair (if not exists)
generate_cosign_key() {
    if [[ -f "$COSIGN_KEY" ]]; then
        log_info "Cosign key already exists at $COSIGN_KEY"
        return
    fi
    
    log_info "Generating Cosign key pair..."
    
    # Generate key pair without password for automation
    COSIGN_PASSWORD="" cosign generate-key-pair --output-key-prefix "$KEYS_DIR/cosign"
    
    log_success "Generated Cosign key pair at $KEYS_DIR/"
    log_warning "Keep the private key secure and never commit it to version control"
}

# Create checksums for artifacts
create_checksums() {
    local artifact_path="$1"
    local checksum_file="${artifact_path}.sha256"
    
    log_info "Creating checksum for $(basename "$artifact_path")"
    
    cd "$(dirname "$artifact_path")"
    sha256sum "$(basename "$artifact_path")" > "$checksum_file"
    
    log_success "Created checksum: $checksum_file"
}

# Sign artifact with GPG
sign_with_gpg() {
    local artifact_path="$1"
    local signature_file="${artifact_path}.sig"
    
    if [[ -z "$GPG_KEY_ID" ]]; then
        log_error "GPG_KEY_ID not set. Please set it or run 'generate-keys' first"
        return 1
    fi
    
    log_info "Signing $(basename "$artifact_path") with GPG key $GPG_KEY_ID"
    
    gpg --armor --detach-sign --default-key "$GPG_KEY_ID" --output "$signature_file" "$artifact_path"
    
    log_success "Created GPG signature: $signature_file"
}

# Sign artifact with Cosign
sign_with_cosign() {
    local artifact_path="$1"
    
    if [[ ! -f "$COSIGN_KEY" ]]; then
        log_error "Cosign key not found at $COSIGN_KEY. Please run 'generate-keys' first"
        return 1
    fi
    
    log_info "Signing $(basename "$artifact_path") with Cosign"
    
    # Sign the artifact
    COSIGN_PASSWORD="" cosign sign --key "$COSIGN_KEY" --upload=false "$artifact_path"
    
    log_success "Created Cosign signature for $(basename "$artifact_path")"
}

# Verify GPG signature
verify_gpg_signature() {
    local artifact_path="$1"
    local signature_file="${artifact_path}.sig"
    
    if [[ ! -f "$signature_file" ]]; then
        log_error "GPG signature file not found: $signature_file"
        return 1
    fi
    
    log_info "Verifying GPG signature for $(basename "$artifact_path")"
    
    if gpg --verify "$signature_file" "$artifact_path" 2>/dev/null; then
        log_success "GPG signature verification passed"
        return 0
    else
        log_error "GPG signature verification failed"
        return 1
    fi
}

# Verify Cosign signature
verify_cosign_signature() {
    local artifact_path="$1"
    local public_key="${COSIGN_KEY}.pub"
    
    if [[ ! -f "$public_key" ]]; then
        log_error "Cosign public key not found: $public_key"
        return 1
    fi
    
    log_info "Verifying Cosign signature for $(basename "$artifact_path")"
    
    if cosign verify --key "$public_key" "$artifact_path" 2>/dev/null; then
        log_success "Cosign signature verification passed"
        return 0
    else
        log_error "Cosign signature verification failed"
        return 1
    fi
}

# Verify checksums
verify_checksums() {
    local artifact_path="$1"
    local checksum_file="${artifact_path}.sha256"
    
    if [[ ! -f "$checksum_file" ]]; then
        log_error "Checksum file not found: $checksum_file"
        return 1
    fi
    
    log_info "Verifying checksum for $(basename "$artifact_path")"
    
    cd "$(dirname "$artifact_path")"
    if sha256sum -c "$(basename "$checksum_file")" &>/dev/null; then
        log_success "Checksum verification passed"
        return 0
    else
        log_error "Checksum verification failed"
        return 1
    fi
}

# Sign all artifacts in directory
sign_artifacts() {
    local artifacts_dir="${1:-$ARTIFACTS_DIR}"
    
    if [[ ! -d "$artifacts_dir" ]]; then
        log_error "Artifacts directory not found: $artifacts_dir"
        return 1
    fi
    
    log_info "Signing all artifacts in $artifacts_dir"
    
    local signed_count=0
    while IFS= read -r -d '' artifact; do
        # Skip signature and checksum files
        if [[ "$artifact" =~ \.(sig|sha256)$ ]]; then
            continue
        fi
        
        log_info "Processing artifact: $(basename "$artifact")"
        
        # Create checksums
        create_checksums "$artifact"
        
        # Sign with GPG
        if sign_with_gpg "$artifact"; then
            ((signed_count++))
        fi
        
        # Sign with Cosign (for container images and other supported formats)
        if [[ "$artifact" =~ \.(tar|tar\.gz|tar\.bz2|zip)$ ]]; then
            sign_with_cosign "$artifact" || true  # Don't fail if Cosign signing fails
        fi
        
    done < <(find "$artifacts_dir" -type f -print0)
    
    log_success "Signed $signed_count artifacts"
}

# Verify all artifacts in directory
verify_artifacts() {
    local artifacts_dir="${1:-$ARTIFACTS_DIR}"
    
    if [[ ! -d "$artifacts_dir" ]]; then
        log_error "Artifacts directory not found: $artifacts_dir"
        return 1
    fi
    
    log_info "Verifying all artifacts in $artifacts_dir"
    
    local verified_count=0
    local failed_count=0
    
    while IFS= read -r -d '' artifact; do
        # Skip signature and checksum files
        if [[ "$artifact" =~ \.(sig|sha256)$ ]]; then
            continue
        fi
        
        log_info "Verifying artifact: $(basename "$artifact")"
        
        local verification_passed=true
        
        # Verify checksums
        if ! verify_checksums "$artifact"; then
            verification_passed=false
        fi
        
        # Verify GPG signature
        if ! verify_gpg_signature "$artifact"; then
            verification_passed=false
        fi
        
        # Verify Cosign signature (if exists)
        if [[ "$artifact" =~ \.(tar|tar\.gz|tar\.bz2|zip)$ ]]; then
            verify_cosign_signature "$artifact" || true  # Don't fail verification if Cosign fails
        fi
        
        if [[ "$verification_passed" == true ]]; then
            ((verified_count++))
            log_success "Verification passed for $(basename "$artifact")"
        else
            ((failed_count++))
            log_error "Verification failed for $(basename "$artifact")"
        fi
        
    done < <(find "$artifacts_dir" -type f -print0)
    
    log_info "Verification complete: $verified_count passed, $failed_count failed"
    
    if [[ $failed_count -gt 0 ]]; then
        return 1
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

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
    $0 generate-keys          # Generate signing keys
    $0 sign                   # Sign all artifacts in ./artifacts
    $0 verify                 # Verify all artifacts in ./artifacts
    $0 sign-file app.tar.gz   # Sign specific file

EOF
}

# Main script logic
main() {
    ensure_directories
    check_dependencies
    
    case "${1:-help}" in
        "generate-keys")
            generate_gpg_key
            generate_cosign_key
            ;;
        "sign")
            sign_artifacts "${2:-$ARTIFACTS_DIR}"
            ;;
        "verify")
            verify_artifacts "${2:-$ARTIFACTS_DIR}"
            ;;
        "sign-file")
            if [[ -z "${2:-}" ]]; then
                log_error "File path required for sign-file command"
                show_usage
                exit 1
            fi
            create_checksums "$2"
            sign_with_gpg "$2"
            ;;
        "verify-file")
            if [[ -z "${2:-}" ]]; then
                log_error "File path required for verify-file command"
                show_usage
                exit 1
            fi
            verify_checksums "$2"
            verify_gpg_signature "$2"
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi