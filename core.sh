#!/bin/bash
set -euo pipefail

# Obtener la ruta del directorio donde está el script
script_dir=$(dirname "$(realpath "$0")")

# Rutas
git_path="$script_dir"
vn_path=$(cd "$script_dir/.." && pwd)

# Validar rutas
[[ -d "$vn_path" ]] || { echo "Error: vn_path ($vn_path) no existe"; exit 1; }
[[ -d "$git_path" ]] || { echo "Error: git_path ($git_path) no existe"; exit 1; }

# ==============================================================================================================================
# Función para obtener los nombres de las carpetas
# ==============================================================================================================================
get_folders() {
    local folder="$1"
    for dir in "$folder"/*/; do
        [[ ! -d "$dir" ]] && continue
        [[ "$(basename "${dir%/}")" == "vn_saves" ]] && continue
        echo "$(basename "${dir%/}")"
    done
}
# ==============================================================================================================================
# Función para sincronizar todas las novelas (Funciona Ya no tocar)
# ==============================================================================================================================
sync_all(){
    local type="$1" # 1: Local a Git | 2: Git a Local
    local src dest

    # Establecer la lista de novelas según el tipo de sincronización
    local list=()
    [[ $type == 1 ]] && list=("${local_novels[@]}") || list=("${git_novels[@]}")

    # Sincronizar cada novela
    for novel in "${list[@]}"; do
        printf '📂 %-24s ' "$novel"

        # Verificar existencia y asignar ruta
        [[ $type == 2 && ! -d "$vn_path/$novel/" ]] && { echo -e "❌ No existe en los archivos locales"; continue; }
        src="$([[ $type == 1 ]] && echo "$vn_path/$novel" || echo "$git_path/$novel" )"

        # Detectar si hay subdirectorios
        if [[ ! -d "$vn_path/$novel/data/" ]]; then
            local subdirs

            mapfile -t subdirs < <(get_folders "$src/")
            echo ""
            
            # Sincronizar subdirectorios
            for subd in "${subdirs[@]}"; do
                printf '└── 📂 %-21s' "$subd"
                src="$([[ $type == 1 ]] && echo "$vn_path/$novel/$subd/data/game/saves/" || echo "$git_path/$novel/$subd/")"
                dest="$([[ $type == 1 ]] && echo "$git_path/$novel/$subd/" || echo "$vn_path/$novel/$subd/data/game/saves/")"

                # Crea el directorio destino por si no existe y sincroniza
                [[ $type == 1 && -d "$src" ]] && mkdir -p "$dest"
                sync_dirs "$src" "$dest" && continue    
            done
        else
            dest="$([[ $type == 1 ]] && echo "$git_path/$novel/" || echo "$vn_path/$novel/data/game/saves/" )"
            [[ $type == 1 && ! -d "$src/data/game/" ]] && { echo -e "❌ No existen saves"; continue; }
            src="$([[ $type == 1 ]] && echo "$vn_path/$novel/data/game/saves/" || echo "$git_path/$novel/")"
            sync_dirs "$src" "$dest" && continue
        fi    
    done
}
# ==============================================================================================================================
# Función para sincronizar directorios
# ==============================================================================================================================
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

# ==============================================================================================================================
# Push de cambios en el repositorio de saves
# ==============================================================================================================================
git_push(){
    cd "$git_path" || return 1

    # Verificar que sea repo git
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "❌ No estás dentro de un repositorio Git"
        return 1
    fi

    # No hacer nada si no hay cambios
    if [[ -z "$(git status --porcelain)" ]]; then
        echo "ℹ️  No hay cambios para commitear"
        return 0
    fi

    # Agrega TODO: modificados, nuevos y borrados
    git add -A

    # Si después de agregar no hay nada staged, salir
    if git diff --cached --quiet; then
        echo "ℹ️  No hay cambios preparados para commit"
        return 0
    fi

    git commit -m "Actualización de saves $(date '+%Y-%m-%d %H:%M:%S')" || {
        echo "❌ Error al hacer commit"
        return 1
    }

    # Traer cambios remotos antes de subir, para evitar atorarse si hay cambios en GitHub
    git pull --rebase origin main || {
        echo "❌ Error al sincronizar con origin/main"
        return 1
    }

    git push origin main || {
        echo "❌ Error al hacer push"
        return 1
    }

    echo "✅ Push completado"
}
# ==============================================================================================================================
# Pull de cambios en el repositorio de saves
# ==============================================================================================================================
git_pull(){
  (
    cd "$git_path" || return 1
    git fetch origin
    git pull --rebase origin main
  )
}
# ==============================================================================================================================
# Menu
# ==============================================================================================================================

# Mapear novelas (Local y Git)
mapfile -t local_novels < <(get_folders "$vn_path") 
mapfile -t git_novels < <(get_folders "$git_path")


git_push