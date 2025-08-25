#!/bin/bash
set -euo pipefail

# Obtener la ruta del directorio donde está el script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Rutas
GIT_PATH="$SCRIPT_DIR"
VN_PATH=$(cd "$SCRIPT_DIR/.." && pwd)

# Validar rutas
[[ -d "$VN_PATH" ]] || { echo "Error: VN_PATH ($VN_PATH) no existe"; exit 1; }
[[ -d "$GIT_PATH" ]] || { echo "Error: GIT_PATH ($GIT_PATH) no existe"; exit 1; }

# ------------------------------------------------------------------------------------------------------------------------------
sync(){
    local tipo="$1"
    local src dest
    
    for novel in "${list[@]}"; do       
        printf '📂 %-24s ' "$novel"
        [[ $tipo != 1 && ! -d "$VN_PATH/$novel/" ]] && { echo -e "❌ No existe en los archivos locales"; continue; }
        src="$([[ $tipo == 1 ]] && echo "$VN_PATH/$novel" || echo "$GIT_PATH/$novel" )"
        if [[ ! -d "$VN_PATH/$novel/data/" ]]; then    
            local subdirs
            mapfile -t subdirs < <(get_folders "$src/")
            echo ""
            for subd in "${subdirs[@]}"; do
                printf '└── 📂 %-21s' "$subd"
                src="$([[ $tipo == 1 ]] && echo "$VN_PATH/$novel/$subd/data/game/saves/" || echo "$GIT_PATH/$novel/$subd/")"
                dest="$([[ $tipo == 1 ]] && echo "$GIT_PATH/$novel/$subd/" || echo "$VN_PATH/$novel/$subd/data/game/saves/")"
                [[ $tipo == 1 && -d "$src" ]] && mkdir -p "$dest"
                sync_dirs "$src" "$dest" && continue    
            done
        else
            dest="$([[ $tipo == 1 ]] && echo "$GIT_PATH/$novel/" || echo "$VN_PATH/$novel/data/game/saves/" )"
            [[ $tipo == 1 && ! -d "$src/data/game/" ]] && { echo -e "❌ No existe en los archivos locales"; continue; }
            src="$([[ $tipo == 1 ]] && echo "$VN_PATH/$novel/data/game/saves/" || echo "$GIT_PATH/$novel/" )"
            sync_dirs "$src" "$dest" && continue
        fi
    done
}
# ------------------------------------------------------------------------------------------------------------------------------
# Función para obtener los nombres de las carpetas
get_folders() {
    local FOLDER="$1"
    for dir in "$FOLDER"/*/; do
        [[ ! -d "$dir" ]] && continue
        [[ "$(basename "${dir%/}")" == "vn_saves" ]] && continue
        echo "$(basename "${dir%/}")"
    done
}
# ------------------------------------------------------------------------------------------------------------------------------
sync_dirs(){
    local src="$1"
    local dest="$2"

    if rsync -a "$src" "$dest" > /dev/null 2>&1; then
        echo -e "✅ correcto"
        return 0
    else
        echo -e "❌ Error al sincronizar"
        return 1
    fi
}
# ------------------------------------------------------------------------------------------------------------------------------
git_op(){
    if [[ "$1" != 1 ]]; then
        # Intentar hacer un pull sin detener el script si no hay cambios
        git -C "$GIT_PATH" pull || echo "No hay cambios para traer."
        return 0
    fi
    git -C "$GIT_PATH" init
    git -C "$GIT_PATH" add .
    git -C "$GIT_PATH" commit -m "Saves del $(date +'%d/%m/%y')"
    git -C "$GIT_PATH" push -u origin main
}

# ------------------------------------------------------------------------------------------------------------------------------
menu() {
    echo "=============================="
    echo "  📂 Sincronización de saves  "
    echo "=============================="
    echo "1) Cargar saves locales a git"
    echo "0) Importar saves desde git"
    echo "q) Salir"
    echo "------------------------------"
    read -rp "Elige una opción: " opcion

    case "$opcion" in
        1)
            echo -e "\n➡️  Cargando saves locales a git...\n"
            mapfile -t list < <(get_folders "$VN_PATH")        # Novelas locales
            sync 1
            git_op 0
            ;;
        0)
            echo -e "\n⬇️  Importando saves desde git...\n"
            mapfile -t list < <(get_folders "$GIT_PATH")   # Novelas en git
            git_op 1
            sync 0
            ;;
        q|Q)
            echo "👋 Saliendo..."
            exit 0
            ;;
        *)
            echo "❌ Opción no válida"
            ;;
    esac
}
# ------------------------------------------------------------------------------------------------------------------------------
menu
