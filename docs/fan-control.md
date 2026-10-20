# Fan control

Both CPU panels automatically select a group of CPU fan channels. There is no
channel selector: Silent, Standard, Performance, Full, manual ±5% steps and
Restore apply to the whole group. Explicit CPU fan labels are used where
available. For NCT6791, Rise resolves each `pwmN_temp_sel` through its
`tempN_label` and selects channels following CPUTIN or PECI Agent 0/1.
This identifies channels configured for CPU temperature, rather than assuming
header wiring from PWM numbering. It also retains channels with zero RPM.
On the current B365M Pro4-F, pwm1 and pwm2 both follow PECI Agent 0; pwm3–5
follow SYSTIN and are excluded. The existing FAN1 tachometer graph reads
fan2 independently. GPU controllers are excluded.

The [B365M Pro4-F manual](https://download.asrock.com/Manual/B365M%20Pro4-F.pdf)
(section 4.8) documents fan settings. Rise uses the four preset names, with its
own software curves, rather than changing UEFI settings or reproducing
undocumented ASRock curves. Silent, Standard and Performance start at 40%, 55%
and 70% through 40°C and rise linearly to 100% at 80°C. Full is always 100%.
Manual ranges from 40% to 100%; at 80°C every mode forces 100%. A readable CPU
temperature from coretemp, k10temp, zenpower or cpu_thermal is required.

Compatibility depends on the kernel driver exposing standard hwmon `pwmN`
and `pwmN_enable` attributes. No application can guarantee every motherboard.
Rise leaves PWM/DC wiring mode unchanged. Three-pin fans need appropriate DC
configuration in firmware. When the channels are read-only, selecting a profile opens the system's
administrator authentication dialog (`pkexec`). After authorization, Rise
uses `chown` to give the current user ownership of only the selected `pwmN`
and `pwmN_enable` files, discovers them again, and applies the requested
profile to the entire group. The Python controller continues as the desktop
user. Cancellation leaves control unchanged and reports an error in the panel.
This requires polkit, a running authentication agent and coreutils `chown`.
No manual channel selection or terminal permission command is needed.

Ownership lasts until the hwmon device is recreated, normally at reboot;
profile restoration does not revoke that access. Firmware CPU temperature
routing determines group membership, so changing that routing in UEFI can
change automatic selection. Use one controller per channel and disable
conflicting fan-control software before applying a mode.

The selected mode remains active when the CPU panel is closed and is shown
again when it is reopened. The helper keeps monitoring CPU temperature while
the panel is closed. Restore, normal shell exit, or helper SIGTERM restores
the saved PWM and enable mode. Missing
CPU temperature ends control and restores the saved state. SIGKILL or power
loss cannot execute restoration; firmware initializes control at boot. The
40% floor is a software limit, not a guarantee that every fan can spin at that
duty cycle. Confirm actual rotation when selecting a channel.

The helper uses Python 3 and emits JSON lines. Starting it with EOF performs
read-only discovery: `python3 scripts/rise-fan-control </dev/null`.
