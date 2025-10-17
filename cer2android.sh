#!/usr/bin/env bash

printf "%b\n" "\
                _   ___                 _           _     _ 
               | | |__ \               | |         (_)   | |
   ___ ___ _ __| |_   ) |__ _ _ __   __| |_ __ ___  _  __| |
  / __/ _ \ '__| __| / // _\` | '_ \ / _\` | '__/ _ \| |/ _\` |
 | (_|  __/ |  | |_ / /| (_| | | | | (_| | | | (_) | | (_| |
  \___\___|_|   \__|____\__,_|_| |_|\__,_|_|  \___/|_|\__,_|
"

set -euo pipefail

file=""
device=""

while getopts "f:d:" opt; do
  case "$opt" in
    f) file=$OPTARG ;;
    d) device=$OPTARG ;;
    *) printf 'Usage: %s -f <file> -d <device>\n' "$0" >&2; exit 1 ;;
  esac
done

if [ -z "$file" ] || [ -z "$device" ]; then
  printf 'Error: Missing required arguments.\n' >&2
  printf 'Usage: %s -f <file> -d <device>\n' "$0" >&2
  printf '-f : BurpSuite certificate in .der format\n' >&2
  printf '-d : Device identifier (IP:PORT or emulator ID)\n' >&2
  exit 1
fi

# Enable colors only when stdout is a terminal
if [[ -t 1 ]]; then
  BLUE=$'\033[34m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  RED=$'\033[31m'
  RESET=$'\033[0m'
else
  BLUE=''
  GREEN=''
  YELLOW=''
  RED=''
  RESET=''
fi

printf '%b Converting .der to .pem format...\n' "${BLUE}[*]${RESET}"
openssl x509 -inform DER -in "$file" -out ./burp.pem

certificate_hash=$(openssl x509 -inform PEM -subject_hash_old -in ./burp.pem | head -1)
certificate_name="${certificate_hash}.0"

printf '%b Renaming burp.pem to %s...\n' "${BLUE}[*]${RESET}" "$certificate_name"
mv ./burp.pem "$certificate_name"

printf '%b Pushing %s to Android device...\n' "${BLUE}[*]${RESET}" "$certificate_name"
adb -s "$device" push "$certificate_name" /sdcard/
rm -rf $certificate_name

printf '%b Remounting /system as read-write...\n' "${BLUE}[*]${RESET}"
device_protection=$(adb -s "$device" shell cat /proc/mounts | grep system | head -1 | awk '{print $1, $2}')
adb -s "$device" shell mount -o rw,remount $device_protection

printf '%b Installing BurpSuite certificate to system store...\n' "${BLUE}[*]${RESET}"
adb -s "$device" shell mv /sdcard/"$certificate_name" /etc/security/cacerts/

printf '%b Setting proper permissions for the certificate...\n' "${BLUE}[*]${RESET}"
adb -s "$device" shell chown root:root /etc/security/cacerts/"$certificate_name"
adb -s "$device" shell chmod 644 /etc/security/cacerts/"$certificate_name"

printf '%b Certificate successfully installed to system store!\n' "${GREEN}[+]${RESET}"
printf '%b Please reboot the Android device for changes to take effect.\n' "${YELLOW}[!]${RESET}"
