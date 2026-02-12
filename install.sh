#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="Swift-Craft-Launcher-CLI"
SCHEME="Swift-Craft-Launcher-CLI"
CONFIGURATION="Release"
BIN_NAME="scl"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

echo "[1/3] Building ${PROJECT_NAME} (${CONFIGURATION})..."
xcodebuild \
  -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -quiet \
  build

BUILD_SETTINGS="$(xcodebuild \
  -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -showBuildSettings)"

TARGET_BUILD_DIR="$(printf '%s\n' "${BUILD_SETTINGS}" | awk -F' = ' '/TARGET_BUILD_DIR/ {print $2; exit}')"
EXECUTABLE_PATH="$(printf '%s\n' "${BUILD_SETTINGS}" | awk -F' = ' '/EXECUTABLE_PATH/ {print $2; exit}')"

if [[ -z "${TARGET_BUILD_DIR}" || -z "${EXECUTABLE_PATH}" ]]; then
  echo "Failed to resolve build output path." >&2
  exit 1
fi

SOURCE_BIN="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"
if [[ ! -f "${SOURCE_BIN}" ]]; then
  echo "Built binary not found: ${SOURCE_BIN}" >&2
  exit 1
fi

echo "[2/3] Installing to ${INSTALL_DIR}/${BIN_NAME}..."
if [[ ! -d "${INSTALL_DIR}" ]]; then
  sudo mkdir -p "${INSTALL_DIR}"
fi
sudo install -m 0755 "${SOURCE_BIN}" "${INSTALL_DIR}/${BIN_NAME}"

echo "[3/3] Done."
echo "Run: ${BIN_NAME} --help"

