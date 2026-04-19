#!/bin/bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/app_utils.sh"

resolve_release_repo() {
    local override_repo="${RELEASES_REPO:-}"
    local root_dir="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
    local remote_url=""
    local parsed_repo=""

    if [[ -n "$override_repo" ]]; then
        echo "$override_repo"
        return 0
    fi

    remote_url="$(git -C "$root_dir" config --get remote.origin.url 2>/dev/null || true)"
    if [[ -n "$remote_url" ]]; then
        parsed_repo="$(echo "$remote_url" | sed -E 's#^.*github.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#')"
        if [[ -n "$parsed_repo" && "$parsed_repo" != "$remote_url" ]]; then
            echo "$parsed_repo"
            return 0
        fi
    fi

    echo ""
    return 1
}

get_azure_data_studio_supported_version() {
    local supported_ver="unknown"
    local download_url=""

    download_url="$(resolve_azure_data_studio_url)"
    supported_ver="$(extract_version_from_url "$download_url")"
    echo "$supported_ver"
    return 0
}

resolve_azure_data_studio_url() {
    local explicit_url="${AZURE_DATA_STUDIO_URL:-}"
    local release_repo=""
    local json=""
    local zip_url=""

    if [[ -n "$explicit_url" ]]; then
        echo "$explicit_url"
        return 0
    fi

    release_repo="$(resolve_release_repo)"
    if [[ -z "$release_repo" ]]; then
        return 1
    fi

    json="$(curl -fsSL \
        -H 'Accept: application/vnd.github+json' \
        -H 'User-Agent: lab-installer' \
        "https://api.github.com/repos/${release_repo}/releases/tags/Azure" 2>/dev/null || true)"

    if [[ -n "$json" ]]; then
        local py_lib="${PY_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/py}"
        
        if command -v python3 >/dev/null 2>&1; then
            zip_url="$(echo "$json" | python3 "$py_lib/github_utils.py" azure-asset 2>/dev/null)"
            if [[ -n "$zip_url" && "$zip_url" != "Unknown error" ]]; then
                echo "$zip_url"
                return 0
            fi
        fi
    fi

    return 1
}

