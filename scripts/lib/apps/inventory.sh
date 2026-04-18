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
