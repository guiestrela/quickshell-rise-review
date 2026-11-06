// Common behavior for variant-specific presentations.
.pragma library

function probeCommand() {
    return [
        "set -u",
        "is_physical() {",
        "  local dev=\"$1\" state carrier",
        "  [[ \"$dev\" =~ ^[[:alnum:]_.:-]+$ ]] || return 1",
        "  [[ -d \"/sys/class/net/$dev/wireless\" || -e \"/sys/class/net/$dev/device\" ]] || return 1",
        "  state=$(cat \"/sys/class/net/$dev/operstate\" 2>/dev/null || printf unknown)",
        "  [[ \"$state\" == up || \"$state\" == unknown ]] || return 1",
        "  if [[ -r \"/sys/class/net/$dev/carrier\" ]]; then carrier=$(cat \"/sys/class/net/$dev/carrier\" 2>/dev/null); [[ \"$carrier\" == 1 ]] || return 1; fi",
        "}",
        "IFACE=",
        "if command -v nmcli >/dev/null 2>&1; then",
        "  while IFS=: read -r dev type state; do",
        "    if [[ \"$type\" == wifi || \"$type\" == ethernet ]] && [[ \"$state\" == connected* ]] && is_physical \"$dev\"; then IFACE=$dev; break; fi",
        "  done < <(LC_ALL=C nmcli -t --escape no -f DEVICE,TYPE,STATE device status 2>/dev/null)",
        "fi",
        "if [[ -z \"$IFACE\" ]]; then",
        "  for route in \"$(ip -4 route get 1.1.1.1 2>/dev/null)\" \"$(ip -6 route get 2606:4700:4700::1111 2>/dev/null)\"; do",
        "    read -ra fields <<< \"$route\"; for ((i=0; i<${#fields[@]}; i++)); do if [[ \"${fields[i]}\" == dev && $((i+1)) -lt ${#fields[@]} ]] && is_physical \"${fields[i+1]}\"; then IFACE=${fields[i+1]}; break 2; fi; done",
        "  done",
        "fi",
        "if [[ -z \"$IFACE\" ]]; then",
        "  for family in -4 -6; do",
        "    while read -r route; do read -ra fields <<< \"$route\"; for ((i=0; i<${#fields[@]}; i++)); do if [[ \"${fields[i]}\" == dev && $((i+1)) -lt ${#fields[@]} ]] && is_physical \"${fields[i+1]}\"; then IFACE=${fields[i+1]}; break 3; fi; done; done < <(ip \"$family\" route show table main default 2>/dev/null)",
        "  done",
        "fi",
        "if [[ -z \"$IFACE\" ]]; then",
        "  for devpath in /sys/class/net/*; do dev=${devpath##*/}; if [[ -d \"$devpath/wireless\" ]] && is_physical \"$dev\"; then IFACE=$dev; break; fi; done",
        "  if [[ -z \"$IFACE\" ]]; then for devpath in /sys/class/net/*; do dev=${devpath##*/}; if is_physical \"$dev\"; then IFACE=$dev; break; fi; done; fi",
        "fi",
        "[[ -n \"$IFACE\" ]] || { echo NONE; exit 0; }",
        "RX=$(awk -v i=\"$IFACE:\" '$1==i{print $2}' /proc/net/dev 2>/dev/null); RX=${RX:-0}",
        "TX=$(awk -v i=\"$IFACE:\" '$1==i{print $10}' /proc/net/dev 2>/dev/null); TX=${TX:-0}",
        "if [[ -d \"/sys/class/net/$IFACE/wireless\" ]]; then",
        "  LINK=$(iw dev \"$IFACE\" link 2>/dev/null)",
        "  SSID=$(printf '%s\\n' \"$LINK\" | sed -n 's/^\\s*SSID: //p' | head -1)",
        "  if [[ \"$SSID\" =~ \\\\(x[0-9A-Fa-f]{2}|[0-7]{3}) ]]; then SSID=$(printf '%b' \"$SSID\"); fi",
        "  SIG=$(printf '%s\\n' \"$LINK\" | awk '/signal:/ {print int($2); exit}')",
        "  QUAL=$(awk -v s=\"${SIG:--110}\" 'BEGIN{q=int((s+110)*100/70);if(q<0)q=0;if(q>100)q=100;print q}')",
        "  printf 'WIFI\\t%s\\t%s\\t%s\\t%s\\n' \"$SSID\" \"$QUAL\" \"$RX\" \"$TX\"",
        "else",
        "  printf 'ETHERNET\\t%s\\t%s\\t%s\\n' \"$IFACE\" \"$RX\" \"$TX\"",
        "fi"
    ].join("\n")
}

function formatSpeed(riseOwner, riseEnvironment, bps) {
    var riseState = riseOwner;

        var mb = bps / 1048576
        var s = mb < 10 ? mb.toFixed(2) : mb.toFixed(1)
        return s.padStart(5) + "M"  // always 6 chars: " 0.00M" … "100.0M"
    }