install_azure_data_studio_direct() {
    local download_url=""
    local target_app="/Applications/Azure Data Studio.app"
    local mount_point="/tmp/azure_data_studio_mount"
    local work_dir="/tmp/azure_data_studio_extract"
    local dmg_file="/tmp/azure_data_studio.dmg"
    local zip_file="/tmp/azure_data_studio.zip"
    local app_path=""
    local supported_ver="unknown"
    local stage_file="${1:-}"

    print_info "Installing Azure Data Studio..."

    supported_ver="$(get_azure_data_studio_supported_version)"
    if should_skip_direct_install "$target_app" "Azure Data Studio" "$supported_ver"; then
        echo "Already installed - skipping" > "$stage_file" 2>/dev/null || true
        return 0
    fi

    echo "Resolving download URL" > "$stage_file" 2>/dev/null || true
    download_url="$(resolve_azure_data_studio_url)"
    if [[ -z "$download_url" ]]; then
        print_warn "Could not resolve Azure Data Studio download URL."
        return 1
    fi

    sudo rm -rf "$target_app" >/dev/null 2>&1 || true

    if [[ "$download_url" == *.dmg ]]; then
        rm -f "$dmg_file" >/dev/null 2>&1 || true
        echo "Downloading Azure Data Studio" > "$stage_file" 2>/dev/null || true
        monitor_download_progress "$dmg_file" "$stage_file" "Azure Data Studio" "$(get_remote_file_size "$download_url")" &
        local monitor_pid=$!
        if ! download_file_resilient "$download_url" "$dmg_file"; then
            kill $monitor_pid 2>/dev/null || true
            wait $monitor_pid 2>/dev/null || true
            print_warn "Azure Data Studio DMG download failed after retries."
            return 1
        fi
        kill $monitor_pid 2>/dev/null || true
        wait $monitor_pid 2>/dev/null || true

        echo "Verifying download" > "$stage_file" 2>/dev/null || true
        if ! hdiutil verify "$dmg_file" >/dev/null 2>&1; then
            print_warn "Downloaded Azure Data Studio DMG failed integrity verification."
            return 1
        fi

        rm -rf "$mount_point" >/dev/null 2>&1 || true
        mkdir -p "$mount_point" || return 1

        echo "Mounting DMG" > "$stage_file" 2>/dev/null || true
        if ! hdiutil attach "$dmg_file" -quiet -nobrowse -mountpoint "$mount_point" >/dev/null 2>&1; then
            print_warn "Failed to mount Azure Data Studio DMG."
            rm -f "$dmg_file" >/dev/null 2>&1 || true
            return 1
        fi

        echo "Locating app bundle" > "$stage_file" 2>/dev/null || true
        app_path="$(find "$mount_point" -maxdepth 4 -type d -name 'Azure Data Studio.app' | head -n 1)"
        if [[ -z "$app_path" ]]; then
            app_path="$(find "$mount_point" -maxdepth 4 -type d -name '*.app' | head -n 1)"
        fi

        if [[ -z "$app_path" ]]; then
            print_warn "Azure Data Studio app bundle was not found in mounted DMG."
            hdiutil detach "$mount_point" -force >/dev/null 2>&1 || true
            rm -f "$dmg_file" >/dev/null 2>&1 || true
            return 1
        fi

        echo "Copying to /Applications" > "$stage_file" 2>/dev/null || true
        if ! sudo -n ditto "$app_path" "$target_app" >/dev/null 2>&1; then
            if ! sudo ditto "$app_path" "$target_app" >/dev/null 2>&1; then
                print_warn "Failed to copy Azure Data Studio to /Applications."
                hdiutil detach "$mount_point" -force >/dev/null 2>&1 || true
                rm -f "$dmg_file" >/dev/null 2>&1 || true
                return 1
            fi
        fi

        echo "Cleaning up" > "$stage_file" 2>/dev/null || true
        hdiutil detach "$mount_point" -force >/dev/null 2>&1 || true
        rm -f "$dmg_file" >/dev/null 2>&1 || true

    elif [[ "$download_url" == *.zip ]]; then
        rm -f "$zip_file" >/dev/null 2>&1 || true
        rm -rf "$work_dir" >/dev/null 2>&1 || true
        mkdir -p "$work_dir" || return 1

        echo "Downloading Azure Data Studio" > "$stage_file" 2>/dev/null || true
        monitor_download_progress "$zip_file" "$stage_file" "Azure Data Studio" "$(get_remote_file_size "$download_url")" &
        local monitor_pid=$!
        if ! download_file_resilient "$download_url" "$zip_file"; then
            kill $monitor_pid 2>/dev/null || true
            wait $monitor_pid 2>/dev/null || true
            print_warn "Azure Data Studio zip download failed after retries."
            return 1
        fi
        kill $monitor_pid 2>/dev/null || true
        wait $monitor_pid 2>/dev/null || true

        echo "Extracting archive" > "$stage_file" 2>/dev/null || true
        if ! unzip -q "$zip_file" -d "$work_dir"; then
            print_warn "Failed to extract Azure Data Studio zip archive."
            rm -f "$zip_file" >/dev/null 2>&1 || true
            rm -rf "$work_dir" >/dev/null 2>&1 || true
            return 1
        fi

        echo "Locating app bundle" > "$stage_file" 2>/dev/null || true
        app_path="$(find "$work_dir" -maxdepth 2 -type d -name '*.app' | head -n 1)"

        if [[ -z "$app_path" ]]; then
            print_warn "Azure Data Studio app bundle was not found in extracted archive."
            rm -f "$zip_file" >/dev/null 2>&1 || true
            rm -rf "$work_dir" >/dev/null 2>&1 || true
            return 1
        fi

        echo "Copying to /Applications" > "$stage_file" 2>/dev/null || true
        if ! ditto "$app_path" "$target_app"; then
            print_warn "Failed to copy Azure Data Studio to /Applications."
            rm -f "$zip_file" >/dev/null 2>&1 || true
            rm -rf "$work_dir" >/dev/null 2>&1 || true
            return 1
        fi

        echo "Cleaning up" > "$stage_file" 2>/dev/null || true
        rm -f "$zip_file" >/dev/null 2>&1 || true
        rm -rf "$work_dir" >/dev/null 2>&1 || true
    else
        print_warn "Unsupported Azure Data Studio package type: $download_url"
        return 1
    fi

    if [[ -d "$target_app" ]]; then
        print_ok "Azure Data Studio installed. Version: $(get_app_version "$target_app")"
        return 0
    fi

    print_warn "Azure Data Studio installation completed but app was not found at $target_app"
    return 1
}

