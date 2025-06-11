# cpufreqctl

Interactive Bash utility for viewing and tweaking Linux CPU frequency governors and caps.

## Features

* View current governor per policy
* Show available max CPU speed and current cap (MHz + %)
* Display temperatures from hwmon
* Set any available governor interactively
* Cap max frequency to a chosen percentage of full speed
* Restore defaults (governor and max frequency)

## Installation

Copy the script into your PATH and make it executable:

```bash
sudo cp cpufreqctl.sh /usr/local/bin/cpufreqctl
sudo chmod +x /usr/local/bin/cpufreqctl
```

## Usage

Run the tool and pick an action by number or type `exit` anytime to quit:

```bash
cpufreqctl
```

The menu will guide you through:

1. Show current governor per CPU policy
2. Show CPU speed info (cap, available max, %)
3. Show all CPU stats (governors, caps, max freq, temps)
4. Set governor (choose from available)
5. Cap max frequency to N% of full speed
6. Restore defaults (performance + full speed)

## License

This project is licensed under the MIT License. See LICENSE for details.
