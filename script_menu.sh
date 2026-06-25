#!/usr/bin/env bash
# ==============================================================================================================================
# vn_saves/lanzador.sh
# ==============================================================================================================================
set -euo pipefail
script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
source "$script_dir/script_sincronizacion.sh"
# ==============================================================================================================================
# Función para mandar notificaciones síncronas a SwayNC
# ==============================================================================================================================
notificaciones(){
    local urgency="${1:-normal}" title="${2:-VN Saves}" body="${3:-}"

    notify-send \
        -a "VN Saves" \
        -u "$urgency" \
        -h string:x-canonical-private-synchronous:vn_saves \
        "$title" \
        "$body" >/dev/null 2>&1 || true
}
# ==============================================================================================================================
# Wrapper de Ejecución: Maneja logs de comandos y lanza reportes visuales en SwayNC
# ==============================================================================================================================
ejecutar_accion(){
    local titulo="$1"; shift
    local log="/tmp/vn_saves.log"
    notificaciones "normal" "$titulo" "Iniciando…"

    if "$@" >"$log" 2>&1; then
        local ok missing
        ok="$(grep -c "✅ correcto" "$log" 2>/dev/null || true)"
        missing="$(grep -c "❌ No existe" "$log" 2>/dev/null || true)"

        if (( missing > 0 )); then
            notificaciones "normal" "$titulo" "✅ OK: $ok  |  ⚠️ No existen en local: $missing\nDetalles en /tmp/vn_saves.log"
        else
            notificaciones "normal" "$titulo" "✅ OK: $ok"
        fi
        return 0
    else
        # Si el comando falló (retornó != 0), extrae las últimas 12 líneas del error
        local msg_error
        msg_error="$(tail -n 12 "$log" 2>/dev/null || true)"
    
        # Notificación crítica (se queda pegada en color rojo en SwayNC)
        notificaciones "critical" "$titulo" $'❌ Falló\n\n'"$msg_error"$'\n\nLog completo en: /tmp/vn_saves.log'
        return 1
    fi
}
# ==============================================================================================================================
# Selector y Ejecutor: Explora novelas con Rofi y lanza sus scripts contenedores (.sh)
# ==============================================================================================================================
iniciar_novela(){
    local seleccion carpeta subcarpeta launcher
    
    while true; do
        local novelas_locales
        mapfile -t novelas_locales < <(obtener_folders "$vn_path")

        seleccion="$(
            {
                printf "🎮 %s\n" "${novelas_locales[@]}" 
            } | rofi -dmenu -i -p "Selecciona novela"
        )" || return 0

        [[ -z "$seleccion" ]] && return 0
        carpeta="${seleccion#🎮 }"

        launcher=""
        if [[ -d "$vn_path/$carpeta/data/" ]]; then
            # CASO A: Estructura Directa (Simple) - Busca el .sh de arranque
            launcher="$(find "$vn_path/$carpeta/data" -maxdepth 1 -type f -name '*.sh' -print -quit)"
        else
            local subcarpetas
            mapfile -t subcarpetas < <(obtener_folders "$vn_path/$carpeta")        
            
            # Submenú en Rofi para elegir la temporada
            seleccion="$(
                {
                    printf "🧩 %s\n" "${subcarpetas[@]}"
                } | rofi -dmenu -i -p "Selecciona capítulo/temporada"
            )" || continue # Si cancelas en este submenú, te regresa a la lista de novelas

            [[ -z "$seleccion" ]] && continue
            subcarpeta="${seleccion#🧩 }"    

            # Busca el .sh dentro de la subcarpeta
            launcher="$(find "$vn_path/$carpeta/$subcarpeta/data" -maxdepth 1 -type f -name '*.sh' -print -quit)"
        fi

        # Validar que exista
        if [[ -z "${launcher:-}" ]]; then
            notificaciones "critical" "Error de Launcher" "No se encontró ningún script .sh para arrancar en: $carpeta"
            continue # Regresa a la lista para no romper el programa
        fi

        notificaciones "normal" "Ejecutando novela" "Iniciando: $carpeta..."
        chmod +x "$launcher" 2>/dev/null || true

        bash "$launcher"
        
        exit 0
    done
}
# ==============================================================================================================================
# Función para abrir el menú (Integrado con Rofi y SwayNC)
# ==============================================================================================================================
menu(){
  while true; do
        # Lanzar Rofi con las opciones. Si el usuario presiona ESC o cierra Rofi, '|| exit 0' termina el script limpiamente.
        choice=$(printf "%s\n" \
            "📥 Sincronizar: Git → Local" \
            "📤 Sincronizar: Local → Git" \
            "▶ Ejecutar novela" |
            rofi -dmenu -i -p "VN Saves") || exit 0

        case "$choice" in
            "📥 Sincronizar: Git → Local")
                ejecutar_accion "Descargando de Git" git_pull
                ejecutar_accion "Sincronizando a Local" sincronizar 2  # <-- Corregido: antes era 'sync_all'
            ;;
            
            "📤 Sincronizar: Local → Git")
                ejecutar_accion "Sincronizando a Git" sincronizar 1    # <-- Corregido: antes era 'sync_all'
                ejecutar_accion "Subiendo a Git" git_push
            ;;

            "▶ Ejecutar novela")
                notificaciones "normal" "Ejecutar novela" "Abriendo lista de juegos…"
                iniciar_novela
            ;;
            
            *)
                exit 0
            ;;

        esac
    done
}
# ==============================================================================================================================
# Inicio App
# ==============================================================================================================================
menu

