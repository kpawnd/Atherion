#!/bin/bash

cleanup_legacy_sysmon_artifacts() {
    local target_dir="$HOME/.local/bin"
    local removed=0

    rm -f "$target_dir/sysmon.old" "$target_dir/sysmon.bak" "$target_dir/sysmon-legacy" >/dev/null 2>&1 && removed=1 || true
    rm -rf "$HOME/.cache/sysmon" "$HOME/.config/sysmon-legacy" >/dev/null 2>&1 && removed=1 || true

    if [[ -L "$target_dir/sysmon" && ! -e "$target_dir/sysmon" ]]; then
        rm -f "$target_dir/sysmon" >/dev/null 2>&1 || true
        removed=1
    fi

    if [[ "$removed" -eq 1 ]]; then
        print_ok "Cleaned legacy sysmon artifacts"
    else
        print_ok "No legacy sysmon artifacts found"
    fi

    return 0
}

create_sysmon_command() {
    local target_dir="$HOME/.local/bin"
    local target_file="$target_dir/sysmon"

    mkdir -p "$target_dir" || return 1

    cat > "$target_file" <<'EOF'
#!/bin/bash
set -uo pipefail

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

get_cpu_temp() {
    if command -v osx-cpu-temp >/dev/null 2>&1; then
        osx-cpu-temp 2>/dev/null || echo "unavailable"
        return
    fi

    if command -v istats >/dev/null 2>&1; then
        istats cpu temp --no-graphs 2>/dev/null | head -n 1 | awk '{print $NF}' || echo "unavailable"
        return
    fi

    if command -v powermetrics >/dev/null 2>&1; then
        if sudo -n powermetrics --samplers smc -n 1 >/dev/null 2>&1; then
            sudo -n powermetrics --samplers smc -n 1 2>/dev/null | grep -i 'CPU die temperature' | head -n 1 | awk '{print $NF}' || echo "unavailable"
            return
        fi
    fi

    echo "unavailable"
}

format_bytes() {
    local bytes=$1
    if [[ $bytes -ge 1073741824 ]]; then
        echo "$(( bytes / 1073741824 ))GB"
    elif [[ $bytes -ge 1048576 ]]; then
        echo "$(( bytes / 1048576 ))MB"
    else
        echo "$(( bytes / 1024 ))KB"
    fi
}

get_memory_stats() {
    local vm_output
    local pages_free
    local pages_active
    local pages_wired
    local pagesize
    
    vm_output=$(vm_stat)
    pagesize=$(vm_output | grep -i 'page size' | awk '{print $NF}')
    [[ -z "$pagesize" ]] && pagesize=4096
    
    pages_free=$(echo "$vm_output" | grep 'Pages free' | awk '{print $NF}' | tr -d '.')
    pages_active=$(echo "$vm_output" | grep 'Pages active' | awk '{print $NF}' | tr -d '.')
    pages_wired=$(echo "$vm_output" | grep 'Pages wired' | awk '{print $NF}' | tr -d '.')
    
    echo "$((pages_free * pagesize)),$((pages_active * pagesize)),$((pages_wired * pagesize))"
}

print_once() {
    printf "${BOLD}${CYAN}╔════ System Diagnostics ════╗${NC}\n"
    printf "${CYAN}║${NC} $(date '+%a %b %d %H:%M:%S %Y')\n"
    printf "${CYAN}║${NC} Host: ${BOLD}$(scutil --get ComputerName 2>/dev/null || hostname)${NC}\n"
    printf "${CYAN}║${NC} Uptime: $(uptime | sed 's/.*up \([^,]*\).*/\1/')\n"
    printf "${CYAN}║${NC} CPU Temp: $(get_cpu_temp) °C\n"
    printf "${BOLD}${CYAN}╠════════════════════════════╣${NC}\n"
    
    printf "${CYAN}║ CPU${NC}\n"
    top -l 1 2>/dev/null | grep -E '^CPU usage:' | sed 's/^/║   /'
    printf "${CYAN}║${NC}\n"
    
    printf "${CYAN}║ Memory${NC}\n"
    local mem_stats=$(get_memory_stats)
    local mem_free=$(echo "$mem_stats" | cut -d',' -f1)
    local mem_active=$(echo "$mem_stats" | cut -d',' -f2)
    local mem_wired=$(echo "$mem_stats" | cut -d',' -f3)
    printf "${CYAN}║${NC}   Free: $(format_bytes "$mem_free")\n"
    printf "${CYAN}║${NC}   Active: $(format_bytes "$mem_active")\n"
    printf "${CYAN}║${NC}   Wired: $(format_bytes "$mem_wired")\n"
    printf "${CYAN}║${NC}\n"
    
    printf "${CYAN}║ Disk (/)${NC}\n"
    df -h / 2>/dev/null | tail -1 | awk '{printf "║   Used: %s | Available: %s | Capacity: %s\n", $3, $4, $5}' | sed 's/^/║   /' | head -1
    df -h / 2>/dev/null | tail -1 | awk '{print $3, $4, $5}' | (read used avail cap; printf "${CYAN}║${NC}   Used: ${YELLOW}%s${NC} | Available: ${GREEN}%s${NC} | Capacity: ${YELLOW}%s${NC}\n" "$used" "$avail" "$cap")
    printf "${CYAN}║${NC}\n"
    
    printf "${CYAN}║ Top Processes (by CPU)${NC}\n"
    ps -Ao pid,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | head -7 | tail -6 | while read pid cpu mem comm; do
        printf "${CYAN}║${NC}   PID: %5s | CPU: %5s | MEM: %5s | %s\n" "$pid" "$cpu" "$mem" "$comm"
    done
    printf "${BOLD}${CYAN}╚════════════════════════════╝${NC}\n"
}

show_help() {
    cat <<USAGE
Usage: sysmon [--once] [--legacy] [--help]

Default:
  Launches btop when available (recommended monitor).

Options:
  --once    Print one snapshot and exit.
  --legacy  Force legacy built-in monitor loop.
  --help    Show this help message.
USAGE
}

if [[ "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

if [[ "${1:-}" != "--once" && "${1:-}" != "--legacy" ]]; then
    if command -v btop >/dev/null 2>&1; then
        exec btop
    fi
fi

if [[ "${1:-}" == "--once" ]]; then
    print_once
    exit 0
fi

while true; do
    clear
    print_once
    printf "\n${YELLOW}Refreshing every 2 seconds. Press Ctrl+C to exit.${NC}\n"
    sleep 2
done
EOF

    chmod +x "$target_file" || return 1
    print_ok "System monitor command created: $target_file"
    return 0
}

ensure_bash_alias() {
    local bashrc="$HOME/.bashrc"
    local bash_profile="$HOME/.bash_profile"
    local zshrc="$HOME/.zshrc"
    local alias_line='alias sysmon="$HOME/.local/bin/sysmon"'

    touch "$bashrc" "$bash_profile" "$zshrc" || return 1

    if ! grep -Fxq "$alias_line" "$bashrc"; then
        echo "$alias_line" >> "$bashrc" || return 1
        print_ok "Added sysmon alias to $bashrc"
    else
        print_ok "sysmon alias already exists in $bashrc"
    fi

    if ! grep -Fxq "$alias_line" "$bash_profile"; then
        echo "$alias_line" >> "$bash_profile" || return 1
        print_ok "Added sysmon alias to $bash_profile"
    else
        print_ok "sysmon alias already exists in $bash_profile"
    fi

    if ! grep -Fxq "$alias_line" "$zshrc"; then
        echo "$alias_line" >> "$zshrc" || return 1
        print_ok "Added sysmon alias to $zshrc"
    else
        print_ok "sysmon alias already exists in $zshrc"
    fi

    return 0
}
