#!/bin/bash

get_app_version() {
    local app_path="$1"
    local plist="$app_path/Contents/Info.plist"
    local version=""

    if [[ ! -f "$plist" ]]; then
        echo "unknown"
        return 0
    fi

    version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null || true)"
    if [[ -z "$version" ]]; then
        version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist" 2>/dev/null || true)"
    fi
    if [[ -z "$version" ]]; then
        version="unknown"
    fi

    echo "$version"
}

report_installed_app_versions() {
    local py_script="${ACID_ROOT}/scripts/py/report_apps.py"
    local line app_name status version
    local azure_app="/Applications/Azure Data Studio.app"
    local blender_app="/Applications/Blender.app"
    local android_app="/Applications/Android Studio.app"

    print_info "Checking installed app versions..."

    if command -v python3 >/dev/null 2>&1 && [[ -f "$py_script" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            app_name="${line%%|*}"
            status="${line#*|}"
            status="${status%%|*}"
            version="${line##*|}"

            if [[ "$status" == "installed" ]]; then
                print_ok "$app_name installed. Version: $version"
            else
                print_info "$app_name not installed."
            fi
        done < <(python3 "$py_script" 2>/dev/null)
        return 0
    fi

    if [[ -d "$azure_app" ]]; then
        print_ok "Azure Data Studio installed. Version: $(get_app_version "$azure_app")"
    else
        print_info "Azure Data Studio not installed."
    fi

    if [[ -d "$blender_app" ]]; then
        print_ok "Blender installed. Version: $(get_app_version "$blender_app")"
    else
        print_info "Blender not installed."
    fi

    if [[ -d "$android_app" ]]; then
        print_ok "Android Studio installed. Version: $(get_app_version "$android_app")"
    else
        print_info "Android Studio not installed."
    fi

    return 0
}

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
        # Lightweight fallback if python3 is unavailable.
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
