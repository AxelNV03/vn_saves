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

# Función para actualizar los archivos de guardado en git
sync_saves_to_git() {
    # Mostrar mensaje
    echo -e "\nActualizando saves en las carpetas de git...\nObteniendo carpetas locales..."

    # Capturar dirs en un arreglo
    local novelas
    mapfile -t novelas < <(get_folders "$VN_PATH")
    printf '📂 %s\n' "${novelas[@]}"

    # Sincronizar carpetas del repositorio
    echo -e "\nSincronizando saves...\n"
    for dir in "${novelas[@]}"; do
        printf '📂 %-24s ' "$dir"
        if [[ -d "$VN_PATH/$dir/data" ]]; then
            if [[ -d "$VN_PATH/$dir/data/game/saves" ]]; then
                mkdir -p "$GIT_PATH/$dir/"
                if rsync -a "$VN_PATH/$dir/data/game/saves/" "$GIT_PATH/$dir/" > /dev/null 2>&1; then
                    printf '✅ correcto\n'
                else
                    printf '❌ Error al sincronizar %s\n' "$dir"
                fi
            else
                printf '❌ Error: No se encontró saves en %s\n' "$dir"
            fi
        else
            local subdirs
            mapfile -t subdirs < <(get_folders "$VN_PATH/$dir")
            echo ""
            for subd in "${subdirs[@]}"; do
                printf '└── 📂 %-21s' "$subd"
                if [[ -d "$VN_PATH/$dir/$subd/data" ]]; then
                    if [[ -d "$VN_PATH/$dir/$subd/data/game/saves" ]]; then
                        mkdir -p "$GIT_PATH/$dir/$subd/"
                        if rsync -a "$VN_PATH/$dir/$subd/data/game/saves/" "$GIT_PATH/$dir/$subd/" > /dev/null 2>&1; then
                            printf '✅ correcto\n'
                        else
                            printf '❌ Error al sincronizar %s/%s\n' "$dir" "$subd"
                        fi
                    else
                        printf '❌ Error: No se encontró saves en %s/%s\n' "$dir" "$subd"
                    fi
                else
                    printf '❌ Error: No se encontró data en %s/%s\n' "$dir" "$subd"
                fi
            done
        fi
    done
    echo -e "\n\n✅ Sincronización local de saves completada.\n"

    # Inicializar repositorio solo si no existe
    if [[ ! -d "$GIT_PATH/.git" ]]; then
        git init "$GIT_PATH" || { echo "Error al inicializar el repositorio"; exit 1; }
    fi

    # Verificar remoto
    if ! git -C "$GIT_PATH" remote | grep -q "origin"; then
        echo "Error: No hay un remoto 'origin' configurado en $GIT_PATH"
        exit 1
    fi

    # Preparar para la sincronización
    git -C "$GIT_PATH" add . || { echo "Error al agregar archivos"; exit 1; }
    git -C "$GIT_PATH" commit -m "Actualización de archivos de guardado" || { echo "Error al hacer commit"; exit 1; }
    git -C "$GIT_PATH" push origin main || { echo "Error al hacer push"; exit 1; }

    # Mostrar mensaje de confirmación
    echo -e "\n✅ Sincronización completada."
}

# ------------------------------------------------------------------------------------------------------------------------------

# Función para actualizar los archivos de guardado locales
sync_saves_git_to_local(){
    # Mostrar mensaje
    echo -e "\nObteniendo cambios de git..."

    # Traer cambios de git
    # git -C "$GIT_PATH" pull origin main || { echo "Error al traer cambios"; exit 1; }

    echo -e "\nCargando carpetas\nActualizando saves en las carpetas locales...\n"

    # Cargar carpetas
    local git_vns
    mapfile -t git_vns < <(get_folders "$GIT_PATH")
    printf '📂 %s\n' "${git_vns[@]}"

    # Sincronizar con las carpetas locales
    echo -e "\nSincronizando saves...\n"
    for dir in "${git_vns[@]}"; do
        printf '📂 %-24s ' "$dir"
        if [[ -d $VN_PATH/$dir ]]; then
            if [ -n "$(find $GIT_PATH/$dir -mindepth 1 -maxdepth 1 -type d -print -quit)" ]; then
                local subdirs
                mapfile -t subdirs < <(get_folders "$GIT_PATH/$dir")
                echo ""
                for subd in "${subdirs[@]}"; do
                    printf '└── 📂 %-21s' "$subd"
                    if rsync -a "$GIT_PATH/$dir/$subd/" "$VN_PATH/$dir/$subd/data/game/saves/" > /dev/null 2>&1; then
                        printf '✅ correcto\n'
                    else
                        printf '❌ Error al sincronizar\n'
                    fi
                done  
            else
                if rsync -a "$GIT_PATH/$dir/" "$VN_PATH/$dir/data/game/saves/" > /dev/null 2>&1; then
                    printf '✅ correcto\n'
                else
                    printf '❌ Error al sincronizar %s/%s\n' "$dir" "$subd"
                fi
            fi
        else
            printf '❌ La carpeta %s no se encuentra en el sistema \n' "$dir"
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

# Logica de sincronización
sync_saves_to_git
# sync_saves_git_to_local