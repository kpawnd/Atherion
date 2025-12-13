#!/bin/bash

# ============================================================================
# MacBook Optimization Script - All-in-One Edition
# ============================================================================

# Configuration constants
CONFIG_FILE="$HOME/.macbook_optimizer_state.conf"

# Colors for status messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ============================================================================
# CONFIG FUNCTIONS
# ============================================================================

function initialize_config() {
    local config_dir=$(dirname "$CONFIG_FILE")
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir" 2>/dev/null || {
            echo -e "${RED}Error: Cannot create config directory $config_dir${NC}"
            return 1
        }
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        if touch "$CONFIG_FILE" 2>/dev/null; then
            chmod 644 "$CONFIG_FILE" 2>/dev/null
        else
            echo -e "${RED}Error: Cannot create config file $CONFIG_FILE${NC}"
            echo -e "${YELLOW}Please check your home directory permissions${NC}"
            return 1
        fi
    fi

    if [ ! -w "$CONFIG_FILE" ]; then
        if chmod 644 "$CONFIG_FILE" 2>/dev/null; then
            echo -e "${YELLOW}Fixed permissions for config file${NC}"
        else
            echo -e "${RED}Error: Config file exists but is not writable${NC}"
            echo -e "${YELLOW}Try running: chmod 644 $CONFIG_FILE${NC}"
            return 1
        fi
    fi

    return 0
}

function add_timestamp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
}

function check_status() {
    local timestamp=$(add_timestamp)
    local status_message
    local config_entry

    if [ $? -eq 0 ]; then
        status_message="${GREEN}Success: $1${NC}"
        config_entry="$2=enabled|$timestamp"
    else
        status_message="${RED}Error: $1${NC}"
        config_entry="$2=failed|$timestamp"
    fi

    echo -e "$status_message"

    if write_to_config "$config_entry"; then
        return 0
    else
        echo -e "${YELLOW}Warning: Could not save status to config file${NC}"
        return 1
    fi
}

