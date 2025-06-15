#!/usr/bin/env bash
set -e

SRC="cpufreqctl.sh"
DST="/usr/local/bin/cpufreqctl"

echo "=== cpufreqctl Installation ==="
echo "This will install cpufreqctl system-wide to $DST"
read -rp "Continue and use sudo if needed? [Y/n] " ans
[[ "$ans" =~ ^[Nn]$ ]] && echo "Installation aborted." && exit 1

if [[ ! -f "$SRC" ]]; then
  echo "Error: $SRC not found in the current directory."
  exit 1
fi

# Copy and set permissions
echo "Installing cpufreqctl to $DST..."
sudo cp "$SRC" "$DST"
sudo chmod +x "$DST"
echo "✓ Binary installed successfully"

# Verify installation
if [[ ! -x "$DST" ]]; then
  echo "Error: Installation failed. $DST is not executable."
  exit 1
fi

# Check if /usr/local/bin is in system PATH
echo "Checking system PATH configuration..."
if grep -q ":/usr/local/bin:" /etc/profile /etc/environment 2>/dev/null; then
  echo "✓ /usr/local/bin is already in system PATH"
  echo "✓ Installation complete!"
  echo "You can now run cpufreqctl from anywhere."
  exit 0
fi

# Detect current shell
CURRENT_SHELL=$(basename "$SHELL")
echo "Detected shell: $CURRENT_SHELL"

# PATH check and shell-specific configuration
case ":$PATH:" in
  *":/usr/local/bin:"*)
    echo "✓ /usr/local/bin is already in your PATH"
    echo "✓ Installation complete!"
    echo "You can now run cpufreqctl from anywhere."
    ;;
  *)
    echo "! /usr/local/bin is not in your PATH"
    echo "Adding to your shell configuration..."
    
    # Primary configuration in ~/.profile
    PROFILE_FILE="$HOME/.profile"
    PATH_LINE='export PATH="/usr/local/bin:$PATH"'

    # Create or update .profile (even for fish, for future compatibility)
    if [[ ! -f "$PROFILE_FILE" ]]; then
      echo "Creating new $PROFILE_FILE for system compatibility..."
      cat > "$PROFILE_FILE" << 'EOF'
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login exists.
# See /usr/share/doc/bash/examples/startup-files for examples.
# The files are located in the bash-doc package.

# The default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private local/bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

EOF
      # Add our PATH configuration
      echo "$PATH_LINE" >> "$PROFILE_FILE"
      # Set proper permissions
      chmod 644 "$PROFILE_FILE"
      echo "✓ Created new $PROFILE_FILE with default configuration"
      echo "  (This file will be used if you switch to bash/zsh/etc. in the future)"
    elif ! grep -q "/usr/local/bin" "$PROFILE_FILE"; then
      echo "$PATH_LINE" >> "$PROFILE_FILE"
      echo "✓ Added PATH configuration to existing $PROFILE_FILE"
    else
      echo "✓ PATH configuration already exists in $PROFILE_FILE"
    fi

    # Shell-specific configuration to ensure .profile is sourced
    case "$CURRENT_SHELL" in
      "bash")
        BASHRC="$HOME/.bashrc"
        if [[ ! -f "$BASHRC" ]] || ! grep -q "source ~/.profile" "$BASHRC"; then
          echo 'if [ -f ~/.profile ]; then source ~/.profile; fi' >> "$BASHRC"
          echo "✓ Updated $BASHRC to source .profile"
        fi
        ;;
      "zsh")
        ZSHRC="$HOME/.zshrc"
        if [[ ! -f "$ZSHRC" ]] || ! grep -q "source ~/.profile" "$ZSHRC"; then
          echo 'if [ -f ~/.profile ]; then source ~/.profile; fi' >> "$ZSHRC"
          echo "✓ Updated $ZSHRC to source .profile"
        fi
        ;;
      "fish")
        # Fish doesn't use .profile, so we need to add the PATH directly
        FISH_CONFIG="$HOME/.config/fish/config.fish"
        if [[ ! -f "$FISH_CONFIG" ]]; then
          mkdir -p "$(dirname "$FISH_CONFIG")"
          touch "$FISH_CONFIG"
        fi
        if ! grep -q "/usr/local/bin" "$FISH_CONFIG"; then
          echo 'set -gx PATH /usr/local/bin $PATH' >> "$FISH_CONFIG"
          echo "✓ Added PATH configuration to $FISH_CONFIG"
          echo "  (Note: .profile was also created for future shell compatibility)"
        fi
        ;;
      "ksh")
        KSHRC="$HOME/.kshrc"
        if [[ ! -f "$KSHRC" ]] || ! grep -q "source ~/.profile" "$KSHRC"; then
          echo 'if [ -f ~/.profile ]; then . ~/.profile; fi' >> "$KSHRC"
          echo "✓ Updated $KSHRC to source .profile"
        fi
        ;;
      "tcsh")
        TCSHRC="$HOME/.tcshrc"
        if [[ ! -f "$TCSHRC" ]] || ! grep -q "source ~/.profile" "$TCSHRC"; then
          echo 'if ( -f ~/.profile ) source ~/.profile' >> "$TCSHRC"
          echo "✓ Updated $TCSHRC to source .profile"
        fi
        ;;
      "dash"|"ash")
        # These shells already use .profile by default
        echo "✓ Using default .profile configuration"
        ;;
      *)
        echo "! Unrecognized shell: $CURRENT_SHELL"
        echo "Please ensure ~/.profile is sourced in your shell configuration."
        echo "Common configuration files:"
        echo "  bash: ~/.bashrc"
        echo "  zsh:  ~/.zshrc"
        echo "  fish: ~/.config/fish/config.fish"
        echo "  ksh:  ~/.kshrc"
        echo "  tcsh: ~/.tcshrc"
        echo "  dash/ash: ~/.profile"
        exit 1
        ;;
    esac

    # Verify the configuration
    echo "Verifying installation..."
    if command -v cpufreqctl >/dev/null 2>&1; then
      echo "✓ Installation complete!"
      echo "You can now run cpufreqctl from anywhere."
    else
      echo "! Installation complete, but cpufreqctl is not yet in your PATH."
      echo "Please restart your shell or run: source ~/.profile"
    fi
    ;;
esac
