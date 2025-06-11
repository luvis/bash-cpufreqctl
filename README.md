# cpufreqctl

cpufreqctl is an interactive, user-friendly CPU governor and frequency control tool for Linux. It allows you to:

* View CPU details and current scaling status
* Set the CPU governor (e.g. performance, powersave)
* Cap the maximum CPU frequency as a percentage
* Save and restore your system’s original settings
* View advanced stats (for geeks)

## Key Features

* **Safe:** Never hardcodes system defaults. The first time you save defaults, they are stored in `~/.cpufreqctl.defaults` and can be restored at any time.
* **Universal:** Works on most modern Linux systems, supports Intel and AMD CPUs, and shows available governors and sensors.
* **User-focused:** All major actions apply to all cores by default—no jargon. Advanced info is available but never forced.

---

## Usage

Just run:

```bash
./cpufreqctl
```

### Menu options

1. **Show CPU status**

   * Shows vendor, model, cores, threads, current governor, current frequency cap, and live CPU temperature.
2. **Set CPU governor**

   * Choose from available governors. Applies your choice to all CPU cores.
3. **Cap CPU max frequency**

   * Cap the max CPU speed as a percent of the hardware maximum.
4. **Geek stats/debug info**

   * Shows all policy groups, governors, caps, and all temp sensors for deeper analysis.
5. **Defaults menu**

   * Save current state as defaults
   * View saved defaults
   * Overwrite saved defaults

---

## Restoring defaults

If you’ve saved defaults (option 5 > save), you can restore them any time from the defaults menu. Defaults are stored in your home directory as `~/.cpufreqctl.defaults` and only updated if you explicitly save/overwrite.

---

## Requirements

* Bash
* Linux with sysfs CPU frequency support
* sudo (for making changes)

---

## Notes

* **You do not need to run the whole tool as root**, but you will be prompted for sudo when changing system settings.
* If you do not save defaults before making changes, you cannot "restore factory settings"—you can only restore what you have saved. Always use the Defaults menu to save your starting config!
* All actions affect every CPU core/policy by default. Advanced per-policy or per-core settings are shown only in the geek/debug stats.
* CPU temperature is auto-detected and will always prioritize the real CPU sensor (e.g. k10temp/coretemp), falling back to the first available temp sensor if needed.

---

## License

MIT

---

## Author

* David Campbell

---

For suggestions, improvements, or issues, open a pull request or contact David.

