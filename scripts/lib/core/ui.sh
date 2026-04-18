#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_STEPS=0
FAILED_STEPS=0
FIRMWARE_PASSWORD_CHANGED=0

print_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_err() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

clear_inline_status() {
    if [[ -t 1 ]]; then
        printf "\r\033[2K"
    fi
}

spinner_wait() {
    local pid="$1"
    local label="$2"
    local frames='|/-\\'
    local i=0

    if [[ ! -t 1 ]]; then
        wait "$pid"
        return $?
    fi

    while kill -0 "$pid" >/dev/null 2>&1; do
        printf "\r\033[2K${BLUE}[RUN]${NC} %s [%c]" "$label" "${frames:i++%${#frames}:1}"
        sleep 0.12
    done

    wait "$pid"
    local status=$?
    clear_inline_status
    return $status
}

render_app_install_progress() {
    local current="$1"
    local total="$2"
    local label="$3"
    local width=28
    local pct=0
    local filled=0
    local empty=0
    local bar

    if [[ "$total" -gt 0 ]]; then
        pct=$(( (current * 100) / total ))
    fi

    filled=$(( (pct * width) / 100 ))
    empty=$(( width - filled ))
    bar="$(printf '%*s' "$filled" '' | tr ' ' '#')$(printf '%*s' "$empty" '' | tr ' ' '-')"

    printf "\r\033[2K${BLUE}[INSTALL]${NC} [%s] %3d%% - %s" "$bar" "$pct" "$label"
}

announce_install_stage() {
    local current="$1"
    local total="$2"
    local label="$3"

    render_app_install_progress "$current" "$total" "$label"
    printf "\n"
}