# ============================================================================
# Cisco Packet Tracer Installation
# ============================================================================

get_packet_tracer_supported_version() {
    local dmg_url=""
    local version="unknown"

    dmg_url="$(resolve_packet_tracer_dmg_url)"
    version="$(extract_version_from_url "$dmg_url")"
    version="$(normalize_packet_tracer_version "$version")"
    echo "$version"
    return 0
}

resolve_packet_tracer_dmg_url() {
    local explicit_url="${PACKET_TRACER_DMG_URL:-}"
    local release_repo="${PACKET_TRACER_RELEASE_REPO:-}"
    local release_tag="${PACKET_TRACER_RELEASE_TAG:-Cisco}"
    local api_url
    local json
    local dmg_url

    if [[ -n "$explicit_url" ]]; then
        echo "$explicit_url"
        return 0
    fi

    if [[ -z "$release_repo" ]]; then
        release_repo="$(resolve_release_repo)"
    fi

    if [[ -z "$release_repo" ]]; then
        return 1
    fi

    api_url="https://api.github.com/repos/${release_repo}/releases/tags/${release_tag}"
    json="$(curl -fsSL "$api_url" 2>&1)" || return 1

    if [[ -z "$json" ]]; then
        return 1
    fi

    if echo "$json" | grep -q '"message"'; then
        return 1
    fi

    local py_lib="${PY_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/py}"
    
    if command -v python3 >/dev/null 2>&1; then
        dmg_url="$(echo "$json" | python3 "$py_lib/github_utils.py" packet-tracer-asset 2>&1)"
        if [[ -n "$dmg_url" && "$dmg_url" != "Unknown error" ]]; then
            echo "$dmg_url"
            return 0
        fi
    fi

    return 1
}

