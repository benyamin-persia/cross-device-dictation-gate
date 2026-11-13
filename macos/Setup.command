#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
echo "Cross-Device Dictation Gate: Mac setup wizard"
echo "Deskflow and macOS Dictation must be configured first."
echo "Local IPv4 candidates:"
ifconfig | grep 'inet ' | grep -v '127.0.0.1' || true
read -r -p "Windows Deskflow server LAN IPv4: " WIN
read -r -p "Mac LAN IPv4: " MAC
if [[ -d "$HOME/Applications/Cross-Device Dictation Gate.app" ]]; then
  read -r -p "An existing package install was found. Back up and update it? [y/N] " UPDATE
  if [[ "$UPDATE" != "y" ]]; then echo "Cancelled"; exit 0; fi
  chmod +x ./install.sh
  ./install.sh --windows-ip "$WIN" --mac-ip "$MAC" --update
else
  chmod +x ./install.sh
  ./install.sh --windows-ip "$WIN" --mac-ip "$MAC"
fi
echo "Review and approve the macOS Accessibility / Input Monitoring permissions."
read -r -p "Press Enter to close this setup window."
