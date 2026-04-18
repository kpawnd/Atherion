#!/bin/bash

remove_deepfreeze_and_faronics() {
    local had_error=0
    local matched=0
    local line kind value
    local py_script="${ACID_ROOT}/scripts/py/deepfreeze_targets.py"

    print_info "Removing Deep Freeze / Faronics from known service labels and known paths."

    if command -v python3 >/dev/null 2>&1 && [[ -f "$py_script" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            kind="${line%%|*}"
            value="${line#*|}"
            [[ -z "$value" ]] && continue
            matched=1

            case "$kind" in
                LABEL)
                    print_info "Stopping launch service: $value"
                    if ! launchctl bootout system "$value" >/dev/null 2>&1; then
                        launchctl remove "$value" >/dev/null 2>&1 || {
                            print_warn "Could not fully remove service: $value"
                            had_error=1
                        }
                    fi
                    ;;
                PATH)
                    print_info "Deleting known path: $value"
                    launchctl unload "$value" >/dev/null 2>&1 || true
                    if ! rm -rf "$value"; then
                        print_warn "Could not delete: $value"
                        had_error=1
                    fi
                    ;;
                RECEIPT)
                    print_info "Forgetting package receipt: $value"
                    pkgutil --forget "$value" >/dev/null 2>&1 || true
                    ;;
            esac
        done < <(python3 "$py_script" 2>/dev/null)
    else
        while IFS= read -r value; do
            [[ -z "$value" ]] && continue
            matched=1
            print_info "Stopping launch service: $value"
            launchctl bootout system "$value" >/dev/null 2>&1 || launchctl remove "$value" >/dev/null 2>&1 || true
        done < <(launchctl list 2>/dev/null | awk '{print $3}' | grep -Ei 'faronics|deep[[:space:]_-]*freeze|deepfreeze')
    fi

    if [[ "$matched" -eq 0 ]]; then
        print_info "No known Deep Freeze / Faronics service labels or paths found."
    fi

    if [[ "$had_error" -eq 1 ]]; then
        print_warn "Deep Freeze / Faronics known-path cleanup completed with some failures."
        return 1
    fi

    print_ok "Deep Freeze / Faronics known-path cleanup completed."
    return 0
}