install_packet_tracer() {
    local dmg_url=""
    local dmg_file="/tmp/cisco_packet_tracer.dmg"
    local mount_point="/tmp/packet_tracer_mount"
    local install_log="/tmp/packet_tracer_install.log"
    local app_path
    local installer_bundle="0"
    local installed_app
    local supported_ver="unknown"
    local stage_file="${1:-}"
    # Initialize stage file
    if [[ -n "$stage_file" ]]; then
        echo "Checking app" > "$stage_file"
    fi

    print_info "Installing Cisco Packet Tracer..."

    supported_ver="$(get_packet_tracer_supported_version)"
    installed_app="$(find_installed_packet_tracer_app)"
    if [[ -n "$installed_app" ]]; then
        if should_skip_direct_install "$installed_app" "Cisco Packet Tracer" "$supported_ver"; then
            return 0
        fi
    else
        print_info "Cisco Packet Tracer not currently installed. Proceeding with installation."
    fi

    echo "Resolving download URL" > "$stage_file" 2>/dev/null || true
    dmg_url="$(resolve_packet_tracer_dmg_url)"

    if [[ -z "$dmg_url" ]]; then
        echo "Failed: Could not resolve Packet Tracer URL" > "$stage_file" 2>/dev/null || true
        print_warn "Could not resolve Cisco Packet Tracer DMG URL from GitHub release."
        print_warn "Repository: ${PACKET_TRACER_RELEASE_REPO:-<auto-detected>}, Tag: ${PACKET_TRACER_RELEASE_TAG:-Cisco}"
        print_warn "Verify GitHub release exists, check network/firewall, or set PACKET_TRACER_DMG_URL manually."
        return 1
    fi

    print_info "Using Packet Tracer DMG URL: $dmg_url"

    rm -f "$dmg_file" >/dev/null 2>&1 || true
    echo "Downloading Cisco Packet Tracer" > "$stage_file" 2>/dev/null || true
    monitor_download_progress "$dmg_file" "$stage_file" "Cisco Packet Tracer" "$(get_remote_file_size "$dmg_url")" &
    local monitor_pid=$!
    if ! download_file_resilient "$dmg_url" "$dmg_file"; then
        kill $monitor_pid 2>/dev/null || true
        wait $monitor_pid 2>/dev/null || true
        print_warn "Failed to download Cisco Packet Tracer DMG."
        return 1
    fi
    kill $monitor_pid 2>/dev/null || true
    wait $monitor_pid 2>/dev/null || true

    echo "Verifying download" > "$stage_file" 2>/dev/null || true
    if ! hdiutil verify "$dmg_file" >/dev/null 2>&1; then
        print_warn "Downloaded Cisco Packet Tracer DMG failed integrity verification."
        rm -f "$dmg_file" >/dev/null 2>&1 || true
        return 1
    fi

    rm -rf "$mount_point" >/dev/null 2>&1 || true
    mkdir -p "$mount_point" || return 1

    echo "Mounting DMG" > "$stage_file" 2>/dev/null || true
    if ! hdiutil attach "$dmg_file" -quiet -nobrowse -readonly -mountpoint "$mount_point" >/dev/null 2>&1; then
        local attach_output=""
        local detected_mount=""
        attach_output="$(hdiutil attach "$dmg_file" -nobrowse -readonly 2>/dev/null || true)"
        detected_mount="$(printf '%s\n' "$attach_output" | awk -F'\t' '/\/Volumes\// {print $3}' | tail -n 1)"
        if [[ -n "$detected_mount" && -d "$detected_mount" ]]; then
            mount_point="$detected_mount"
        else
            print_warn "Failed to mount Cisco Packet Tracer DMG."
            rm -f "$dmg_file" >/dev/null 2>&1 || true
            return 1
        fi
    fi

    echo "Locating app bundle" > "$stage_file" 2>/dev/null || true
    app_path="$(find "$mount_point" -maxdepth 5 -name '*Packet*Tracer*.app' | head -n 1)"
    if [[ -z "$app_path" ]]; then
        app_path="$(find "$mount_point" -maxdepth 5 -name '*.app' | head -n 1)"
    fi

    if [[ -n "$app_path" ]]; then
        if is_packet_tracer_installer_bundle "$app_path"; then
            installer_bundle="1"
        fi
    fi

    if [[ -n "$app_path" ]]; then
        if [[ "$installer_bundle" == "1" ]]; then
            : >"$install_log"
            echo "Running installer" > "$stage_file" 2>/dev/null || true
            if ! run_packet_tracer_installer_unattended "$app_path" "$install_log" "$mount_point"; then
                print_warn "Packet Tracer unattended installation failed."
                hdiutil detach "$mount_point" -force >/dev/null 2>&1 || true
                rm -f "$dmg_file" >/dev/null 2>&1 || true
                return 1
            fi
        else
            echo "Copying app bundle to /Applications" > "$stage_file" 2>/dev/null || true
            sudo -n rm -rf "/Applications/$(basename "$app_path")" >/dev/null 2>&1 || sudo rm -rf "/Applications/$(basename "$app_path")" >/dev/null 2>&1 || true
            if ! sudo -n ditto "$app_path" "/Applications/$(basename "$app_path")" >/dev/null 2>&1; then
                if ! sudo ditto "$app_path" "/Applications/$(basename "$app_path")" >/dev/null 2>&1; then
                    print_warn "Packet Tracer app copy failed."
                    hdiutil detach "$mount_point" -force >/dev/null 2>&1 || true
                    rm -f "$dmg_file" >/dev/null 2>&1 || true
                    return 1
                fi
            fi
        fi
    else
        print_warn "No .app found inside Packet Tracer DMG."
        hdiutil detach "$mount_point" -force >/dev/null 2>&1 || true
        rm -f "$dmg_file" >/dev/null 2>&1 || true
        return 1
    fi

    echo "Verifying installation" > "$stage_file" 2>/dev/null || true
    sleep 1
    installed_app="$(find_installed_packet_tracer_app)"
    if [[ -z "$installed_app" ]]; then
        print_warn "Packet Tracer install command completed but app was not found in /Applications."
        find /Applications -maxdepth 3 -type d -name '*[Pp]acket*[Tt]racer*' 2>/dev/null | while read d; do
            print_info "  Found: $d"
        done
        hdiutil detach "$mount_point" -force >/dev/null 2>&1 || true
        rm -f "$dmg_file" >/dev/null 2>&1 || true
        return 1
    fi

    echo "Cleaning up" > "$stage_file" 2>/dev/null || true
    hdiutil detach "$mount_point" -force >/dev/null 2>&1 || true
    rm -f "$dmg_file" >/dev/null 2>&1 || true
    print_ok "Cisco Packet Tracer installation completed: $installed_app"
    return 0
}

