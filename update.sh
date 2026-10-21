#!/bin/bash
set -e

# PCL Plugin - All Versions Builder & Uploader
REPO_OWNER="niubikelashi"
REPO_NAME="PCL"
PLUGIN_NAME="Plain Craft Launcher 2"
RELEASE_DIR="./release"
SOLUTION_FILE="Plain Craft Launcher 2.sln"

echo "=== ${PLUGIN_NAME} Build & Release ==="

# Check if MSBuild is available
if ! command -v msbuild &> /dev/null; then
    echo "[ERROR] MSBuild not found. Please install Visual Studio Build Tools."
    exit 1
fi

# Clean build directory
rm -rf "${RELEASE_DIR}"
mkdir -p "${RELEASE_DIR}"

# Parse arguments: tag name or "all"
TAG="${1:-latest}"

if [ "${TAG}" = "all" ]; then
    echo "Building all tags..."
    TAGS=$(git ls-remote --tags origin | grep -oP 'refs/tags/\K[^~^]+' || echo "")
    
    if [ -z "${TAGS}" ]; then
        # Fetch tags if not available locally
        git fetch --tags --force || true
        TAGS=$(git tag -l | sort -V)
    fi
    
    for TAG in ${TAGS}; do
        echo "============================================"
        echo "Building PCL v${TAG}..."
        echo "============================================"
        
        # Checkout the tag (detached HEAD mode)
        git checkout "${TAG}" || { echo "[WARN] Failed to checkout ${TAG}, skipping."; continue; }
        
        # Initialize submodules
        git submodule init
        git submodule update --recursive
        
        # Build
        nuget restore "${SOLUTION_FILE}" 2>/dev/null || true
        msbuild "${SOLUTION_FILE}" /p:Configuration=Release /p:Platform=x64 || { echo "[WARN] Build failed for ${TAG}"; continue; }
        
        # Copy output files to release directory
        OUTPUT_DIR="Plain Craft Launcher 2/bin/x64/Release"
        if [ -d "${OUTPUT_DIR}" ]; then
            mkdir -p "${RELEASE_DIR}/PCL-${TAG}"
            cp "${OUTPUT_DIR}/PCL.exe" "${RELEASE_DIR}/PCL-${Tag}/" || true
            cp "${OUTPUT_DIR}/*.dll" "${RELEASE_DIR}/PCL-${Tag}/" 2>/dev/null || true
            
            echo "[OK] PCL v${TAG} built successfully ($(du -sh "${RELEASE_DIR}/PCL-${Tag}" | cut -f1))"
        else
            echo "[WARN] No output found for ${TAG}, checking different paths..."
            # Try fallback locations
            find "Plain Craft Launcher 2/bin/x64/Release/" -name "*.exe" -exec cp {} "${RELEASE_DIR}/PCL-${Tag}/" \; 2>/dev/null || true
        fi
        
        git checkout main 2>/dev/null || true
    done
    
    echo ""
    echo "=== All builds complete ==="
    echo "Artifacts saved in: ${RELEASE_DIR}"
else
    # Build single tag
    if ! git rev-parse "${TAG}" --verify > /dev/null 2>&1; then
        echo "[ERROR] Tag '${TAG}' not found. Run 'git fetch --tags' first."
        exit 1
    fi
    
    echo "Building PCL v${TAG}..."
    
    # Checkout the tag
    git checkout "${TAG}" || { echo "[ERROR] Failed to checkout ${TAG}"; exit 1; }
    
    # Initialize submodules
    git submodule init
    git submodule update --recursive
    
    # Build
    nuget restore "${SOLUTION_FILE}" 2>/dev/null || true
    msbuild "${SOLUTION_FILE}" /p:Configuration=Release /p:Platform=x64 || { echo "[ERROR] Build failed!"; exit 1; }
    
    # Copy output
    OUTPUT_DIR="Plain Craft Launcher 2/bin/x64/Release"
    mkdir -p "${RELEASE_DIR}/PCL-${TAG}"
    cp "${OUTPUT_DIR}/PCL.exe" "${RELEASE_DIR}/PCL-${Tag}/"
    cp "${OUTPUT_DIR}/*.dll" "${RELEASE_DIR}/PCL-${Tag}/" 2>/dev/null || true
    
    echo "Built: PCL v${TAG} ($(du -sh "${RELEASE_DIR}/PCL-${Tag}" | cut -f1))"
    
    # Push to main branch for artifact tracking
    git checkout main
fi
