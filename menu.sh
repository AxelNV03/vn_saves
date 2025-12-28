#!/usr/bin/env bash
set -euo pipefail

script_dir=$(dirname "$(realpath "$0")")

# Cargar funciones
source "$script_dir/core.sh"

menu(){
  choice=$(printf "%s\n" \
    "📥 Git → Local" \
    "📤 Cargar a Git" \
    "▶ Ejecutar novela" |
    rofi -dmenu -i -p "VN Saves")

  case "$choice" in
    "📥 Git → Local") git_pull; sync_all 2 ;;
    "📤 Cargar a Git") sync_all 1; git_push ;;
    "▶ Ejecutar novela") run_novel ;;
  esac
}

menu
# ==============================================================================================================================


