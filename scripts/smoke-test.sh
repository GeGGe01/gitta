#!/usr/bin/env bash
set -euo pipefail

DEB_PATH=${1:-dist/gitta_0.1.0_amd64.deb}

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not available; skipping container smoke test." >&2
  exit 0
fi

IMG="ubuntu:22.04"

echo "[smoke] Using image: $IMG"
docker run --rm -i -v "$(pwd)":/work "$IMG" bash -lc "\
  set -e; \
  apt-get update -qq; \
  apt-get install -y -qq ca-certificates gnupg >/dev/null; \
  dpkg -i /work/$DEB_PATH || apt-get -f install -y -qq; \
  gitta --version; \
  printf "- first change\n- second change\n" | gitta | grep -q "^first change$"; \
  echo 'OK' \
"
