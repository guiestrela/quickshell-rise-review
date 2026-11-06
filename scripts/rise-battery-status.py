#!/usr/bin/env python3
"""Read aggregate battery status plus safe health details for the Rise panel."""

import json
import os
import re
import subprocess
from pathlib import Path


DISPLAY_DEVICE = "/org/freedesktop/UPower/devices/DisplayDevice"


def upower(*args):
    env = dict(os.environ, LC_ALL="C")
    try:
        result = subprocess.run(
            ["upower", *args], check=False, capture_output=True, text=True,
            timeout=5, env=env,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return result.stdout if result.returncode == 0 else ""


def field(output, name):
    match = re.search(rf"^\s*{re.escape(name)}\s*:\s*(.*?)\s*$", output, re.M | re.I)
    return match.group(1) if match else ""


def number(output, name):
    value = field(output, name)
    match = re.match(r"([-+]?\d+(?:\.\d+)?)", value)
    return float(match.group(1)) if match else None


def duration(output, state):
    label = "Time to full" if state == "charging" else "Time left"
    key = "time to full" if state == "charging" else "time to empty"
    value = field(output, key)
    match = re.match(r"(\d+(?:\.\d+)?)\s*(seconds?|minutes?|hours?|days?)", value, re.I)
    if not match:
        return label, ""
    amount = float(match.group(1))
    unit = match.group(2).lower()
    seconds = amount * (1 if unit.startswith("second") else 60 if unit.startswith("minute")
                        else 3600 if unit.startswith("hour") else 86400)
    minutes = max(0, int(seconds // 60))
    hours, remainder = divmod(minutes, 60)
    return label, f"{hours}h {remainder}m" if hours else f"{remainder}m"


def main():
    output = {
        "schema": 1, "batteryId": "", "percentage": 0, "status": "unknown",
        "timeLabel": "Time left", "timeText": "", "powerRate": "",
        "sizeText": "", "healthText": "", "cycles": 0,
    }
    aggregate = upower("-i", DISPLAY_DEVICE)
    percentage = number(aggregate, "percentage")
    state = field(aggregate, "state").lower()
    if percentage is None or field(aggregate, "type").lower() != "battery":
        print(json.dumps(output, separators=(",", ":")))
        return

    output["percentage"] = max(0, min(100, round(percentage)))
    output["status"] = state or "unknown"
    output["timeLabel"], output["timeText"] = duration(aggregate, state)
    rate = number(aggregate, "energy-rate")
    if rate is not None:
        rate = abs(rate)
        output["powerRate"] = str(int(rate)) if rate.is_integer() else f"{rate:.1f}"

    devices = []
    for path in upower("-e").splitlines():
        path = path.strip()
        if "/battery_" in path.lower():
            info = upower("-i", path)
            if info and field(info, "type").lower() == "battery":
                battery_id = path.rsplit("/", 1)[-1]
                if battery_id.startswith("battery_"):
                    battery_id = battery_id[len("battery_"):]
                devices.append((battery_id, info))

    if len(devices) == 1:
        battery_id, info = devices[0]
        output["batteryId"] = battery_id
        cycles = number(info, "charge-cycles")
        if cycles is None or cycles < 0:
            sys_name = devices[0][0]
            try:
                cycles = float((Path("/sys/class/power_supply") / sys_name / "cycle_count").read_text().strip())
            except (OSError, ValueError):
                cycles = 0
        output["cycles"] = max(0, int(cycles))
    elif len(devices) > 1:
        output["batteryId"] = "Combined"

    energy_full = number(aggregate, "energy-full")
    if energy_full is None or energy_full <= 0:
        energy_full = sum(number(info, "energy-full") or 0 for _, info in devices)
    if energy_full > 0:
        output["sizeText"] = f"{energy_full:.0f} Wh"

    full_values = [number(info, "energy-full") for _, info in devices]
    design_values = [number(info, "energy-full-design") for _, info in devices]
    full_total = sum(value for value in full_values if value is not None)
    design_total = sum(value for value in design_values if value is not None)
    if full_total > 0 and design_total > 0:
        output["healthText"] = f"{min(100, round(full_total * 100 / design_total))}%"

    print(json.dumps(output, separators=(",", ":")))


if __name__ == "__main__":
    main()
