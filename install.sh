#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="hjy666-mc"
REPO_NAME="Swift-Craft-Launcher-CLI"
PROJECT_NAME="Swift-Craft-Launcher-CLI"
SCHEME="Swift-Craft-Launcher-CLI"
CONFIGURATION="Release"
BIN_NAME="scl"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
RELEASE_BASE="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/latest/download"

arch="$(uname -m)"
case "${arch}" in
  arm64|aarch64) ASSET_NAME="scl-macos-arm64" ;;
  x86_64) ASSET_NAME="scl-macos-x64" ;;
  *)
    echo "Unsupported architecture: ${arch}" >&2
    exit 1
    ;;
esac

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/scl-install.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

add_path_if_needed() {
  if printf '%s' ":${PATH}:" | grep -q ":${INSTALL_DIR}:"; then
    return
  fi

  local shell_name path_line
  shell_name="$(basename "${SHELL:-}")"
  path_line="export PATH=\"${INSTALL_DIR}:\$PATH\""

  local -a rc_files=()
  case "${shell_name}" in
    zsh)
      rc_files+=("${HOME}/.zprofile" "${HOME}/.zshrc")
      ;;
    bash)
      rc_files+=("${HOME}/.bash_profile" "${HOME}/.bashrc")
      ;;
    *)
      rc_files+=("${HOME}/.profile")
      ;;
  esac

  for rc_file in "${rc_files[@]}"; do
    if [[ ! -f "${rc_file}" ]] || ! grep -Fq "${INSTALL_DIR}" "${rc_file}"; then
      {
        echo ""
        echo "# Added by ${BIN_NAME} installer"
        echo "${path_line}"
      } >> "${rc_file}"
      echo "PATH updated in ${rc_file}."
    fi
  done

  if [[ ${#rc_files[@]} -gt 0 ]]; then
    echo "Open a new terminal or run: source ${rc_files[0]}"
  fi
}

install_binary() {
  local source_bin="$1"
  echo "[2/3] Installing to ${INSTALL_DIR}/${BIN_NAME}..."
  if [[ ! -d "${INSTALL_DIR}" ]]; then
    sudo mkdir -p "${INSTALL_DIR}"
  fi
  sudo install -m 0755 "${source_bin}" "${INSTALL_DIR}/${BIN_NAME}"
}

echo "[1/3] Downloading prebuilt binary (${ASSET_NAME})..."
DOWNLOAD_URL="${RELEASE_BASE}/${ASSET_NAME}"
DOWNLOADED_BIN="${TMP_DIR}/${ASSET_NAME}"

if curl -fL "${DOWNLOAD_URL}" -o "${DOWNLOADED_BIN}" >/dev/null 2>&1; then
  chmod +x "${DOWNLOADED_BIN}"
  install_binary "${DOWNLOADED_BIN}"
  add_path_if_needed
  echo "[3/3] Done (installed from release binary)."
  echo "Run: ${BIN_NAME} --help"
  exit 0
fi

echo "Prebuilt binary download failed, fallback to source build..."
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode Command Line Tools or publish release binary assets first." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git not found. Please install git first." >&2
  exit 1
fi

PROJECT_DIR="${TMP_DIR}/${PROJECT_NAME}"
git clone --depth=1 "${REPO_URL}" "${PROJECT_DIR}" >/dev/null 2>&1

echo "[2/3] Building ${PROJECT_NAME} (${CONFIGURATION})..."
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

install_binary "${SOURCE_BIN}"
add_path_if_needed

echo "[3/3] Done (installed from source build)."
echo "Run: ${BIN_NAME} --help"
