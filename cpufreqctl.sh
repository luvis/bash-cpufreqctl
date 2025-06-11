#!/usr/bin/env bash
# cpufreqctl — interactive CPU frequency & governor manager
# A universal tool for Linux kernels exposing CPU freq and governor in /sys
# Type 'exit' at any prompt to quit at any time

# ANSI color codes
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'

# defaults
DEFAULT_GOV="performance"
DEFAULT_MAX=$(< /sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq 2>/dev/null || echo 0)
# dynamically detect cpufreq policy directories
readarray -t POLICIES < <(find /sys/devices/system/cpu -maxdepth 2 -type d -name 'policy*' 2>/dev/null)

pause() { read -rp "Press Enter to return to main menu..." _; }

show_current_governor() {
  echo -e "${BLUE}Current governor per policy:${NC}"
  for p in "${POLICIES[@]}"; do
    gov=$(< "$p"/scaling_governor)
    echo -e "  ${YELLOW}$(basename "$p")${NC}: $gov"
  done
  pause
}

show_current_max_speed() {
  echo -e "${BLUE}CPU max speed info per policy:${NC}"
  for p in "${POLICIES[@]}"; do
    policy=$(basename "$p")
    max_avail=$(< "$p"/cpuinfo_max_freq)
    cap=$(< "$p"/scaling_max_freq)
    avail_mhz=$((max_avail/1000))
    cap_mhz=$((cap/1000))
    pct=$(( cap * 100 / max_avail ))
    echo -e "  ${YELLOW}$policy${NC}: $cap_mhz MHz ($pct% of $avail_mhz MHz max)"
  done
  pause
}

show_all_stats() {
  echo -e "${GREEN}=== Governors ===${NC}"
  # inline governors without pause
  for p in "${POLICIES[@]}"; do
    gov=$(< "$p"/scaling_governor)
    echo -e "  ${YELLOW}$(basename "$p")${NC}: $gov"
  done

  echo -e "
${GREEN}=== Max freq cap ===${NC}"
  # inline max speed info
  for p in "${POLICIES[@]}"; do
    policy=$(basename "$p")
    max_avail=$(< "$p"/cpuinfo_max_freq)
    cap=$(< "$p"/scaling_max_freq)
    avail_mhz=$((max_avail/1000))
    cap_mhz=$((cap/1000))
    pct=$(( cap * 100 / max_avail ))
    echo -e "  ${YELLOW}$policy${NC}: $cap_mhz MHz ($pct% of $avail_mhz MHz max)"
  done

  if [ "$DEFAULT_MAX" -gt 0 ]; then
    echo -e "
${GREEN}=== CPUinfo max freq ===${NC}"
    echo -e "  ${YELLOW}$(basename "${POLICIES[0]}")${NC}: $((DEFAULT_MAX/1000)) MHz"
  fi

  echo -e "
${GREEN}=== Temperatures ===${NC}"
  for hw in /sys/class/hwmon/hwmon*; do
    hwname=$(cat "$hw"/name 2>/dev/null || basename "$hw")
    for f in "$hw"/temp*_input; do
      [ -r "$f" ] || continue
      echo -e "  ${YELLOW}$hwname${NC}: $(( $(<"$f")/1000 ))°C"
    done
  done

  pause
}

set_governor() {
  GOVS=( $(< "${POLICIES[0]}/scaling_available_governors" 2>/dev/null) )
  echo -e "${BLUE}Choose a governor (number, 'x' cancel, 'exit' quit):${NC}"
  for i in "${!GOVS[@]}"; do
    printf "  %d) %s\n" $((i+1)) "${GOVS[i]}"
  done
  echo "  x) Cancel   exit) Quit"
  read -rp "Select: " idx
  case "$idx" in
    exit) echo "Exiting."; exit 0 ;; x) return ;;
  esac
  if [[ $idx =~ ^[0-9]+$ ]] && [ $idx -ge 1 ] && [ $idx -le ${#GOVS[@]} ]; then
    choice=${GOVS[$((idx-1))]}
    for p in "${POLICIES[@]}"; do
      echo "$choice" | sudo tee "$p"/scaling_governor >/dev/null
    done
    echo -e "${GREEN}Governor set to '$choice'${NC}"
  else
    echo -e "${RED}Invalid choice${NC}"
  fi
  pause
}

cap_to_percent() {
  echo -e "${BLUE}Enter cap percentage [1-100] ('x' cancel, 'exit' quit):${NC}"
  read -rp "Percent: " pct
  case "$pct" in
    exit) echo "Exiting."; exit 0 ;; x) return ;;
  esac
  if [[ $pct =~ ^[0-9]+$ ]] && [ $pct -ge 1 ] && [ $pct -le 100 ]; then
    max=$(< "${POLICIES[0]}/cpuinfo_max_freq")
    target=$(( max * pct / 100 ))
    for p in "${POLICIES[@]}"; do
      echo "$target" | sudo tee "$p"/scaling_max_freq >/dev/null
    done
    echo -e "${GREEN}Capped to $pct% → $((target/1000)) MHz${NC}"
  else
    echo -e "${RED}Invalid percentage${NC}"
  fi
  pause
}

restore_defaults() {
  read -rp "Restore governor='${DEFAULT_GOV}' and maxfreq=$((DEFAULT_MAX/1000)) MHz? [y/N]: " ans
  case "$ans" in
    [Yy]*)
      for p in "${POLICIES[@]}"; do
        echo "$DEFAULT_GOV" | sudo tee "$p"/scaling_governor >/dev/null
        echo "$DEFAULT_MAX" | sudo tee "$p"/scaling_max_freq >/dev/null
      done
      echo -e "${GREEN}Defaults restored.${NC}"
      ;;
    *) echo "Aborted." ;;
  esac
  pause
}

show_menu() {
  echo -e "${BLUE}\nCPU Frequency & Governor Tool${NC}"
  echo "A universal Bash utility to view and tweak CPU frequency governors and speed caps."
  echo "Type 'exit' anytime to quit."  
  echo
  echo " 1) Show current governor"
  echo " 2) Show CPU speed info"
  echo " 3) Show all CPU stats"
  echo " 4) Set governor"
  echo " 5) Cap max frequency to N%"
  echo " 6) Restore defaults"
}

# main loop
while true; do
  clear
  show_menu
  read -rp "Select [1-6 or 'exit']: " opt
  case "$opt" in
    exit) echo "Goodbye!"; exit 0;;
    1) show_current_governor;;
    2) show_current_max_speed;;
    3) show_all_stats;;
    4) set_governor;;
    5) cap_to_percent;;
    6) restore_defaults;;
    *) echo -e "${RED}Invalid choice${NC}"; pause;;
  esac
done

