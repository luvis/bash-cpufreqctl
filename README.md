# cpufreqctl

cpufreqctl is an interactive, user-friendly CPU governor and frequency control tool for Linux systems using the kernel's `cpufreq` interface via sysfs. It lets you monitor and control CPU scaling, governors, and frequency caps from the terminal. The tool was developed on openSUSE but should work on most modern Linux distributions. Advanced details and sensor readouts are available for deeper analysis.

**Disclaimer:** Use at your own risk. While cpufreqctl does not make changes unless you explicitly confirm them, modifying CPU settings can impact system stability and performance. No guarantee is provided for compatibility or safety on all systems.



## Features

* View CPU details, scaling status, and temperature (auto-detected for most CPUs)
* Set the CPU governor (e.g. performance, powersave)
* Cap the maximum CPU frequency as a percentage (minimum enforced)
* Save and restore your system’s original settings (defaults stored per user)
* Advanced stats and sensor info for power users ("Geek menu")



## How does it work?

cpufreqctl interacts directly with Linux sysfs (`/sys/devices/system/cpu/cpufreq/...`) and standard tools like `awk`, `sudo`, and `bash`. It reads available governors, scaling frequencies, and sensor data from the kernel, making no assumptions about your hardware or distribution. Actions requiring changes (like setting a governor) use `sudo` for safety but the menu can be used as a normal user.



## Requirements

* Bash (any recent version)
* Linux with kernel cpufreq/sysfs interface (most desktop/laptop distros)
* sudo (for system changes)
* awk
* Sensors (for temperature readout; works best with coretemp, k10temp, etc.)



## Installation

To install system-wide (recommended), run:

```bash
./install.sh
```

This will copy `cpufreqctl.sh` to `/usr/local/bin/cpufreqctl` and make it executable. You can then run `cpufreqctl` from anywhere.

If you prefer not to install, you can run locally without installation:

```bash
./cpufreqctl.sh
```



## Usage

Just run:

```bash
cpufreqctl
```

### Menu options

1. **Show CPU status**

   * Shows vendor, model, cores, threads, current governor, current frequency cap, and live CPU temperature.
2. **Set CPU governor**

   * Choose from available governors. Applies your choice to all CPU cores.
3. **Cap CPU max frequency**

   * Cap the max CPU speed as a percent of the hardware maximum (minimum allowed is 20%).
4. **Geek stats/debug info**

   * Shows all policy groups, governors, caps, and all temp sensors for deeper analysis.
5. **Defaults menu**

   * Save current state as defaults
   * View saved defaults
   * Overwrite saved defaults



## Restoring defaults

The restore feature is designed to let you revert to a previously saved configuration using the defaults menu. It works by loading settings from the `~/.cpufreqctl.defaults` file and applying them to your system.

For restoration to work, a valid defaults file must exist in your home directory—this file is only created when you use the save command (option 5 > save). Restoring may not succeed if the file is missing, has been changed, or is incompatible with your current system or kernel.



## Notes

* **You do not need to run the whole tool as root**, but you will be prompted for sudo when changing system settings.
* If you do not save defaults before making changes, you cannot "restore factory settings"—you can only restore what you have saved. Always use the Defaults menu to save your starting config!
* All actions affect every CPU core/policy by default. Advanced per-policy or per-core settings are shown only in the geek/debug stats.
* CPU temperature is auto-detected and will always prioritize the real CPU sensor (e.g. k10temp/coretemp), falling back to the first available temp sensor if needed.



## License

MIT



## Author

* David Campbell



For suggestions, improvements, or issues, open a pull request or contact David.