get_android_studio_dmg_url() {
    local explicit_url="${ANDROID_STUDIO_DMG_URL:-}"
    local release_repo=""
    local json=""
    local dmg_url=""

    if [[ -n "$explicit_url" ]]; then
        echo "$explicit_url"
        return 0
    fi

    local py_lib="${PY_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/py}"

    release_repo="$(resolve_release_repo)"
    if [[ -z "$release_repo" ]]; then
        return 1
    fi

    if command -v python3 >/dev/null 2>&1; then
        json="$(curl -fsSL \
            -H 'Accept: application/vnd.github+json' \
            -H 'User-Agent: lab-installer' \
            "https://api.github.com/repos/${release_repo}/releases/tags/Android" 2>/dev/null || true)"
        if [[ -n "$json" ]]; then
            dmg_url="$(echo "$json" | python3 "$py_lib/github_utils.py" android-asset 2>/dev/null)"
            if [[ -n "$dmg_url" && "$dmg_url" != "Unknown error" ]]; then
                echo "$dmg_url"
                return 0
            fi
        fi
    fi

    return 1
}

install_android_studio_direct_dmg() {
    local dmg_url="$1"
    local dmg_file="/tmp/android_studio.dmg"
    local mount_point="/tmp/android_studio_mount"
    local app_path=""
    local target_app="/Applications/Android Studio.app"
    local stage_file="$2"
    local file_size

    print_info "Downloading Android Studio from release..."
    
    rm -f "$dmg_file" >/dev/null 2>&1 || true
    
    echo "Resolving file size" > "$stage_file" 2>/dev/null || true
    file_size="$(get_remote_file_size "$dmg_url")"
    
    echo "Downloading Android Studio" > "$stage_file" 2>/dev/null || true
    monitor_download_progress "$dmg_file" "$stage_file" "Android Studio" "$file_size" &
    local monitor_pid=$!
    if ! download_file_resilient "$dmg_url" "$dmg_file"; then
        kill $monitor_pid 2>/dev/null || true
        wait $monitor_pid 2>/dev/null || true
        print_warn "Android Studio download failed."
        return 1
    fi
    kill $monitor_pid 2>/dev/null || true
    wait $monitor_pid 2>/dev/null || true

    echo "Verifying download" > "$stage_file" 2>/dev/null || true
    if ! hdiutil verify "$dmg_file" >/dev/null 2>&1; then
        print_warn "Downloaded Android Studio DMG failed verification."
        rm -f "$dmg_file" >/dev/null 2>&1 || true
        return 1
    fi

    rm -rf "$mount_point" >/dev/null 2>&1 || true
    mkdir -p "$mount_point" || return 1

    echo "Mounting DMG" > "$stage_file" 2>/dev/null || true
    if ! hdiutil attach "$dmg_file" -quiet -nobrowse -mountpoint "$mount_point" >/dev/null 2>&1; then
        print_warn "Failed to mount Android Studio DMG."
        rm -f "$dmg_file" >/dev/null 2>&1 || true
        return 1
    fi

    echo "Locating app" > "$stage_file" 2>/dev/null || true
    app_path="$(find "$mount_point" -maxdepth 4 -type d -name 'Android Studio.app' | head -n 1)"
    if [[ -z "$app_path" ]]; then
        app_path="$(find "$mount_point" -maxdepth 4 -type d -name '*.app' | head -n 1)"
    fi

    if [[ -z "$app_path" ]]; then
        print_warn "Android Studio app not found in DMG."
        hdiutil detach "$mount_point" -force >/dev/null 2>&1 || true
        rm -f "$dmg_file" >/dev/null 2>&1 || true
        return 1
    fi

    echo "Installing" > "$stage_file" 2>/dev/null || true
    sudo rm -rf "$target_app" >/dev/null 2>&1 || true
    if ! sudo ditto "$app_path" "$target_app" >/dev/null 2>&1; then
        print_warn "Failed to copy Android Studio to /Applications."
        hdiutil detach "$mount_point" -force >/dev/null 2>&1 || true
        rm -f "$dmg_file" >/dev/null 2>&1 || true
        return 1
    fi

    echo "Cleanup" > "$stage_file" 2>/dev/null || true
    hdiutil detach "$mount_point" -force >/dev/null 2>&1 || true
    rm -f "$dmg_file" >/dev/null 2>&1 || true

    if [[ -d "$target_app" ]]; then
        print_ok "Android Studio installed from release."
        return 0
    fi

    print_warn "Android Studio install completed but app not found."
    return 1
}

