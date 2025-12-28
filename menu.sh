#!/usr/bin/env bash
set -euo pipefail

script_dir=$(dirname "$(realpath "$0")")

# Cargar funciones
source "$script_dir/core.sh"

# ---------------------------
# Notificación (swaync/libnotify)
# ---------------------------
notify_vn(){
  local urgency="${1:-normal}" title="${2:-VN Saves}" body="${3:-}"
  notify-send \
    -a "VN Saves" \
    -u "$urgency" \
    -h string:x-canonical-private-synchronous:vn_saves \
    "$title" \
    "$body" >/dev/null 2>&1 || true
}

run_action(){
  local title="$1"; shift
  local log="/tmp/vn_saves.log"

  notify_vn normal "$title" "Iniciando…"

  # Guardar salida para debug (por si lo ejecutas sin terminal)
  if "$@" >"$log" 2>&1; then
    notify_vn normal "$title" "✅ Listo"
    return 0
  else
    # Muestra un resumen corto y deja el log completo en /tmp
    local tailmsg
    tailmsg="$(tail -n 12 "$log" 2>/dev/null || true)"
    notify_vn critical "$title" $'❌ Falló\n\n'"$tailmsg"$'\n\nLog: /tmp/vn_saves.log'
    return 1
  fi
}

menu(){
  choice=$(printf "%s\n" \
    "📥 Git → Local" \
    "📤 Cargar a Git" \
    "▶ Ejecutar novela" |
    rofi -dmenu -i -p "VN Saves") || exit 0

  case "$choice" in
    "📥 Git → Local")
      run_action "Git → Local" git_pull
      run_action "Sync Git → Local" sync_all 2
      ;;
    "📤 Cargar a Git")
      run_action "Sync Local → Git" sync_all 1
      run_action "Git Push" git_push
      ;;
    "▶ Ejecutar novela")
      # Aquí normalmente quieres solo notificar inicio/fin, sin log gigante
      notify_vn normal "Ejecutar novela" "Abriendo lista…"
      run_novel
      ;;
    *)
      exit 0
      ;;
  esac
}

menu