function write_to_config() {
    local entry="$1"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Config file doesn't exist, attempting to create...${NC}"
        initialize_config || return 1
    fi

    if [ ! -w "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Cannot write to config file (permission denied)${NC}"
        echo -e "${YELLOW}Config file location: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}Please run: chmod 644 $CONFIG_FILE${NC}"
        return 1
    fi

    if echo "$entry" >> "$CONFIG_FILE" 2>/dev/null; then
        return 0
    else
        echo -e "${RED}Error: Failed to write to config file${NC}"
        return 1
    fi
}

function safe_read_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi

    if [ ! -r "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Cannot read config file (permission denied)${NC}"
        echo -e "${YELLOW}Config file location: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}Please run: chmod 644 $CONFIG_FILE${NC}"
        return 1
    fi

    return 0
}

function get_feature_status() {
    local feature=$1
    echo -e "\n${BLUE}Feature Status Report:${NC}"
    echo -e "${BLUE}------------------${NC}"
    
    if ! safe_read_config; then
        echo -e "Feature: ${YELLOW}$feature${NC}"
        echo -e "Status: ${RED}config file not accessible${NC}"
        echo -e "${BLUE}------------------${NC}\n"
        return 1
    fi

    if grep -q "^$feature=" "$CONFIG_FILE" 2>/dev/null; then
        local line=$(grep "^$feature=" "$CONFIG_FILE" | tail -n 1)
        local status=$(echo "$line" | cut -d'|' -f1 | cut -d'=' -f2)
        local timestamp=$(echo "$line" | cut -d'|' -f2)

        echo -e "Feature: ${YELLOW}$feature${NC}"
        if [ "$status" = "enabled" ]; then
            echo -e "Status: ${GREEN}$status${NC}"
        else
            echo -e "Status: ${RED}$status${NC}"
        fi
        echo -e "Last Run: $timestamp"
    else
        echo -e "Feature: ${YELLOW}$feature${NC}"
        echo -e "Status: ${YELLOW}never run${NC}"
    fi
    echo -e "${BLUE}------------------${NC}\n"
}

function show_all_statuses() {
    echo -e "\n${BLUE}Complete System Status Report${NC}"
    echo -e "${BLUE}===========================${NC}"
    
    if ! safe_read_config; then
        echo -e "${RED}Cannot access configuration file${NC}"
        return 1
    fi

    if [ ! -s "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}No optimizations have been run yet.${NC}"
        return
    fi

    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local feature=$(echo "$line" | cut -d'=' -f1)
            local status=$(echo "$line" | cut -d'|' -f1 | cut -d'=' -f2)
            local timestamp=$(echo "$line" | cut -d'|' -f2)

            echo -e "${YELLOW}$feature${NC}:"
            if [ "$status" = "enabled" ]; then
                echo -e "  Status: ${GREEN}$status${NC}"
            else
                echo -e "  Status: ${RED}$status${NC}"
            fi
            echo -e "  Last Run: $timestamp"
            echo -e "${BLUE}------------------${NC}"
        fi
    done < "$CONFIG_FILE"
}

# ============================================================================
# SYSTEM OPTIMIZATION FUNCTIONS
# ============================================================================

function optimize_system_performance() {
    echo "Optimizing system performance..."
    sudo sysctl -w kern.ipc.somaxconn=2048
    sudo sysctl -w kern.ipc.nmbclusters=65536
    sudo sysctl -w kern.maxvnodes=750000
    sudo sysctl -w kern.maxproc=2048
    sudo sysctl -w kern.maxfiles=200000
    sudo sysctl -w kern.maxfilesperproc=100000
    check_status "System performance optimized" "system_performance"
}

function optimize_memory_management() {
    echo "Optimizing memory management..."
    sudo purge
    sudo pmset -a sms 0
    sudo sysctl -w kern.maxvnodes=750000
    sudo sysctl -w kern.maxproc=2048
    sudo sysctl -w kern.maxfiles=200000
    sudo sysctl -w kern.maxfilesperproc=100000
    sudo sync
    sudo purge
    check_status "Memory management optimized" "memory_management"
}

function optimize_ssd() {
    echo "Optimizing SSD settings..."
    sudo trimforce enable
    sudo pmset -a hibernatemode 0
    sudo rm /var/vm/sleepimage
    check_status "SSD optimized" "ssd_optimization"
}

function optimize_security() {
    echo "Optimizing security settings..."
    sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1
    sudo defaults write /Library/Preferences/com.apple.alf stealthenabled -int 1
    sudo defaults write /Library/Preferences/com.apple.alf allowsignedenabled -int 1
    check_status "Security settings optimized" "security_optimization"
}

# ============================================================================
# NETWORK OPTIMIZATION FUNCTIONS
# ============================================================================

function optimize_network_settings() {
    echo "Optimizing network settings..."
    sudo sysctl -w net.inet.tcp.delayed_ack=0
    sudo sysctl -w net.inet.tcp.mssdflt=1440
    sudo sysctl -w net.inet.tcp.blackhole=2
    sudo sysctl -w net.inet.icmp.icmplim=50
    sudo sysctl -w net.inet.tcp.path_mtu_discovery=1
    sudo sysctl -w net.inet.tcp.tcp_keepalive=1
    check_status "Network settings optimized" "network_optimization"
}

function flush_dns_cache() {
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    check_status "DNS cache flushed" "dns_flush"
}

function enable_firewall() {
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    check_status "Network firewall enabled" "firewall"
}

# ============================================================================
# STORAGE OPTIMIZATION FUNCTIONS
# ============================================================================

function clear_system_caches() {
    sudo rm -rf ~/Library/Caches/*
    sudo rm -rf /Library/Caches/*
    check_status "System caches cleared" "cache_clear"
}

function remove_unused_languages() {
    sudo rm -rf /System/Library/CoreServices/Language\ Chooser.app
    check_status "Unused languages removed" "language_cleanup"
}

function clear_font_caches() {
    sudo atsutil databases -remove
    sudo atsutil server -shutdown
    sudo atsutil server -ping
    check_status "Font caches cleared" "font_cache"
}

function remove_ds_store_files() {
    find . -name '.DS_Store' -depth -exec rm {} \;
    check_status "DS_Store files removed" "ds_store_cleanup"
}

# ============================================================================
# PERFORMANCE TWEAK FUNCTIONS
# ============================================================================

function disable_spotlight() {
    sudo mdutil -a -i off
    check_status "Spotlight indexing disabled" "spotlight"
}

function disable_dashboard() {
    defaults write com.apple.dashboard mcx-disabled -boolean YES
    killall Dock
    check_status "Dashboard disabled" "dashboard"
}

function disable_animations() {
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
    defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
    defaults write com.apple.dock launchanim -bool false
    killall Dock
    check_status "Animations disabled" "animations"
}

function optimize_dock() {
    defaults write com.apple.dock launchanim -bool false
    defaults write com.apple.dock expose-animation-duration -float 0
    defaults write com.apple.dock springboard-show-duration -int 0
    defaults write com.apple.dock springboard-hide-duration -int 0
    killall Dock
    check_status "Dock animations disabled" "dock_optimization"
}

# ============================================================================
# MAINTENANCE FUNCTIONS
# ============================================================================

function verify_disk_permissions() {
    sudo diskutil verifyPermissions /
    check_status "Disk permissions verified" "disk_permissions"
}

function run_maintenance_scripts() {
    sudo periodic daily weekly monthly
    check_status "Maintenance scripts executed" "maintenance_scripts"
}

function clear_system_logs() {
    sudo rm -rf /var/log/*
    check_status "System logs cleared" "log_cleanup"
}

function reset_smc() {
    echo "Please follow these steps to reset SMC:"
    echo "1. Shut down your MacBook"
    echo "2. Hold Shift + Control + Option and Power button for 10 seconds"
    echo "3. Release all keys and power button"
    echo "4. Press power button to turn on your MacBook"
    read -p "Press Enter when done..."
    check_status "SMC reset instructions provided" "smc_reset"
}

# ============================================================================
# POWER MANAGEMENT FUNCTIONS
# ============================================================================

function optimize_power() {
    echo "Optimizing power settings..."
    sudo pmset -a displaysleep 15
    sudo pmset -a disksleep 10
    sudo pmset -a womp 1
    sudo pmset -a networkoversleep 0
    check_status "Power settings optimized" "power_optimization"
}

function toggle_power_saving() {
    echo "Power Saving Mode Management..."
    local current_mode=$(pmset -g | grep lowpowermode | awk '{print $2}')
    
    if [ "$current_mode" = "1" ]; then
        sudo pmset -a lowpowermode 0
        check_status "Power saving mode disabled" "power_saving"
    else
        sudo pmset -a lowpowermode 1
        sudo pmset -a displaysleep 5
        sudo pmset -a disksleep 5
        sudo pmset -a sleep 10
        sudo pmset -a lessbright 1
        sudo pmset -a halfdim 1
        check_status "Power saving mode enabled" "power_saving"
    fi

    echo -e "\n${BLUE}Current Power Settings:${NC}"
    pmset -g
}

function check_mdm_status() {
    echo -e "${YELLOW}Checking MDM (Mobile Device Management) Status...${NC}"
    echo "----------------------------------------"
    local mdm_detected=false
    local mdm_details=""

    echo -e "\n${BLUE}Checking /etc/hosts for MDM entries:${NC}"
    if grep -q "deviceenrollment.apple.com\|mdmenrollment.apple.com\|iprofiles.apple.com" /etc/hosts; then
        echo -e "${RED}Found MDM blocking entries in /etc/hosts:${NC}"
        grep "deviceenrollment.apple.com\|mdmenrollment.apple.com\|iprofiles.apple.com" /etc/hosts
        mdm_detected=true
        mdm_details+="MDM blocking entries found in /etc/hosts\n"
    else
        echo -e "${GREEN}No MDM blocking entries found in /etc/hosts${NC}"
    fi

    echo -e "\n${BLUE}Checking enrollment profiles:${NC}"
    local profile_output=$(sudo profiles show -type enrollment 2>&1)
    if [[ $profile_output == *"There are no enrollment profiles"* ]]; then
        echo -e "${GREEN}No enrollment profiles found${NC}"
    else
        echo -e "${RED}Enrollment profiles detected:${NC}"
        echo "$profile_output"
        mdm_detected=true
        mdm_details+="MDM enrollment profiles detected\n"
    fi

    echo -e "\n${YELLOW}MDM Status Summary:${NC}"
    if [ "$mdm_detected" = true ]; then
        echo -e "${RED}MDM Detection: POSITIVE${NC}"
        echo -e "Details:"
        echo -e "$mdm_details"
        echo -e "\nRecommendation: Your device appears to be under MDM control."
    else
        echo -e "${GREEN}MDM Detection: NEGATIVE${NC}"
        echo "Your device appears to be free from MDM control."
    fi

    read -p "Press Enter to continue..."
}

function toggle_auto_boot() {
    echo "AutoBoot Feature Management..."
    
    if [[ $(sysctl -n machdep.cpu.brand_string) == *"Intel"* ]]; then
        echo "Current AutoBoot status:"
        nvram -p | grep "AutoBoot" || echo "AutoBoot status not found"
        
        echo -e "\n1. Disable AutoBoot (prevent auto-start when opening lid)"
        echo "2. Enable AutoBoot (restore default behavior)"
        echo "3. Return to previous menu"
        read -p "Enter your choice (1-3): " choice

        case $choice in
            1)
                sudo nvram AutoBoot=%00
                check_status "AutoBoot disabled - Mac won't automatically start when opening lid" "autoboot"
                echo -e "\nNew AutoBoot status:"
                nvram -p | grep "AutoBoot" || echo "AutoBoot status not found"
                echo -e "\n${YELLOW}The changes require a system restart to take effect.${NC}"
                read -p "Would you like to restart now? (y/n): " restart_choice
                if [[ $restart_choice =~ ^[Yy]$ ]]; then
                    echo "System will restart in 5 seconds..."
                    sleep 5
                    sudo shutdown -r now
                else
                    echo "Please remember to restart your system later for changes to take effect."
                fi
                ;;
            2)
                sudo nvram AutoBoot=%03
                check_status "AutoBoot enabled - Mac will start when opening lid" "autoboot"
                echo -e "\nNew AutoBoot status:"
                nvram -p | grep "AutoBoot" || echo "AutoBoot status not found"
                echo -e "\n${YELLOW}The changes require a system restart to take effect.${NC}"
                read -p "Would you like to restart now? (y/n): " restart_choice
                if [[ $restart_choice =~ ^[Yy]$ ]]; then
                    echo "System will restart in 5 seconds..."
                    sleep 5
                    sudo shutdown -r now
                else
                    echo "Please remember to restart your system later for changes to take effect."
                fi
                ;;
            3)
                return
                ;;
            *)
                echo "Invalid choice. Please try again."
                ;;
        esac
    else
        echo "This feature is only available for Intel-based Macs."
        echo "Your Mac appears to be using Apple Silicon."
    fi

    read -p "Press Enter to continue..."
}

# ============================================================================
# SYSTEM MONITORING FUNCTIONS
# ============================================================================

function display_system_info() {
    local info_type=$1

    case $info_type in
        "cpu")
            clear
            echo -e "\n${YELLOW}CPU Information:${NC}"
            echo -e "CPU Model: $(sysctl -n machdep.cpu.brand_string)"
            echo -e "CPU Cores: $(sysctl -n hw.ncpu)"
            echo -e "CPU Speed: $(sysctl -n hw.cpufrequency_max | awk '{print $1 / 1000000000 "GHz"}')"
            echo -e "\nCPU Load:"
            top -l 1 | grep -E "^CPU"
            ;;
        "memory")
            clear
            echo -e "\n${YELLOW}Memory Status:${NC}"
            echo -e "Total RAM: $(sysctl -n hw.memsize | awk '{print $1 / 1024/1024/1024 "GB"}')"
            vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^0-9]+(\d+)/ and printf("%-16s % 16.2f MB\n", "$1:", $2 * $size / 1048576);'
            ;;
        "gpu")
            clear
            echo -e "\n${YELLOW}GPU Information:${NC}"
            system_profiler SPDisplaysDataType | grep -A 10 "Chipset Model"
            ;;
        "battery")
            clear
            echo -e "\n${YELLOW}Battery Information:${NC}"
            pmset -g batt | grep -v "Now drawing from"
            system_profiler SPPowerDataType | grep -E "Cycle Count|Condition|Charge Remaining|Charging|Full Charge Capacity|Battery Installed"
            ;;
        "disk")
            clear
            echo -e "\n${YELLOW}Disk Space:${NC}"
            df -h / | tail -n 1 | awk '{print "Used: " $3 " of " $2 " (" $5 " used)"}'
            ;;
        "network")
            clear
            echo -e "\n${YELLOW}Network Status:${NC}"
            echo -e "Active Interfaces:"
            netstat -nr | grep default | awk '{print $NF}'
            ;;
        "temperature")
            clear
            echo -e "\n${YELLOW}Temperature Sensors:${NC}"
            if command -v istats &> /dev/null; then
                istats
            else
                echo "Installing iStats for temperature monitoring..."
                sudo gem install iStats
                istats
            fi
            ;;
    esac
}

function check_system_status() {
    while true; do
        clear
        echo -e "\n${BLUE}=== System Status Check ===${NC}"
        echo -e "${BLUE}------------------------${NC}"
        echo -e "\nChoose information to view:"
        echo -e "${YELLOW}1. CPU Information${NC}"
        echo -e "${YELLOW}2. Memory Status${NC}"
        echo -e "${YELLOW}3. GPU Information${NC}"
        echo -e "${YELLOW}4. Battery Information${NC}"
        echo -e "${YELLOW}5. Disk Space${NC}"
        echo -e "${YELLOW}6. Network Status${NC}"
        echo -e "${YELLOW}7. Temperature Sensors${NC}"
        echo -e "${YELLOW}8. View All Information${NC}"
        echo -e "${YELLOW}0. Back to Main Menu${NC}"
        read -p "Enter your choice (0-8): " info_choice

        case $info_choice in
            1) display_system_info "cpu" ;;
            2) display_system_info "memory" ;;
            3) display_system_info "gpu" ;;
            4) display_system_info "battery" ;;
            5) display_system_info "disk" ;;
            6) display_system_info "network" ;;
            7) display_system_info "temperature" ;;
            8)
                for type in "cpu" "memory" "gpu" "battery" "disk" "network" "temperature"; do
                    display_system_info "$type"
                    echo -e "\nPress Enter to continue..."
                    read
                done
                ;;
            0) return ;;
            *) echo -e "${RED}Invalid choice. Please enter a number between 0 and 8.${NC}" ;;
        esac

        if [ "$info_choice" != "0" ] && [ "$info_choice" != "8" ]; then
            echo -e "\nPress Enter to return to system status menu..."
            read
        fi
    done

    check_status "System status check completed" "system_check"
}

# ============================================================================
# MULTI-SELECT SECTION HANDLERS
# ============================================================================

function run_selected_optimizations() {
    local section_name=$1
    shift
    local -a options=("$@")
    
    echo -e "\n${CYAN}Select optimizations to run (e.g., A,C or A C):${NC}"
    for i in "${!options[@]}"; do
        local letter=$(printf "\\$(printf '%03o' $((65 + i)))")
        echo -e "${YELLOW}${letter}. ${options[$i]}${NC}"
    done
    echo -e "${YELLOW}0. Cancel${NC}"
    
    read -p "Enter your selections: " selections
    
    # Handle cancel
    if [[ "$selections" =~ ^0$ ]]; then
        echo -e "${YELLOW}Cancelled${NC}"
        return
    fi
    
    # Convert to uppercase and remove spaces/commas
    selections=$(echo "$selections" | tr '[:lower:]' '[:upper:]' | tr -d ' ' | tr ',' ' ')
    
    # Execute selected optimizations
    for sel in $selections; do
        # Convert letter to index (A=0, B=1, etc.)
        local idx=$(($(printf '%d' "'$sel") - 65))
        
        if [ $idx -ge 0 ] && [ $idx -lt ${#options[@]} ]; then
            echo -e "\n${BLUE}Running: ${options[$idx]}${NC}"
            case "$section_name" in
                "system")
                    case $idx in
                        0) optimize_system_performance ;;
                        1) optimize_memory_management ;;
                        2) optimize_ssd ;;
                        3) optimize_security ;;
                    esac
                    ;;
                "network")
                    case $idx in
                        0) optimize_network_settings ;;
                        1) flush_dns_cache ;;
                        2) enable_firewall ;;
                    esac
                    ;;
                "storage")
                    case $idx in
                        0) clear_system_caches ;;
                        1) remove_unused_languages ;;
                        2) clear_font_caches ;;
                        3) remove_ds_store_files ;;
                    esac
                    ;;
                "performance")
                    case $idx in
                        0) disable_spotlight ;;
                        1) disable_dashboard ;;
                        2) disable_animations ;;
                        3) optimize_dock ;;
                    esac
                    ;;
                "maintenance")
                    case $idx in
                        0) verify_disk_permissions ;;
                        1) run_maintenance_scripts ;;
                        2) clear_system_logs ;;
                        3) reset_smc ;;
                    esac
                    ;;
                "power")
                    case $idx in
                        0) optimize_power ;;
                        1) toggle_power_saving ;;
                        2) toggle_auto_boot ;;
                    esac
                    ;;
            esac
        else
            echo -e "${RED}Invalid selection: $sel${NC}"
        fi
    done
}

# ============================================================================
# MAIN MENU AND HANDLER
# ============================================================================

function display_main_menu() {
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     MacBook Optimization Script - All-in-One         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${MAGENTA}═══ OPTIMIZATION SECTIONS ═══${NC}"
    echo -e "${YELLOW}1. System Optimizations${NC}"
    echo -e "${YELLOW}2. Network Optimizations${NC}"
    echo -e "${YELLOW}3. Storage Optimizations${NC}"
    echo -e "${YELLOW}4. Performance Tweaks${NC}"
    echo -e "${YELLOW}5. Maintenance${NC}"
    echo -e "${YELLOW}6. Power Management${NC}"
    
    echo -e "\n${MAGENTA}═══ SYSTEM TOOLS ═══${NC}"
    echo -e "${YELLOW}7. Check System Status${NC}"
    echo -e "${YELLOW}8. View All Optimization States${NC}"
    echo -e "${YELLOW}9. Reset All Optimizations${NC}"
    echo -e "${YELLOW}10. Check MDM Status${NC}"
    
    echo -e "\n${YELLOW}0. Quit${NC}"
    echo -e "${BLUE}═════════════════════════════════════════════════════════${NC}"
}

function handle_user_choice() {
    read -p "Enter your choice: " choice
    echo ""

    case $choice in
        1)
            run_selected_optimizations "system" \
                "Optimize System Performance" \
                "Optimize Memory Management" \
                "Optimize SSD Settings" \
                "Optimize Security"
            ;;
        2)
            run_selected_optimizations "network" \
                "Optimize Network Settings" \
                "Flush DNS Cache" \
                "Enable Network Firewall"
            ;;
        3)
            run_selected_optimizations "storage" \
                "Clear System Caches" \
                "Remove Unused Languages" \
                "Clear Font Caches" \
                "Remove .DS_Store Files"
            ;;
        4)
            run_selected_optimizations "performance" \
                "Disable Spotlight Indexing" \
                "Disable Dashboard" \
                "Disable Animations" \
                "Optimize Dock"
            ;;
        5)
            run_selected_optimizations "maintenance" \
                "Verify Disk Permissions" \
                "Run Daily Maintenance Scripts" \
                "Clear System Logs" \
                "Reset SMC"
            ;;
        6)
            run_selected_optimizations "power" \
                "Optimize Power Settings" \
                "Toggle Power Saving Mode" \
                "Toggle AutoBoot (Intel Only)"
            ;;
        7)
            check_system_status
            ;;
        8)
            show_all_statuses
            ;;
        9)
            echo -e "${YELLOW}Resetting all optimization states...${NC}"
            if [ -f "$CONFIG_FILE" ]; then
                if rm "$CONFIG_FILE" 2>/dev/null; then
                    if initialize_config; then
                        echo -e "${GREEN}All optimization states reset successfully${NC}"
                    else
                        echo -e "${RED}Failed to recreate config file${NC}"
                    fi
                else
                    echo -e "${RED}Failed to remove existing config file${NC}"
                    echo -e "${YELLOW}You may need to manually delete: $CONFIG_FILE${NC}"
                fi
            else
                echo -e "${YELLOW}Config file doesn't exist, creating new one...${NC}"
                if initialize_config; then
                    echo -e "${GREEN}Config file created successfully${NC}"
                else
                    echo -e "${RED}Failed to create config file${NC}"
                fi
            fi
            ;;
        10)
            check_mdm_status
            ;;
        0)
            echo -e "${GREEN}Quitting the script. Bye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter a valid option.${NC}"
            ;;
    esac

    if [ "$choice" != "0" ]; then
        echo -e "\nPress Enter to continue..."
        read
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function main() {
    echo -e "${BLUE}Initializing MacBook Optimization Script...${NC}"
    
    if ! initialize_config; then
        echo -e "${RED}Failed to initialize configuration. Script may not work properly.${NC}"
        echo -e "${YELLOW}Press any key to continue anyway, or Ctrl+C to exit...${NC}"
        read -n 1 -s
    fi

    while true; do
        clear
        display_main_menu
        handle_user_choice
    done
}

# Start the script
main
