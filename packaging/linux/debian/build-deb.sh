#!/usr/bin/env bash
# Builds a scaphandre .deb for each supported Ubuntu version, compiling
# inside a container matching that version so the auto-detected library
# dependencies (glibc, openssl, ...) are correct for the target host.
set -euo pipefail

REVISION="${1:-ifca-advanced-computing1}"
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DOCKERFILE="$REPO_ROOT/packaging/linux/debian/Dockerfile.build"
BUILD_CONTEXT="$REPO_ROOT/packaging/linux/debian"

# "ubuntu-version:output-tag" pairs
DISTROS=("22.04:ubuntu2204" "24.04:ubuntu2404" "26.04:ubuntu2604")

mkdir -p "$REPO_ROOT/target/debian"

for entry in "${DISTROS[@]}"; do
    UBUNTU_VERSION="${entry%%:*}"
    TAG="${entry##*:}"
    IMAGE="scaphandre-deb-builder:${UBUNTU_VERSION}"
    TARGET_DIR="$REPO_ROOT/target/debian-build-${TAG}"

    echo "==> Building scaphandre .deb for Ubuntu ${UBUNTU_VERSION} (revision ${REVISION})"

    docker build \
        --build-arg UBUNTU_VERSION="${UBUNTU_VERSION}" \
        -t "${IMAGE}" \
        -f "${DOCKERFILE}" \
        "${BUILD_CONTEXT}"

    docker run --rm \
        -v "${REPO_ROOT}:/build" \
        -e CARGO_TARGET_DIR="/build/target/debian-build-${TAG}" \
        -w /build \
        --user "$(id -u):$(id -g)" \
        -e HOME=/tmp \
        "${IMAGE}" \
        cargo deb --deb-revision "${REVISION}"

    BUILT_DEB=$(ls "${TARGET_DIR}"/debian/scaphandre_*_amd64.deb)
    DEST="$REPO_ROOT/target/debian/$(basename "${BUILT_DEB%_amd64.deb}_${TAG}_amd64.deb")"
    cp "${BUILT_DEB}" "${DEST}"
    echo "==> ${DEST}"
done
