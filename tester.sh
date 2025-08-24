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


        if [[ ! -d "$VN_PATH/$novel/data/" ]]; then
            if [[ $tipo != 1 && ! -d "$VN_PATH/$novel" ]]; then
                echo -e "❌ No existe en los archivos locales"
            
            
            fi 
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

# Define directorios
mapfile -t NOVELS < <(get_folders "$VN_PATH")        # Novelas locales
mapfile -t GIT_NOVELS < <(get_folders "$GIT_PATH")   # Novelas en git

list=("${NOVELS[@]}")
# list=("${GIT_NOVELS[@]}")

printf '📂 %s\n' "${list[@]}"
echo -e "\n\n\n"
sync 1
