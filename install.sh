#!/usr/bin/env bash
set -e

SRC="cpufreqctl.sh"
DST="/usr/local/bin/cpufreqctl"

echo "This will install cpufreqctl system-wide to $DST"
read -rp "Continue and use sudo if needed? [Y/n] " ans
[[ "$ans" =~ ^[Nn]$ ]] && echo "Aborted." && exit 1

if [[ ! -f "$SRC" ]]; then
  echo "Error: $SRC not found in the current directory."
  exit 1
fi

# Copy and set permissions
sudo cp "$SRC" "$DST"
sudo chmod +x "$DST"
echo "Installed cpufreqctl to $DST"

# PATH check
case ":$PATH:" in
  *":/usr/local/bin:"*)
    echo "cpufreqctl is now ready. Run with: cpufreqctl"
    ;;
  *)
    echo "Warning: /usr/local/bin is not in your PATH."
    echo 'Add this line to your ~/.bashrc or ~/.zshrc:'
    echo '  export PATH="/usr/local/bin:$PATH"'
    ;;
esac
