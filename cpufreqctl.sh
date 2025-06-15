#!/usr/bin/env bash
# cpufreqctl.sh — Clean, Modern CPU Power Tool with Profile Support

# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Globals ---
PROFILE_DIR="$HOME/.cpufreqctl-profiles"
DEFAULT_PROFILE="default"
MAX_LOG_ENTRIES=8
declare -a ACTION_LOG

# --- Padding Settings ---
TOP_PADDING=2
LEFT_PADDING="    "  # Four spaces

pad() {
    while IFS= read -r line; do
        echo "${LEFT_PADDING}${line}"
    done
}

# --- Utility Functions ---
echo_and_log() {
    # $1: command description, $2: command string, $3: output/result
    log_action "$1: $2"
    [[ -n "$3" ]] && log_action "$3"
}

log_action() {
    local msg="$1"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    ACTION_LOG=("[$timestamp] $msg" "${ACTION_LOG[@]}")
    if ((${#ACTION_LOG[@]} > MAX_LOG_ENTRIES)); then
        ACTION_LOG=("${ACTION_LOG[@]:0:MAX_LOG_ENTRIES}")
    fi
}

display_header() {
    clear
    for ((i=0; i<TOP_PADDING; i++)); do echo; done
    echo -e "${BLUE}CPU Frequency & Governor Tool${NC}" | pad
    if ((${#ACTION_LOG[@]} > 0)); then
        echo -e "${YELLOW}Log:${NC}" | pad
        local box_width=100
        local border=""
        for ((i=0; i<box_width; i++)); do border+="─"; done
        echo -e "${BLUE}┌${border}┐${NC}" | pad
        for ((i=${#ACTION_LOG[@]}-1; i>=0; i--)); do
            local entry="${ACTION_LOG[i]}"
            local plain_entry
            plain_entry=$(echo -e "$entry" | sed 's/\x1b\[[0-9;]*m//g')
            local len=${#plain_entry}
            if (( len > box_width )); then
                entry="${entry:0:box_width}"
            else
                entry="$entry$(printf '%*s' $((box_width - len)) '')"
            fi
            printf "${BLUE}│${NC}%s${BLUE}│${NC}\n" "$entry" | pad
        done
        echo -e "${BLUE}└${border}┘${NC}" | pad
    fi
}

# --- System Check ---
check_system() {
    log_action "Running: check Linux system"
    if [[ "$(uname)" == "Linux" ]]; then
        log_action "Result: Linux system detected"
    else
        log_action "Result: Not a Linux system"
        echo -e "${RED}Error: Not a Linux system${NC}"
        return 1
    fi
    log_action "Running: check CPU frequency scaling interface"
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        log_action "Result: CPU frequency scaling interface found"
    else
        log_action "Result: CPU frequency scaling interface NOT found"
        echo -e "${RED}Error: CPU frequency scaling not found${NC}"
        return 1
    fi
    log_action "Checking: Temperature monitoring support (ls /sys/class/hwmon)"
    if [[ ! -d /sys/class/hwmon ]]; then
        log_action "Result: Temperature monitoring interface not found"
    else
        for hw in /sys/class/hwmon/hwmon*; do
            name=$(cat "$hw"/name 2>/dev/null || echo "hwmon")
            log_action "Checking: Sensor $hw name = $name"
        done
        found_sensors=false
        found_name=""
        for hw in /sys/class/hwmon/hwmon*; do
            name=$(cat "$hw"/name 2>/dev/null || echo "hwmon")
            if [[ "$name" == "k10temp" ]] || [[ "$name" == "coretemp" ]]; then
                found_sensors=true
                found_name="$name"
                break
            fi
        done
        if $found_sensors; then
            log_action "Result: Temperature sensors found ($found_name)"
        else
            log_action "Result: Temperature interface found but no known sensors detected"
        fi
    fi
    log_action "System check complete. Main menu starting."
    return 0
}

# --- CPU Info ---
get_cores() { awk '/^cpu cores/ {print $4; exit}' /proc/cpuinfo; }
get_threads() { nproc; }
get_simple_cpu_temp() {
    for hw in /sys/class/hwmon/hwmon*; do
        name=$(cat "$hw"/name 2>/dev/null || echo "hwmon")
        if [[ "$name" == "k10temp" ]]; then
            for f in "$hw"/temp*_input; do
                [ -r "$f" ] || continue
                temp=$(( $(<"$f")/1000 ))
                echo "k10temp (CPU): $temp°C"
                return
            done
        fi
    done
    for hw in /sys/class/hwmon/hwmon*; do
        name=$(cat "$hw"/name 2>/dev/null || echo "hwmon")
        if [[ "$name" == "coretemp" ]]; then
            for f in "$hw"/temp*_input; do
                [ -r "$f" ] || continue
                temp=$(( $(<"$f")/1000 ))
                echo "coretemp (CPU): $temp°C"
                return
            done
        fi
    done
    for hw in /sys/class/hwmon/hwmon*; do
        for f in "$hw"/temp*_input; do
            [ -r "$f" ] || continue
            label_file="${f/_input/_label}"
            label=""
            [ -r "$label_file" ] && label=$(cat "$label_file")
            if [[ "$label" =~ (Package|Tctl|Tdie|CPU|Core) ]]; then
                temp=$(( $(<"$f")/1000 ))
                hwname=$(cat "$hw"/name 2>/dev/null || echo "hwmon")
                echo "$hwname: $temp°C"
                return
            fi
        done
    done
    for hw in /sys/class/hwmon/hwmon*; do
        for f in "$hw"/temp*_input; do
            [ -r "$f" ] || continue
            temp=$(( $(<"$f")/1000 ))
            hwname=$(cat "$hw"/name 2>/dev/null || echo "hwmon")
            echo "$hwname: $temp°C"
            return
        done
    done
}
get_governors() {
    [[ -r "${POLICIES[0]}/scaling_available_governors" ]] && cat "${POLICIES[0]}/scaling_available_governors"
}

# --- Profile Management ---
profile_file() { echo "$PROFILE_DIR/$1"; }
profile_exists() { [[ -f "$(profile_file "$1")" ]]; }
save_profile() {
    local name="$1"
    local file; file=$(profile_file "$name")
    {
        echo "# cpufreqctl profile: $name"
        for p in "${POLICIES[@]}"; do
            gov=$(< "$p"/scaling_governor)
            max=$(< "$p"/cpuinfo_max_freq)
            echo "$(basename "$p")|$gov|$max"
        done
    } > "$file"
    echo_and_log "Save profile" "profile '$name'" "Profile '$name' saved."
    [[ $2 == 'cli' ]] && echo "Profile '$name' saved." || true
}
load_profile() {
    local name="$1"
    local file; file=$(profile_file "$name")
    [[ -f "$file" ]] || { echo "No profile named '$name'"; return 1; }
    declare -gA GOVS
    declare -gA MAXS
    while IFS='|' read -r pol gov max; do
        GOVS["$pol"]="$gov"
        MAXS["$pol"]="$max"
    done < <(grep -v '^#' "$file")
    return 0
}
apply_profile() {
    load_profile "$1" || return 1
    for p in "${POLICIES[@]}"; do
        pol=$(basename "$p")
        if [[ -n "${GOVS[$pol]}" ]]; then
            out=$(echo "${GOVS[$pol]}" | sudo tee "$p"/scaling_governor 2>&1)
            echo_and_log "Set governor" "echo '${GOVS[$pol]}' | sudo tee $p/scaling_governor" "$out"
        fi
        if [[ -n "${MAXS[$pol]}" ]]; then
            out=$(echo "${MAXS[$pol]}" | sudo tee "$p"/scaling_max_freq 2>&1)
            echo_and_log "Set max freq" "echo '${MAXS[$pol]}' | sudo tee $p/scaling_max_freq" "$out"
        fi
    done
    echo_and_log "Apply profile" "profile '$1'" "Profile '$1' applied."
    [[ $2 == 'cli' ]] && echo "Profile '$1' applied." || true
}
delete_profile() {
    [[ "$1" == "$DEFAULT_PROFILE" ]] && { echo "Refusing to delete default profile."; return 1; }
    rm -f "$(profile_file "$1")" && echo_and_log "Delete profile" "profile '$1'" "Profile '$1' deleted."
}
list_profiles() {
    shopt -s nullglob
    for pf in "$PROFILE_DIR"/*; do
        name=$(basename "$pf")
        [[ "$name" == "$DEFAULT_PROFILE" ]] && tag=" (default)" || tag=""
        echo " - $name$tag"
    done
    shopt -u nullglob
}
set_default_profile() {
    local src="$1"
    local force="$2"
    if [[ "$src" == "$DEFAULT_PROFILE" ]]; then
        echo "'$src' is already the default profile."
        return 0
    fi
    if [[ -f "$(profile_file "$DEFAULT_PROFILE")" && "$force" != "--force" ]]; then
        echo -e "${YELLOW}Warning:${NC} This will overwrite the current default profile!"
        read -rp "${LEFT_PADDING}Are you sure you want to overwrite the default profile with '$src'? [y/N]: " ans
        [[ "${ans,,}" =~ ^y ]] || { echo "Aborted."; return 1; }
    fi
    cp "$(profile_file "$src")" "$(profile_file "$DEFAULT_PROFILE")" && echo_and_log "Set default profile" "cp $src $DEFAULT_PROFILE" "Set '$src' as default."
}

# --- Actions ---
declare -a POLICIES
get_policies() {
    mapfile -t POLICIES < <(find /sys/devices/system/cpu -maxdepth 2 -type d -name 'policy*' 2>/dev/null | sort -V)
}
set_governor() {
    for p in "${POLICIES[@]}"; do 
        out=$(echo "$1" | sudo tee "$p"/scaling_governor 2>&1)
        echo_and_log "Set governor" "echo '$1' | sudo tee $p/scaling_governor" "$out"
    done
    [[ $2 == 'cli' ]] && echo "Governor set to '$1'." || true
}
set_cap() {
    local percent="$1"
    [[ $percent =~ ^[0-9]+$ ]] && (( percent >= 20 && percent <= 100 )) || { echo "Invalid percent (20-100)"; return 1; }
    local max target
    max=$(< "${POLICIES[0]}/cpuinfo_max_freq")
    target=$(( max * percent / 100 ))
    for p in "${POLICIES[@]}"; do 
        out=$(echo "$target" | sudo tee "$p"/scaling_max_freq 2>&1)
        echo_and_log "Set cap" "echo '$target' | sudo tee $p/scaling_max_freq" "$out"
    done
    [[ $2 == 'cli' ]] && echo "CPU capped to $percent% ($((target/1000)) MHz)." || true
}

# --- CLI ---
cli_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]
Profile management:
  -l, --list                  List all saved profiles
  -a, --apply <profile>       Apply (load) a profile
  -s, --save <profile>        Save current settings as a profile
  -d, --delete <profile>      Delete a profile
      --set-default <profile> Set a profile as the default (overwrites the 'default' profile file)
                              (will prompt for confirmation unless --force is given)
Status and info:
  -S, --status                Show current CPU status
  -G, --governors             List available CPU governors
Other:
      --cap <percent>         Cap CPU max frequency to percent
      --set-governor <gov>    Set CPU governor
  -h, --help                  Show this help message
EOF
}
parse_cli() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--list) list_profiles; exit 0;;
            -a|--apply) apply_profile "$2" cli; exit 0;;
            -s|--save) save_profile "$2" cli; exit 0;;
            -d|--delete) delete_profile "$2"; exit 0;;
            --set-default)
                if [[ -n "$2" ]]; then
                    set_default_profile "$2" "$3"; exit 0
                else
                    echo "Error: --set-default requires a profile name"; exit 1
                fi
                ;;
            -S|--status)
                vendor=$(awk -F: '/vendor_id/ {print $2; exit}' /proc/cpuinfo | xargs)
                model=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | xargs)
                cores=$(get_cores)
                threads=$(get_threads)
                gov=$(<"${POLICIES[0]}/scaling_governor")
                cap=$(< "${POLICIES[0]}/scaling_max_freq")
                max=$(< "${POLICIES[0]}/cpuinfo_max_freq")
                capmhz=$((cap/1000)); maxmhz=$((max/1000)); pct=$(( cap * 100 / max ))
                temp=$(get_simple_cpu_temp)
                echo "CPU Status:"
                echo "  Vendor   : $vendor"
                echo "  Model    : $model"
                echo "  Cores    : $cores"
                echo "  Threads  : $threads"
                echo "  Governor : $gov"
                echo "  Max Freq : $capmhz MHz ($pct% of max)"
                [[ -n "$temp" ]] && echo "  Temp     : $temp"
                exit 0;;
            -G|--governors) get_governors; exit 0;;
            --cap) set_cap "$2" cli; exit 0;;
            --set-governor) set_governor "$2" cli; exit 0;;
            -h|--help) cli_usage; exit 0;;
            *) echo "Unknown option: $1"; cli_usage; exit 1;;
        esac
    done
}

# --- Interactive UI ---
show_simple_status() {
    display_header
    echo -e "${BLUE}\033[1m1) Show CPU status${NC}" | pad
    echo | pad
    vendor=$(awk -F: '/vendor_id/ {print $2; exit}' /proc/cpuinfo | xargs)
    model=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | xargs)
    cores=$(get_cores)
    threads=$(get_threads)
    gov=$(<"${POLICIES[0]}/scaling_governor")
    cap=$(< "${POLICIES[0]}/scaling_max_freq")
    max=$(< "${POLICIES[0]}/cpuinfo_max_freq")
    capmhz=$((cap/1000)); maxmhz=$((max/1000)); pct=$(( cap * 100 / max ))
    cpu_temp=$(get_simple_cpu_temp)
    echo -e "${BLUE}CPU Status:${NC}" | pad
    echo -e "  ${YELLOW}Vendor   :${NC} $vendor" | pad
    echo -e "  ${YELLOW}Model    :${NC} $model" | pad
    echo -e "  ${YELLOW}Cores    :${NC} $cores" | pad
    echo -e "  ${YELLOW}Threads  :${NC} $threads" | pad
    echo -e "  ${YELLOW}Governor :${NC} ${GREEN}$gov${NC}" | pad
    echo -e "  ${YELLOW}Max Freq :${NC} ${GREEN}$capmhz MHz ($pct%% of max)${NC}" | pad
    if [[ -n "$cpu_temp" ]]; then
        echo -e "  ${YELLOW}Temp     :${NC} $cpu_temp" | pad
    fi
    echo | pad
    read -rp "${LEFT_PADDING}Press Enter to return to main menu..." x
    [[ "${x,,}" == "exit" ]] && echo "Bye!" | pad && exit 0
}

set_governor_all() {
    display_header
    echo -e "${BLUE}\033[1m2) Set CPU governor${NC}" | pad
    echo | pad
    GOVS=()
    if [[ -r "${POLICIES[0]}/scaling_available_governors" ]]; then
        read -ra GOVS < "${POLICIES[0]}/scaling_available_governors"
    fi
    gov_now=$(<"${POLICIES[0]}/scaling_governor")
    echo -e "${BLUE}Current governor:${NC} ${GREEN}$gov_now${NC}" | pad
    echo | pad
    if ((${#GOVS[@]}==0)); then
        echo "No governors available on this system." | pad
        read -rp "${LEFT_PADDING}Press Enter to return to main menu..." x
        [[ "${x,,}" == "exit" ]] && echo "Bye!" | pad && exit 0
        return
    fi
    echo "Choose CPU governor:" | pad
    for i in "${!GOVS[@]}"; do 
        if [[ "${GOVS[i]}" == "$gov_now" ]]; then
            printf "  %d) ${GREEN}%s${NC}\n" $((i+1)) "${GOVS[i]}" | pad
        else
            printf "  %d) %s\n" $((i+1)) "${GOVS[i]}" | pad
        fi
    done
    echo "  0) Back to main menu" | pad
    read -rp "${LEFT_PADDING}Select: " idx
    [[ "${idx,,}" == "exit" ]] && echo "Bye!" | pad && exit 0
    case "$idx" in
        exit) echo "Goodbye!" | pad; exit 0 ;;
        0) return ;;
    esac
    if [[ $idx =~ ^[0-9]+$ ]] && [ $idx -ge 1 ] && [ $idx -le ${#GOVS[@]} ]; then
        set_governor "${GOVS[$((idx-1))]}"
    else
        echo "Invalid choice" | pad
    fi
    read -rp "${LEFT_PADDING}Press Enter to return to main menu..." x
    [[ "${x,,}" == "exit" ]] && echo "Bye!" | pad && exit 0
}

cap_to_percent_all() {
    display_header
    echo -e "${BLUE}\033[1m3) Cap CPU max frequency${NC}" | pad
    echo | pad
    cap=$(< "${POLICIES[0]}/scaling_max_freq")
    max=$(< "${POLICIES[0]}/cpuinfo_max_freq")
    capmhz=$((cap/1000))
    maxmhz=$((max/1000))
    pct=$(( cap * 100 / max ))
    echo -e "${YELLOW}Current CPU max frequency:${NC}" | pad
    printf "  ${GREEN}%d MHz${NC} (${GREEN}%d%%${NC} of max)\n" "$capmhz" "$pct" | pad
    echo | pad
    echo "  0) Back to main menu" | pad
    echo | pad
    read -rp "${LEFT_PADDING}Enter cap percentage [20-100]: " npct
    [[ "${npct,,}" == "exit" ]] && echo "Bye!" | pad && exit 0
    case "$npct" in
        exit) echo "Goodbye!" | pad; exit 0 ;;
        0) return ;;
    esac
    set_cap "$npct"
    read -rp "${LEFT_PADDING}Press Enter to return to main menu..." x
    [[ "${x,,}" == "exit" ]] && echo "Bye!" | pad && exit 0
}

show_advanced_stats() {
    display_header
    echo -e "${BLUE}\033[1m4) Geek stats/debug info${NC}" | pad
    echo | pad
    vendor=$(awk -F: '/vendor_id/ {print $2; exit}' /proc/cpuinfo | xargs)
    model=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | xargs)
    cores=$(get_cores)
    threads=$(get_threads)
    echo -e "${BLUE}Geek/Debug Info: CPU Policies, Governors, Caps, and Sensors${NC}" | pad
    echo -e "${BLUE}(A policy is a group of CPUs that must share settings. Most users only need to set everything globally.)${NC}" | pad
    printf "  ${YELLOW}Vendor   :${NC} %s\n" "$vendor" | pad
    printf "  ${YELLOW}Model    :${NC} %s\n" "$model" | pad
    printf "  ${YELLOW}Cores    :${NC} %s\n" "$cores" | pad
    printf "  ${YELLOW}Threads  :${NC} %s\n" "$threads" | pad
    echo | pad
    echo -e "${GREEN}--- Policies (CPU groups) ---${NC}" | pad
    for p in "${POLICIES[@]}"; do
        name=$(basename "$p")
        gov=$(< "$p"/scaling_governor)
        max=$(< "$p"/cpuinfo_max_freq)
        cap=$(< "$p"/scaling_max_freq)
        maxmhz=$((max/1000))
        capmhz=$((cap/1000))
        pct=$(awk "BEGIN { printf \"%d\", ($cap * 100 / $max) + 0.5 }")
        printf "  ${YELLOW}%-8s${NC}  Gov: ${GREEN}%-12s${NC}  Cap: ${YELLOW}%4d MHz${NC} (${GREEN}%d%%${NC} of ${YELLOW}%d MHz${NC} max)\n" "$name" "$gov" "$capmhz" "$pct" "$maxmhz" | pad
    done
    echo | pad
    echo -e "${GREEN}--- Sensors (hwmon) ---${NC}" | pad
    for hw in /sys/class/hwmon/hwmon*; do
        hwname=$(cat "$hw"/name 2>/dev/null || basename "$hw")
        for f in "$hw"/temp*_input; do [ -r "$f" ] || continue
            temp=$(( $(<"$f")/1000 ))
            printf "  ${YELLOW}%-12s${NC} : ${GREEN}%3d°C${NC}\n" "$hwname" "$temp" | pad
        done
    done
    echo | pad
    read -rp "${LEFT_PADDING}Press Enter to return to main menu..." x
    [[ "${x,,}" == "exit" ]] && echo "Bye!" | pad && exit 0
}

profiles_menu() {
    while true; do
        display_header
        echo -e "${BLUE}\033[1m5) Profiles menu${NC}" | pad
        echo | pad
        echo -e "${BLUE}Available profiles:${NC}" | pad
        shopt -s nullglob
        current_profile=""
        for pf in "$PROFILE_DIR"/*; do
            name=$(basename "$pf")
            match=true
            while IFS='|' read -r pol gov max; do
                pdir="/sys/devices/system/cpu/cpu*/cpufreq/$pol"
                for p in ${POLICIES[@]}; do
                    if [[ $(basename "$p") == "$pol" ]]; then
                        cur_gov=$(< "$p/scaling_governor")
                        cur_max=$(< "$p/cpuinfo_max_freq")
                        [[ "$cur_gov" == "$gov" && "$cur_max" == "$max" ]] || match=false
                    fi
                done
            done < <(grep -v '^#' "$pf")
            if $match; then
                current_profile="$name"
            fi
        done
        for pf in "$PROFILE_DIR"/*; do
            name=$(basename "$pf")
            if [[ "$name" == "$current_profile" ]]; then
                echo -e "  - ${GREEN}$name (current)${NC}" | pad
            else
                echo -e "  - $name" | pad
            fi
        done
        shopt -u nullglob
        echo | pad
        echo "  1) Save current as new profile" | pad
        echo "  2) Apply (set) a profile" | pad
        echo "  3) Delete a profile" | pad
        echo "  4) Save current as default profile" | pad
        echo "  0) Back to main menu" | pad
        echo | pad
        read -rp "${LEFT_PADDING}Select: " c
        [[ "${c,,}" == "exit" ]] && echo "Bye!" | pad && exit 0
        case "$c" in
            1)
                read -rp "${LEFT_PADDING}Enter profile name to save (a-z, 0-9, _, -): " pname
                [[ "${pname,,}" == "exit" ]] && echo "Bye!" | pad && exit 0
                [[ -z "$pname" ]] && echo "Profile name required." | pad && continue
                if profile_exists "$pname"; then
                    echo "Profile '$pname' already exists. Use 'Overwrite profile' to update it." | pad
                    continue
                fi
                save_profile "$pname"
                ;;
            2)
                echo -e "${YELLOW}Type the profile name from the list above to apply:${NC}" | pad
                read -rp "${LEFT_PADDING}Enter profile name to apply: " pname
                [[ "${pname,,}" == "exit" ]] && echo "Bye!" | pad && exit 0
                if ! profile_exists "$pname"; then
                    echo "No profile named '$pname' found." | pad
                    continue
                fi
                apply_profile "$pname"
                ;;
            3)
                echo -e "${YELLOW}Type the profile name from the list above to delete:${NC}" | pad
                read -rp "${LEFT_PADDING}Enter profile name to delete: " pname
                [[ "${pname,,}" == "exit" ]] && echo "Bye!" | pad && exit 0
                delete_profile "$pname"
                ;;
            4)
                echo -e "${YELLOW}Warning:${NC} This will overwrite the current default profile!" | pad
                read -rp "${LEFT_PADDING}Are you sure you want to overwrite the default profile? [y/N]: " ans
                [[ "${ans,,}" =~ ^y ]] || { echo "Aborted." | pad; continue; }
                save_profile "$DEFAULT_PROFILE"
                echo_and_log "Set default profile" "save current as $DEFAULT_PROFILE" "Current settings saved as default profile."
                ;;
            0)
                break
                ;;
            *)
                echo "Invalid choice." | pad
                ;;
        esac
    done
}

main_menu() {
    while true; do
        display_header
        echo -e "${BLUE}\033[1mMain Menu${NC}" | pad
        echo | pad
        echo -e "\033[1m1) Show CPU status${NC}" | pad
        echo -e "\033[1m2) Set CPU governor${NC}" | pad
        echo -e "\033[1m3) Cap CPU max frequency${NC}" | pad
        echo -e "\033[1m4) Geek stats/debug info${NC}" | pad
        echo -e "\033[1m5) Profiles menu${NC}" | pad
        echo -e "\033[1m0) Exit${NC}" | pad
        echo | pad
        read -rp "${LEFT_PADDING}Select: " c
        [[ "${c,,}" == "exit" ]] && echo "Bye!" | pad && exit 0
        case "$c" in
            1) show_simple_status ;;
            2) set_governor_all ;;
            3) cap_to_percent_all ;;
            4) show_advanced_stats ;;
            5) profiles_menu ;;
            0|exit) echo "Bye!" | pad; exit 0 ;;
            *) 
                echo "Invalid choice" | pad
                sleep 1
                ;;
        esac
    done
}

# --- Main Entry ---
mkdir -p "$PROFILE_DIR"
get_policies
if [[ $# -gt 0 ]]; then
    check_system || exit 1
    parse_cli "$@"
    exit
fi
check_system || { echo "System not compatible."; exit 1; }
log_action "Started cpufreqctl-clean"
main_menu 