#!/usr/bin/env bash
set -euo pipefail

# APT repository publisher script
# Generates Packages, Release, InRelease and signs with GPG
# Based on AGENTS.md specification section 5.1

REPO_DIR="${REPO_DIR:-$(pwd)}"
PACKAGE_NAME="${PACKAGE_NAME:-gitta}"
ARCHES="${ARCHES:-amd64}"
DEB_GLOB="${DEB_GLOB:-*.deb}"
DIST_NAME="${DIST_NAME:-stable}"

echo "[publish-apt] Publishing APT repository in: $REPO_DIR"
echo "[publish-apt] Package: $PACKAGE_NAME, Architectures: $ARCHES"

cd "$REPO_DIR"

# Create APT repository structure
mkdir -p "dists/$DIST_NAME/main"
for arch in ${ARCHES//,/ }; do
    mkdir -p "dists/$DIST_NAME/main/binary-$arch"
done
mkdir -p "pool/main"

# Move .deb files to pool
echo "[publish-apt] Moving .deb files to pool/main/"
for deb in $DEB_GLOB; do
    if [[ -f "$deb" ]]; then
        echo "  -> $deb"
        cp -v "$deb" "pool/main/"
    fi
done

# Generate Packages files for each architecture
for arch in ${ARCHES//,/ }; do
    echo "[publish-apt] Generating Packages for $arch"
    apt-ftparchive -a "$arch" packages "./pool/main" > "dists/$DIST_NAME/main/binary-$arch/Packages"
    gzip -f "dists/$DIST_NAME/main/binary-$arch/Packages"
done

# Generate Release file
echo "[publish-apt] Generating Release file"
cat > "dists/$DIST_NAME/Release" << EOF
Origin: $PACKAGE_NAME
Label: $PACKAGE_NAME
Suite: $DIST_NAME
Codename: $DIST_NAME
Architectures: $ARCHES all
Components: main
Description: $PACKAGE_NAME APT repository
Date: $(date -Ru)
EOF

# Add checksums to Release
apt-ftparchive release "dists/$DIST_NAME" >> "dists/$DIST_NAME/Release"

# Sign with GPG if key is available
if gpg --list-secret-keys >/dev/null 2>&1; then
    KEY_FPR=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/{print $5;exit}')
    echo "[publish-apt] Signing with GPG key: $KEY_FPR"
    
    # Create InRelease (clearsigned)
    gpg --batch --yes --default-key "$KEY_FPR" --output "dists/$DIST_NAME/InRelease" --clearsign "dists/$DIST_NAME/Release"
    
    # Create detached signature for clients that expect it
    gpg --batch --yes --default-key "$KEY_FPR" --output "dists/$DIST_NAME/Release.gpg" --detach-sign "dists/$DIST_NAME/Release"
    
    echo "[publish-apt] Generated InRelease and Release.gpg"
else
    echo "[publish-apt] WARNING: No GPG key found, repository will be unsigned"
fi

echo "[publish-apt] APT repository published successfully"
ls -la "dists/$DIST_NAME/"