install_android_studio_with_fallback() {
    local app_path="/Applications/Android Studio.app"
    local stage_file="$1"
    local dmg_url=""
    local supported_ver="unknown"

    if [[ -n "$stage_file" ]]; then
        echo "Checking app" > "$stage_file"
    fi

    print_info "Installing Android Studio from release..."

    echo "Resolving release URL" > "$stage_file" 2>/dev/null || true
    dmg_url="$(get_android_studio_dmg_url)"
    if [[ -z "$dmg_url" ]]; then
        print_warn "Could not resolve Android Studio DMG URL from release tag 'Android'."
        print_warn "Set ANDROID_STUDIO_DMG_URL to override with an explicit URL."
        return 1
    fi

    supported_ver="$(extract_version_from_url "$dmg_url")"

    if should_skip_direct_install "$app_path" "Android Studio" "$supported_ver"; then
        echo "Already installed - skipping" > "$stage_file" 2>/dev/null || true
        return 0
    fi

    echo "Installing from release" > "$stage_file" 2>/dev/null || true
    if install_android_studio_direct_dmg "$dmg_url" "$stage_file"; then
        return 0
    fi

    print_warn "Android Studio installation from release failed."
    return 1
}

install_required_software() {
    local had_error=0
    local stage_blender="/tmp/install_stage_blender.txt"
    local stage_android="/tmp/install_stage_android.txt"
    local stage_azure="/tmp/install_stage_azure.txt"
    local stage_packet="/tmp/install_stage_packet.txt"

    print_info "Installing required software set..."
    repair_homebrew_environment || true

    reinstall_cask_app "blender" "/Applications/Blender.app" "Blender" "$stage_blender" &
    spinner_wait_with_stages $! "Installing Blender" "$stage_blender" || had_error=1

    install_android_studio_with_fallback "$stage_android" &
    spinner_wait_with_stages $! "Installing Android Studio" "$stage_android" || had_error=1

    install_azure_data_studio_direct "$stage_azure" &
    spinner_wait_with_stages $! "Installing Azure Data Studio" "$stage_azure" || had_error=1

    install_packet_tracer "$stage_packet" &
    spinner_wait_with_stages $! "Installing Cisco Packet Tracer" "$stage_packet" || had_error=1

    clear_inline_status
    rm -f "$stage_blender" "$stage_android" "$stage_azure" "$stage_packet" >/dev/null 2>&1 || true
    verify_required_software_present || had_error=1

    if [[ "$had_error" -eq 1 ]]; then
        return 1
    fi

    return 0
}
