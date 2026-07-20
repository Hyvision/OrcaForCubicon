#!/usr/bin/env bash
# set_version.sh — cubicon_version.txt 를 단일 출처로 버전 동기화 (STUB — Phase 2)
set -euo pipefail
ver="$(tr -d '[:space:]' < cubicon/version/cubicon_version.txt)"
echo "CUBI_ORCA_VERSION = $ver"
echo "[stub] version sync not yet implemented (Phase 2)"
