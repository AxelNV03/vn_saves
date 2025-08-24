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
# Función para sincronizar los saves a git
sync_to_git(){
    echo -e "\nActualizando saves en las carpetas de git...\nObteniendo carpetas locales..."
    printf '📂 %s\n' "${NOVELS[@]}"

    # Sincronizar cambios a git
    echo -e "\nSincronizando saves...\n"
    for novel in "${NOVELS[@]}"; do
        local src="$VN_PATH/$novel/" 
        local dest="$GIT_PATH/$novel/"
        
        printf '📂 %-24s ' "$novel"
        
        if [[ ! -d "$src/data" ]]; then
            local subdirs
            mapfile -t subdirs < <(get_folders "$src")
            echo ""
            
            for subd in "${subdirs[@]}"; do
                printf '└── 📂 %-21s' "$subd"
                src="$VN_PATH/$novel/$subd/data/game/saves/"
                dest="$GIT_PATH/$novel/$subd/"
                mkdir -p "$dest"
                sync_dirs "$src" "$dest" "$subd" && continue
            done
        else
            mkdir -p "$dest"
            src="$VN_PATH/$novel/data/game/saves/"
            sync_dirs "$src" "$dest" && continue
        fi
    done
}
# ------------------------------------------------------------------------------------------------------------------------------
# Función para sincronizar los saves a local
sync_to_local(){
    echo -e "\nActualizando saves en las carpetas locales...\nObteniendo carpetas de git..."
    git pull
    printf '📂 %s\n' "${GIT_NOVELS[@]}"

    # Sincronizar cambios a local
    echo -e "\nSincronizando saves...\n"

    list="$NOVELS"
    sync 1 "$VN_PATH" "$GIT_PATH"

    # for novel in "${GIT_NOVELS[@]}"; do
    #     local src="$GIT_PATH/$novel/"
    #     local dest="$VN_PATH/$novel/"

    #     printf '📂 %-24s ' "$novel"

    #     if [[ -d "$dest" ]]; then 
    #         if [[ ! -d "$dest/data" ]];then
    #             local subdirs
    #             mapfile -t subdirs < <(get_folders "$src")
    #             echo ""

    #             for subd in "${subdirs[@]}"; do
    #                 printf '└── 📂 %-21s' "$subd"
    #                 src="$GIT_PATH/$novel/$subd/"
    #                 dest="$VN_PATH/$novel/$subd/data/game/saves/"
    #                 sync_dirs "$src" "$dest" && continue
    #             done 
    #         else
    #             dest="$dest/data/game/saves/"
    #             sync_dirs "$src" "$dest" && continue
    #         fi
    #     fi
    # done
}
# ------------------------------------------------------------------------------------------------------------------------------
sync(){
    local tipo="$1"
    local src dest

    for novel in "${list[@]}"; do       
        src="$2" dest="$3"

        printf '📂 %-24s ' "$novel"


        if [[ ! -d "$VN_PATH/$novel/data/" ]]; then
            if [[ $tipo != 1 && ! -d "$VN_PATH/$novel" ]]; then
                echo -e "❌ No existe en los archivos locales"
            fi
            
            
            [ $tipo != 1 && ! -d ] && ||


        else 

        fi



        if [[ ! -d "$src/$novel/data" ]]; then
            echo "entro $novel por que no existe data"
            local subdirs
            mapfile -t subdirs < <(get_folders "$src/$novel")
            echo ""

            for subd in "${subdirs[@]}"; do
                printf '└── 📂 %-21s' "$subd"
                if [[ $tipo == 1 ]]; then
                    src="$VN_PATH/$novel/$subd/data/game/saves/"
                    dest="$GIT_PATH/$novel/$subd/"
                    mkdir -p "$dest"
                else
                    src="$GIT_PATH/$novel/$subd/"
                    dest="$VN_PATH/$novel/$subd/data/game/saves/"
                fi
                sync_dirs "$src" "$dest" && continue    
            done
        else
            if [[ $tipo == 1 && -d "$src" ]]; then 
                src="$VN_PATH/$novel/data/game/saves/"
                dest="$GIT_PATH/$novel/"
                mkdir -p "$dest"
            fi 
            sync_dirs "$src" "$dest" && continue
        fi
    done
}
# ------------------------------------------------------------------------------------------------------------------------------

git(){
    local opc="$1"

    case "$opc" in
        push)
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
            ;;
        pull)
            git -C "$GIT_PATH" pull origin main || { echo "Error al hacer pull"; exit 1; }
            ;;
    esac
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

# Define directorios
mapfile -t NOVELS < <(get_folders "$VN_PATH")        # Novelas locales
mapfile -t GIT_NOVELS < <(get_folders "$GIT_PATH")   # Novelas en git

# sync_to_git
# sync_to_local

    list=("${NOVELS[@]}")
    echo "$(ls "$VN_PATH/eternum")"
    if [[ -d "$VN_PATH/eternum/data" ]]; then
        echo "existe data"
    fi
    # sync 1 "$VN_PATH" "$GIT_PATH"
    # printf '📂 %s\n' "${list[@]}"

# # Menu
# select option in "Sincronizar a Git" "Sincronizar a Local" "Salir"; do
#     case $option in
#         "Sincronizar a Git")
#             sync_to_git
#             ;;
#         "Sincronizar a Local")
#             sync_to_local
#             ;;
#         "Salir")
#             exit 0
#             ;;
#         *)
#             echo "Opción no válida"
#             ;;
#     esac
# done