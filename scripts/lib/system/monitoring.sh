#!/bin/bash

create_sysmon_command() {
    local target_dir="$HOME/.local/bin"
    local target_file="$target_dir/sysmon"

    mkdir -p "$target_dir" || return 1

    cat > "$target_file" <<'EOF'
#!/bin/bash
set -uo pipefail

get_cpu_temp() {
    if command -v osx-cpu-temp >/dev/null 2>&1; then
        osx-cpu-temp 2>/dev/null || echo "unavailable"
        return
    fi

    if command -v istats >/dev/null 2>&1; then
        istats cpu temp --no-graphs 2>/dev/null | head -n 1 | sed 's/^ *//' || echo "unavailable"
        return
    fi

    if command -v powermetrics >/dev/null 2>&1; then
        sudo -n powermetrics --samplers smc -n 1 2>/dev/null | grep -i 'CPU die temperature' | head -n 1 | sed 's/^ *//' || echo "unavailable (sudo permission required)"
        return
    fi

    echo "unavailable"
}

print_once() {
    echo "System Monitor - $(date)"
    echo "=============================================="
    echo "Host: $(scutil --get ComputerName 2>/dev/null || hostname)"
    echo "Uptime: $(uptime | sed 's/^ *//')"
    echo "CPU Temp: $(get_cpu_temp)"
    echo ""
    echo "CPU Summary"
    top -l 1 | grep -E '^CPU usage:' || true
    echo ""
    echo "Memory Summary"
    vm_stat | head -n 6 || true
    echo ""
    echo "Disk"
    df -h / || true
    echo ""
    echo "Top Processes (CPU)"
    ps -Ao pid,ppid,%cpu,%mem,comm -r | head -n 12
}

if [[ "${1:-}" == "--once" ]]; then
    print_once
    exit 0
fi

while true; do
    clear
    print_once
    echo ""
    echo "Refreshing every 2 seconds. Press Ctrl+C to exit."
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
    local alias_line='alias sysmon="$HOME/.local/bin/sysmon"'

    touch "$bashrc" "$bash_profile" || return 1

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

    return 0
}
