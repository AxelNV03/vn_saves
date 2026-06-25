# ==============================================================================================================================
# vn_saves/script_sincronizacion.sh
# ==============================================================================================================================
#!/bin/bash
set -euo pipefail

# Obtener la ruta absoluta del directorio donde está el script
script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

# Rutas absolutas bien resueltas
git_path="$script_dir"
vn_path=$(realpath "$script_dir/..")

# Validar rutas
[[ -d "$vn_path" ]] || { echo "❌ Error: vn_path ($vn_path) no existe"; exit 1; }
[[ -d "$git_path" ]] || { echo "❌ Error: git_path ($git_path) no existe"; exit 1; }
# ==============================================================================================================================
# Función para obtener los nombres de las carpetas
# ==============================================================================================================================
obtener_folders() {
    local folder="$1"
    shopt -s nullglob
    
    for dir in "$folder"/*/; do
        local name="${dir%/}"
        name="${name##*/}"        
        [[ "$name" == "vn_saves" || "$name" == "."* ]] && continue
        echo "$name"
    done
    shopt -u nullglob
}
# ==============================================================================================================================
# Módulo de Sincronización (Bajo Nivel): Recibe Origen y Destino definitivos y ejecuta rsync
# ==============================================================================================================================
sincronizar_folders(){
    local src="$1"
    local dest="$2"

    if [[ -d "$src" ]]; then
        mkdir -p "$dest"
        if rsync -a "$src/." "$dest" > /dev/null 2>&1; then
            echo -e "✅ correcto"
            return 0
        else
            echo -e "❌ Error al sincronizar archivos"
            return 1
        fi
    else
        echo -e "❌ Sin saves"
        return 1
    fi
}
# ==============================================================================================================================
# Manejador de Novelas Sin Capítulos (Estructura Simple)
# ==============================================================================================================================
folders_simples() {
    local type="$1"
    local novel="$2"

    local local_target="$vn_path/$novel/data/game/saves"
    local git_target="$git_path/$novel"

    # Definir origen y destino de una vez antes de enviar al módulo
    if [[ $type == 1 ]]; then
        sincronizar_folders "$local_target" "$git_target"
    else
        sincronizar_folders "$git_target" "$local_target"
    fi
}
# ==============================================================================================================================
# Manejador de Novelas Con Capítulos/Temporadas (Estructura Compleja)
# ==============================================================================================================================
folders_complejos() {
    local type="$1"
    local novel="$2"
    local search_path="$3"

    local subdirs
    mapfile -t subdirs < <(obtener_folders "$search_path")
    echo "" # Salto de línea estético para la jerarquía visual

    for subd in "${subdirs[@]}"; do
        printf '└── 📂 %-21s' "$subd"
        
        local local_target="$vn_path/$novel/$subd/data/game/saves"
        local git_target="$git_path/$novel/$subd"
        
        # Definir origen y destino de una vez por cada subdirectorio
        if [[ $type == 1 ]]; then
            sincronizar_folders "$local_target" "$git_target"
        else
            sincronizar_folders "$git_target" "$local_target"
        fi
    done
}
# ==============================================================================================================================
# Función Principal / Despachador Central
# ==============================================================================================================================
sincronizar(){
    local type="$1" # 1: Local a Git | 2: Git a Local
    local list=()
    
    [[ $type == 1 ]] && list=("${local_novels[@]}") || list=("${git_novels[@]}")

    for novel in "${list[@]}"; do
        printf '📂 %-24s ' "$novel"

        # Validar que exista el contenedor local al restaurar de Git
        [[ $type == 2 && ! -d "$vn_path/$novel/" ]] && { echo -e "❌ No existe en los archivos locales"; continue; }

        # Ruta base para buscar subcarpetas si es necesario
        local base_src
        [[ $type == 1 ]] && base_src="$vn_path/$novel" || base_src="$git_path/$novel"

        # Evaluar estructura de la novela
        if [[ -d "$vn_path/$novel/data/" ]]; then
            folders_simples "$type" "$novel"
        else
            folders_complejos "$type" "$novel" "$base_src"
        fi    
    done
}
# ==============================================================================================================================
# Validación: Asegura que estemos dentro de un repositorio Git válido
# ==============================================================================================================================
check_git_repo() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "❌ No estás dentro de un repositorio Git"
        return 1
    fi
}
# ==============================================================================================================================
# Pull de cambios en el repositorio de saves
# ==============================================================================================================================
git_pull(){
    (
        cd "$git_path" || return 1
        check_git_repo || return 1

        echo "⬇️  Trayendo cambios remotos (Pull)..."
        git fetch origin
        if git pull --rebase origin main; then
            echo "✅ Repositorio actualizado correctamente"
            return 0
        else
            echo "❌ Error al sincronizar con origin/main"
            return 1
        fi
    )
}
# ==============================================================================================================================
# Push de cambios en el repositorio de saves
# ==============================================================================================================================
git_push(){
    (
        cd "$git_path" || return 1
        check_git_repo || return 1

        # No hacer nada si no hay cambios en el directorio de trabajo
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

        # REUTILIZACIÓN: Llamamos a nuestra función git_pull antes de subir
        echo "🔄 Asegurando sincronización con el remoto antes del push..."
        git_pull || return 1

        echo "🚀 Subiendo saves a GitHub..."
        git push origin main || {
            echo "❌ Error al hacer push"
            return 1
        }

        echo "✅ Push completado con éxito"
    )
}
# ==============================================================================================================================
# Inicio de Mapeo de carpetas
# ==============================================================================================================================

# Mapear novelas (Local y Git)
mapfile -t local_novels < <(obtener_folders "$vn_path") 
mapfile -t git_novels < <(obtener_folders "$git_path")