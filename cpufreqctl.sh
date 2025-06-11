#!/usr/bin/env bash
# cpufreqctl — Interactive CPU Power Tool
# Simplified for normal users. Advanced stats for geeks/debugging.
# Type 'exit' anytime to quit at any prompt

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
DEFAULTS_FILE="$HOME/.cpufreqctl.defaults"

mapfile -t POLICIES < <(find /sys/devices/system/cpu -maxdepth 2 -type d -name 'policy*' 2>/dev/null | sort -V)

get_cores() { awk '/^cpu cores/ {print $4; exit}' /proc/cpuinfo; }
get_threads() { nproc; }

# Try to get only the CPU temp, fallback to all
get_simple_cpu_temp() {
  # Priority 1: k10temp (AMD CPU)
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
  # Priority 2: coretemp (Intel CPU)
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
  # Priority 3: any label matching CPU-like keywords
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
  # fallback to first available temp if no CPU found
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


defaults_exist() {
  [[ -f "$DEFAULTS_FILE" ]]
}

save_defaults() {
  {
    echo "# cpufreqctl defaults file"
    echo "# This file is used by cpufreqctl to restore your saved CPU power settings."
    echo "# Do not delete unless you know what you’re doing!"
    echo "# Saved by cpufreqctl $(date '+%Y-%m-%d %H:%M:%S')"
    for p in "${POLICIES[@]}"; do
      gov=$(< "$p"/scaling_governor)
      max=$(< "$p"/cpuinfo_max_freq)
      echo "$(basename "$p")|$gov|$max"
    done
  } > "$DEFAULTS_FILE"
  echo -e "${GREEN}Defaults saved to $DEFAULTS_FILE${NC}"
  pause
}

load_defaults() {
  if ! defaults_exist; then
    echo -e "${RED}No defaults found. Use 'Save defaults' first.${NC}"
    pause
    return 1
  fi
  declare -gA ORIG_GOVS
  declare -gA ORIG_MAXS
  while IFS='|' read -r pol gov max; do
    ORIG_GOVS["$pol"]="$gov"
    ORIG_MAXS["$pol"]="$max"
  done < <(grep -v '^#' "$DEFAULTS_FILE")
  return 0
}

pause() { read -rp "Press Enter to return to the main menu..." _; }

show_simple_status() {
  echo
  echo -e "${BLUE}CPU Status:${NC}"
  vendor=$(awk -F: '/vendor_id/ {print $2; exit}' /proc/cpuinfo | xargs)
  model=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | xargs)
  cores=$(get_cores)
  threads=$(get_threads)
  printf "  ${YELLOW}Vendor   ${NC}: %s\n" "$vendor"
  printf "  ${YELLOW}Model    ${NC}: %s\n" "$model"
  printf "  ${YELLOW}Cores    ${NC}: %s\n" "$cores"
  printf "  ${YELLOW}Threads  ${NC}: %s\n" "$threads"
  gov="$(<"${POLICIES[0]}/scaling_governor")"
  echo
  printf "  ${YELLOW}Governor ${NC}: ${GREEN}%s${NC}\n" "$gov"
  cap=$(< "${POLICIES[0]}/scaling_max_freq")
  max=$(< "${POLICIES[0]}/cpuinfo_max_freq")
  capmhz=$((cap/1000))
  maxmhz=$((max/1000))
  pct=$(( cap * 100 / max ))
  printf "  ${YELLOW}Max Freq ${NC}: ${GREEN}%d MHz${NC} (${GREEN}%d%%${NC} of max)\n" "$capmhz" "$pct"
  cpu_temp=$(get_simple_cpu_temp)
  if [[ -n "$cpu_temp" ]]; then
    printf "  ${YELLOW}Temp     ${NC}: %s\n" "$cpu_temp"
  fi
  echo
  pause
}

