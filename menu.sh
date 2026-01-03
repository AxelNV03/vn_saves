#!/usr/bin/env bash
set -euo pipefail

script_dir=$(dirname "$(realpath "$0")")

# Cargar funciones
source "$script_dir/core.sh"

# ==============================================================================================================================
# Función para mandar notificaciones
# ==============================================================================================================================
notify_vn(){
  local urgency="${1:-normal}" title="${2:-VN Saves}" body="${3:-}"
  notify-send \
    -a "VN Saves" \
    -u "$urgency" \
    -h string:x-canonical-private-synchronous:vn_saves \
    "$title" \
    "$body" >/dev/null 2>&1 || true
}
# ==============================================================================================================================
# Función para ejecutar funciones con notificaciones y manejo de logs
# ==============================================================================================================================
run_action(){
  local title="$1"; shift
  local log="/tmp/vn_saves.log"

  notify_vn normal "$title" "Iniciando…"

  if "$@" >"$log" 2>&1; then
    # Contar resultados (según tus mensajes)
    local ok missing
    ok="$(grep -c "✅ correcto" "$log" 2>/dev/null || true)"
    missing="$(grep -c "❌ No existe" "$log" 2>/dev/null || true)"

    if (( missing > 0 )); then
      notify_vn normal "$title" "✅ OK: $ok  |  ⚠️ No existen en local: $missing\nDetalles en /tmp/vn_saves.log"
    else
      notify_vn normal "$title" "✅ OK: $ok"
    fi
    return 0
  else
    local tailmsg
    tailmsg="$(tail -n 12 "$log" 2>/dev/null || true)"
    notify_vn critical "$title" $'❌ Falló\n\n'"$tailmsg"$'\n\nLog: /tmp/vn_saves.log'
    return 1
  fi
}

# ==============================================================================================================================
# Función para ejecutar la novela seleccionada
# ==============================================================================================================================
start_novel(){
  local choice folder subd game
  local vn_path="$HOME/.VN"

  while true; do
    mapfile -t local_novels < <(get_folders "$vn_path")

    # Selección de novela
    choice="$(
      {
        printf "🎮 %s\n" "${local_novels[@]}" 
      } | rofi -dmenu -i -p "Selecciona novela"
    )" || return 0

    [[ -z "$choice" ]] && return 0  # ← regresa a novelas
    folder="${choice#🎮 }"

    game=""

    # Caso A: estructura directa
    if [[ -d "$vn_path/$folder/data/" ]]; then
      game="$(find "$vn_path/$folder/data" -maxdepth 1 -type f -name '*.sh' -print -quit)"
    else
      # Caso B: con subdirectorios
      local subdirs
      mapfile -t subdirs < <(get_folders "$vn_path/$folder")

      choice="$(
        {
          printf "🧩 %s\n" "${subdirs[@]}"
        } | rofi -dmenu -i -p "Selecciona capítulo/temporada"
      )" || continue   # ← cancel en submenú => vuelve a lista de novelas

      [[ -z "$choice" ]] && continue  # ← regresa a novelas

      subd="${choice#🧩 }"
      game="$(find "$vn_path/$folder/$subd/data" -maxdepth 1 -type f -name '*.sh' -print -quit)"
    fi
  
    # Validar launcher
    if [[ -z "${game:-}" ]]; then
      notify-send -a "VN" -u critical "No se encontró launcher" "$folder"
      # Si quieres que vuelva a novelas cuando falla, deja continue:
      continue
    fi

    notify_vn normal "Ejecutando novela" "$folder"
    chmod +x "$game" 2>/dev/null || true
    exec bash "$game"
    return 0
  done
}
# ==============================================================================================================================
# Función para abrir el menú
# ==============================================================================================================================
menu(){
  while true; do
    choice=$(printf "%s\n" \
      "📥 Sincronizar: Git → Local" \
      "📤 Sincronizar: Local → Git" \
      "▶ Ejecutar novela" |
      rofi -dmenu -i -p "VN Saves") || exit 0

    case "$choice" in
      "📥 Sincronizar: Git → Local")
        run_action "Git → Local" git_pull
        run_action "Sync Git → Local" sync_all 2
        ;;
      "📤 Sincronizar: Local → Git")
        run_action "Sync Local → Git" sync_all 1
        run_action "Git Push" git_push
        ;;
      "▶ Ejecutar novela")
        # Aquí normalmente quieres solo notificar inicio/fin, sin log gigante
        notify_vn normal "Ejecutar novela" "Abriendo lista…"
        start_novel
        ;;
      *)
        exit 0
        ;;
    esac
  done
}
# ==============================================================================================================================
# Función para sincronizar todas las novelas (Funciona Ya no tocar)
# ==============================================================================================================================
menu
# start_novel
