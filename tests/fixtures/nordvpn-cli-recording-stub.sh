#!/bin/sh
# Test-only NordVPN CLI substitute. Never invokes the real NordVPN client.
printf '%s\0' "$@" >> "${QR04N_ARGV_LOG:?QR04N_ARGV_LOG is required}"
printf '\n' >> "$QR04N_ARGV_LOG"
case "${1-}" in
  status)
    if [ "${QR04N_STATUS_MODE-}" = "unavailable" ]; then printf 'stub unavailable\n' >&2; exit 42; fi
    printf 'Status: Connected\nCountry: Testland\nServer: test.example\n'; exit 0 ;;
  settings) printf 'Firewall: enabled\nKill Switch: disabled\nThreat Protection Lite: disabled\nAuto-connect: enabled\nTechnology: NordLynx\nProtocol: UDP\n'; exit 0 ;;
  connect|disconnect|pause|set) sleep 0.15; exit 0 ;;
  *) printf 'refused argv\n' >&2; exit 86 ;;
esac
