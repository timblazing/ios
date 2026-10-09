#!/usr/bin/env bash
# Installs a game IPA onto the USB-connected iPad with ideviceinstaller.
# A slimmed-down version of Legacy iOS Kit's App Management -> Install IPA (ideviceinstaller).
# Requires AppSync Unified on the device for the ad-hoc signed IPAs this repo builds.
set -uo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
bin="$root/tools/libimobiledevice/macos"
ipa="" game=""

if [[ $(uname -s) != Darwin ]]; then
  echo "install.sh runs on macOS only (it uses the bundled macOS libimobiledevice tools)." >&2
  exit 1
fi
chmod +x "$bin"/idevice* 2>/dev/null

bold=$'\e[1m' dim=$'\e[2m' green=$'\e[32m' red=$'\e[31m' yellow=$'\e[33m' reset=$'\e[0m'
say() { printf '%s\n' "$*"; }
warn() { printf '%s%s%s\n' "$yellow" "$*" "$reset"; }
fail() { printf '%s%s%s\n' "$red" "$*" "$reset"; }

# menu "Title" option... -> sets $choice to the selected option text and $choice_index to its index.
menu() {
  local title="$1"; shift
  local options=("$@") i reply
  while true; do
    printf '\n%s%s%s\n\n' "$bold" "$title" "$reset"
    for i in "${!options[@]}"; do printf '  %2d) %s\n' $((i + 1)) "${options[$i]}"; done
    printf '\nSelect an option: '
    read -r reply || exit 0
    if [[ $reply =~ ^[0-9]+$ ]] && ((reply >= 1 && reply <= ${#options[@]})); then
      choice_index=$((reply - 1))
      choice="${options[$choice_index]}"
      return
    fi
    warn "Enter a number from 1 to ${#options[@]}."
  done
}

ipa_info() {  # ipa_info file key -> value from the app's Info.plist
  unzip -p "$1" 'Payload/*.app/Info.plist' 2>/dev/null | plutil -extract "$2" raw -o - - 2>/dev/null
}

pick_file() {
  osascript -e 'POSIX path of (choose file with prompt "Select an IPA to install" of type {"ipa", "com.apple.itunes.ipa"})' 2>/dev/null
}

select_game() {
  local games=() dir
  for dir in "$root"/games/*/; do
    [[ -d $dir ]] && games+=("$(basename "$dir")")
  done
  menu "Which game do you want to install?" "${games[@]}" "Select IPA file..." "Quit"
  case "$choice" in
    "Quit") exit 0 ;;
    "Select IPA file...")
      game=""
      ipa="$(pick_file)"
      [[ -z $ipa ]] && { warn "No file selected."; return 1; }
      [[ -f $ipa ]] || { fail "Not a file: $ipa"; return 1; } ;;
    *) game="$choice" ;;
  esac
}

select_ipa() {
  local files=() labels=() f i
  # Newest first.
  while IFS= read -r f; do files+=("$f"); done < <(ls -t "$root/games/$game/dist/"*.ipa 2>/dev/null)
  if ((${#files[@]} == 0)); then
    warn "No IPAs in games/$game/dist. Build one first: cd games/$game && make package FINALPACKAGE=1 && scripts/package-ipa.sh"
    return 1
  fi
  for i in "${!files[@]}"; do
    labels+=("$(basename "${files[$i]}")  ${dim}$(du -h "${files[$i]}" | cut -f1 | tr -d ' '), $(date -r "${files[$i]}" '+%b %d %H:%M')$([[ $i == 0 ]] && echo ", newest")${reset}")
  done
  menu "Which $game build?" "${labels[@]}" "Back"
  [[ $choice == "Back" ]] && return 1
  ipa="${files[$choice_index]}"
  return 0
}

device_connected() {
  "$bin/ideviceinfo" -s -k DeviceName >/dev/null 2>&1
}

pair_device() {
  "$bin/idevicepair" validate >/dev/null 2>&1 && return 0
  "$bin/idevicepair" pair >/dev/null 2>&1 && return 0
  warn "Unlock the iPad and tap \"Trust\", then press Return."
  read -r || exit 0
  "$bin/idevicepair" pair >/dev/null 2>&1 && return 0
  fail "Couldn't pair with the iPad. If you tapped \"Don't Trust\", unplug and replug it and try again."
  return 1
}

confirm() {
  local id version name installed
  id="$(ipa_info "$ipa" CFBundleIdentifier)"
  version="$(ipa_info "$ipa" CFBundleShortVersionString)"
  name="$(ipa_info "$ipa" CFBundleDisplayName)"
  while ! device_connected; do
    menu "No device found. Connect the iPad over USB and unlock it." "Retry" "Back" "Quit"
    case "$choice" in Back) return 1 ;; Quit) exit 0 ;; esac
  done
  pair_device || return 1
  installed="$("$bin/ideviceinstaller" list -b "$id" -a CFBundleShortVersionString 2>/dev/null | sed -n 2p | tr -d '"')"
  printf '\n%sReady to install%s\n\n' "$bold" "$reset"
  printf '  IPA:        %s\n' "$ipa"
  printf '  App:        %s %s (%s)\n' "${name:-?}" "${version:-?}" "${id:-unknown bundle id}"
  printf '  Device:     %s, %s, iOS %s\n' "$("$bin/ideviceinfo" -k DeviceName)" "$("$bin/ideviceinfo" -k ProductType)" "$("$bin/ideviceinfo" -k ProductVersion)"
  printf '  Installed:  %s\n' "${installed:-not installed}"
  menu "Install it?" "Install" "Back" "Quit"
  case "$choice" in Back) return 1 ;; Quit) exit 0 ;; esac
}

install_ipa() {
  say ""
  say "Installing $(basename "$ipa")..."
  if "$bin/ideviceinstaller" install "$ipa"; then
    say ""
    say "${green}Installed.${reset} If the home screen icon looks stale, run uicache as mobile or respring."
  else
    fail "Install failed. Check that the iPad is jailbroken (TNS Sockport active) and AppSync Unified is installed."
    return 1
  fi
}

# Screens: game -> ipa (skipped for a picked file) -> confirm. Back returns to the previous screen.
screen=game
while true; do
  case "$screen" in
    game) select_game && screen=$([[ -n $game ]] && echo ipa || echo confirm) ;;
    ipa) if select_ipa; then screen=confirm; else screen=game; fi ;;
    confirm)
      if confirm; then
        install_ipa
        menu "What next?" "Install another" "Quit"
        [[ $choice == "Quit" ]] && exit 0
        screen=game
      else
        screen=$([[ -n $game ]] && echo ipa || echo game)
      fi ;;
  esac
done