find_governors() {
  #
  # Most systems expose available governors in the first policy's scaling_available_governors file.
  # This path is reliable for nearly all modern kernels and distributions.
  # As a fallback, we try to scan all policy and CPU directories for governors (future proofing).
  # Always split on whitespace, not lines.
  if [[ -r "${POLICIES[0]}/scaling_available_governors" ]]; then
    read -ra arr < "${POLICIES[0]}/scaling_available_governors"
    printf '%s\n' "${arr[@]}"
    return
  fi
  # Fallback universal scan (rarely needed; may not work everywhere due to permissions)
  declare -A GOV_SET
  for p in "${POLICIES[@]}"; do
    while read -ra arr < "$p/scaling_available_governors" 2>/dev/null; do
      for g in "${arr[@]}"; do GOV_SET["$g"]=1; done
    done
  done
  for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
    while read -ra arr < "$cpu/scaling_available_governors" 2>/dev/null; do
      for g in "${arr[@]}"; do GOV_SET["$g"]=1; done
    done
  done
  for g in "${!GOV_SET[@]}"; do echo "$g"; done
}

require_defaults() {
  if ! defaults_exist; then
    echo -e "${RED}No CPU defaults have been saved yet!${NC}"
    read -rp "Save current settings as defaults now? [Y/n]: " ans
    case "$ans" in
      [Nn]*) return 1;;
      *) save_defaults; return 0;;
    esac
  fi
  return 0
}

set_governor_all() {
  require_defaults || return
  mapfile -t GOVS < <(find_governors)
  echo
  if ((${#GOVS[@]}==0)); then
    echo -e "${RED}No governors available on this system.${NC}"
    pause
    return
  fi
  echo -e "${BLUE}Choose CPU governor:${NC}"
  for i in "${!GOVS[@]}"; do printf "  %d) %s\n" $((i+1)) "${GOVS[i]}"; done
  echo "  0) Back to main menu   exit) Quit"
  read -rp "Select: " idx
  case "$idx" in
    exit) echo "Goodbye!"; exit 0 ;;
    0) return ;;
  esac
  if [[ $idx =~ ^[0-9]+$ ]] && [ $idx -ge 1 ] && [ $idx -le ${#GOVS[@]} ]; then
    choice=${GOVS[$((idx-1))]}
    for p in "${POLICIES[@]}"; do echo "$choice" | sudo tee "$p"/scaling_governor >/dev/null; done
    echo -e "${GREEN}Governor set to '$choice'.${NC}"
  else
    echo -e "${RED}Invalid choice${NC}"
  fi
  pause
}

cap_to_percent_all() {
  require_defaults || return
  cap=$(< "${POLICIES[0]}/scaling_max_freq")
  max=$(< "${POLICIES[0]}/cpuinfo_max_freq")
  capmhz=$((cap/1000))
  maxmhz=$((max/1000))
  pct=$(( cap * 100 / max ))
  echo
  echo -e "${BLUE}Current CPU max frequency:${NC}"
  printf "  ${YELLOW}%d MHz${NC} (${GREEN}%d%%${NC} of max)\n" "$capmhz" "$pct"
  echo
  echo -e "${BLUE}Enter cap percentage [20-100]:${NC}"
  echo "  0) Back to main menu   exit) Quit"
  read -rp "Percent (20-100, 0=back, exit=quit): " npct
  case "$npct" in
    exit) echo "Goodbye!"; exit 0 ;;
    0) return ;;
  esac
  if [[ $npct =~ ^[0-9]+$ ]] && [ $npct -ge 20 ] && [ $npct -le 100 ]; then
  target=$(awk "BEGIN { printf \"%d\", ($max * $npct / 100) + 0.5 }")
  for p in "${POLICIES[@]}"; do echo "$target" | sudo tee "$p"/scaling_max_freq >/dev/null; done
  echo -e "${GREEN}CPU capped to $npct% ($((target/1000)) MHz).${NC}"
else
  echo -e "${RED}Invalid percentage. Minimum allowed is 20%.${NC}"
fi
pause

}

show_advanced_stats() {
  echo
  echo -e "${BLUE}Geek/Debug Info: CPU Policies, Governors, Caps, and Sensors${NC}"
  echo -e "(A policy is a group of CPUs that must share settings. Most users only need to set everything globally.)\n"
  vendor=$(awk -F: '/vendor_id/ {print $2; exit}' /proc/cpuinfo | xargs)
  model=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | xargs)
  cores=$(get_cores)
  threads=$(get_threads)
  printf "  ${YELLOW}Vendor   ${NC}: %s\n" "$vendor"
  printf "  ${YELLOW}Model    ${NC}: %s\n" "$model"
  printf "  ${YELLOW}Cores    ${NC}: %s\n" "$cores"
  printf "  ${YELLOW}Threads  ${NC}: %s\n" "$threads"
  echo
  echo -e "${GREEN}--- Policies (CPU groups) ---${NC}"
  for p in "${POLICIES[@]}"; do
    name=$(basename "$p")
    gov=$(< "$p"/scaling_governor)
    max=$(< "$p"/cpuinfo_max_freq)
    cap=$(< "$p"/scaling_max_freq)
    maxmhz=$((max/1000))
    capmhz=$((cap/1000))
    pct=$(awk "BEGIN { printf \"%d\", ($cap * 100 / $max) + 0.5 }")
    printf "  ${YELLOW}%-8s${NC}  Gov: ${GREEN}%-12s${NC}  Cap: ${GREEN}%4d MHz${NC} (%d%% of %d MHz max)\n" "$name" "$gov" "$capmhz" "$pct" "$maxmhz"
  done
  echo
  echo -e "${GREEN}--- Sensors (hwmon) ---${NC}"
  for hw in /sys/class/hwmon/hwmon*; do
    hwname=$(cat "$hw"/name 2>/dev/null || basename "$hw")
    for f in "$hw"/temp*_input; do [ -r "$f" ] || continue
      printf "  ${YELLOW}%-12s${NC} : %3d°C\n" "$hwname" "$(( $(<"$f")/1000 ))"
    done
  done
  echo
  pause
}

