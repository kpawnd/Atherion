#!/bin/bash

configure_firmware_password() {
    local answer

    if [[ "$(sysctl -n machdep.cpu.brand_string 2>/dev/null || true)" != *"Intel"* ]]; then
        print_warn "Firmware password tool is not supported on this Mac type. Skipping."
        return 0
    fi

    if [[ ! -x /usr/sbin/firmwarepasswd ]]; then
        print_warn "firmwarepasswd tool not found. Skipping firmware password step."
        return 0
    fi

    read -r -p "Change firmware password now? (y/N): " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        print_info "Firmware password change skipped by user."
        return 0
    fi

    print_info "Current firmware password status:"
    sudo /usr/sbin/firmwarepasswd -check || print_warn "Could not read current firmware password status."

    print_info "You will now be prompted for password input by firmwarepasswd."
    print_info "If a firmware password already exists, provide current password first."

    if ! sudo /usr/sbin/firmwarepasswd -setpasswd; then
        print_warn "Firmware password change did not complete."
        return 1
    fi

    FIRMWARE_PASSWORD_CHANGED=1
    print_ok "Firmware password change completed."
    return 0
}

configure_power_management() {
    local had_error=0

    print_info "Applying power management settings..."

    if ! sudo pmset repeat cancel; then
        print_warn "Failed to clear existing pmset repeat schedule."
        had_error=1
    fi

    if ! sudo pmset repeat wakeorpoweron MTWRFS 07:00:00; then
        print_warn "Failed to set wake/power on schedule."
        had_error=1
    fi

    if ! sudo pmset repeat shutdown MTWRFS 21:30:00; then
        print_warn "Failed to set shutdown schedule."
        had_error=1
    fi

    if ! sudo pmset -a acwake 1; then
        print_warn "Failed to enable AC wake."
        had_error=1
    fi

    if ! sudo pmset -a powernap 0; then
        print_warn "Failed to disable Power Nap."
        had_error=1
    fi

    if [[ "$had_error" -eq 1 ]]; then
        return 1
    fi

    print_ok "Power schedule set for Mon-Sat: on at 07:00, off at 21:30."
    print_ok "AC wake enabled and Power Nap disabled."
    return 0
}

configure_performance_tweaks() {
    local had_error=0

    print_info "Applying performance tweaks..."

    if ! sudo mdutil -a -i off >/dev/null 2>&1; then
        print_warn "Failed to disable Spotlight indexing."
        had_error=1
    fi

    if ! defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false; then
        print_warn "Failed to disable automatic window animations."
        had_error=1
    fi
    if ! defaults write NSGlobalDomain NSWindowResizeTime -float 0.001; then
        print_warn "Failed to reduce window resize animation time."
        had_error=1
    fi
    if ! defaults write com.apple.dock launchanim -bool false; then
        print_warn "Failed to disable Dock launch animation."
        had_error=1
    fi

    defaults write com.apple.dashboard mcx-disabled -boolean YES >/dev/null 2>&1 || true

    if ! defaults write com.apple.dock expose-animation-duration -float 0; then
        print_warn "Failed to set expose animation duration."
        had_error=1
    fi
    defaults write com.apple.dock springboard-show-duration -int 0 >/dev/null 2>&1 || true
    defaults write com.apple.dock springboard-hide-duration -int 0 >/dev/null 2>&1 || true

    if ! killall Dock >/dev/null 2>&1; then
        print_warn "Could not restart Dock automatically."
        had_error=1
    fi

    if [[ "$had_error" -eq 1 ]]; then
        return 1
    fi

    print_ok "Performance tweaks applied."
    return 0
}
