#!/bin/bash

print_summary() {
    echo ""
    echo "Execution summary:"
    echo "- Total steps: $TOTAL_STEPS"
    echo "- Failed steps: $FAILED_STEPS"

    if [[ "$FAILED_STEPS" -eq 0 ]]; then
        print_ok "All steps completed successfully."
    else
        print_warn "Script completed with some failures. Review warnings above."
    fi

    echo ""
    echo "What is configured:"
    echo "1. Homebrew installation attempt."
    echo "2. App version report for Azure Data Studio, Blender, and Android Studio."
    echo "3. Firmware password change routine (interactive user input)."
    echo "4. Known-path Deep Freeze / Faronics cleanup attempt."
    echo "5. Power schedule with pmset (Mon-Sat)."
    echo "   - Wake/Power on: 07:00"
    echo "   - Shutdown: 21:30"
    echo "6. AC wake enabled and Power Nap disabled."
    echo "7. System monitor command installed: ~/.local/bin/sysmon"
    echo "8. Bash alias added: sysmon"
    echo "9. Performance tweaks applied (Spotlight/animations/Dock)."
    echo "10. Reinstall target apps and record cask lock metadata."
    echo "11. Cisco Packet Tracer install from GitHub release tag Cisco (or PACKET_TRACER_DMG_URL override)."
    echo ""
    echo "Use now:"
    echo "- sysmon           (live terminal monitor)"
    echo "- sysmon --once    (single snapshot)"
    echo ""
    if [[ "$FIRMWARE_PASSWORD_CHANGED" -eq 1 ]]; then
        print_warn "Firmware password was changed. Restart is recommended before validation."
    fi
    print_info "Open a new shell (or run: source ~/.bashrc) to use the alias immediately."
}