defaults_menu() {
  while true; do
    clear
    echo -e "${BLUE}CPU Frequency & Governor Tool — Defaults Menu${NC}\n"
    if ! defaults_exist; then
      echo -e "${YELLOW}No defaults saved yet.${NC}\n"
      echo "  1) Save current as defaults"
      echo "  0) Back to main menu"
      echo
      read -rp "Select: " c
      case "$c" in
        1) save_defaults; return ;;
        0) return ;;
        *) echo -e "${RED}Invalid choice${NC}"; pause ;;
      esac
    else
      echo -e "${GREEN}Defaults saved at:${NC} $DEFAULTS_FILE\n"
      echo "  1) View saved defaults"
      echo "  2) Overwrite with current values"
      echo "  0) Back to main menu"
      echo
      read -rp "Select: " c
      case "$c" in
        1)
          echo -e "\n${BLUE}Current saved defaults:${NC}"
          grep -v '^#' "$DEFAULTS_FILE" | while IFS='|' read -r pol gov max; do
            printf "  Policy: %-8s  Governor: %-12s  Max: %6.0f MHz\n" "$pol" "$gov" "$((max/1000))"
          done
          echo -e "\nFile: $DEFAULTS_FILE\n"
          pause ;;
        2) save_defaults ;;
        0) return ;;
        *) echo -e "${RED}Invalid choice${NC}"; pause ;;
      esac
    fi
  done
}

show_menu() {
  clear
  # RED WARNING if no defaults!
  if ! defaults_exist; then
    echo -e "${RED}⚠️  No CPU defaults saved! Select '6' to save your current settings for later restore.${NC}\n"
  fi
  echo -e "${BLUE}\nCPU Frequency & Governor Tool${NC}"
  echo "Set power mode & speed for your CPU."
  echo "Type 'exit' anytime to quit."
  echo
  echo "  1) Show CPU status"
  echo "  2) Set CPU governor"
  echo "  3) Cap CPU max frequency"
  echo "  4) Geek stats/debug info"
  echo "  5) Defaults menu"
}

while true; do
  show_menu
  read -rp "Select [1-5 or 'exit']: " opt
  case "$opt" in
    exit) echo "Goodbye!"; exit 0 ;;
    1) show_simple_status ;;
    2) set_governor_all ;;
    3) cap_to_percent_all ;;
    4) show_advanced_stats ;;
    5) defaults_menu ;;
    *) echo -e "${RED}Invalid choice${NC}"; pause ;;
  esac
done

