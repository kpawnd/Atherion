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
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
exec btop "$@"
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
