#!/bin/bash

# Función para obtener el tiempo de actividad del sistema
get_uptime() {
    UPTIME=$(uptime | awk -F'( |,|:)+' '{print $3 "d " $4 "h " $5 "m"}')
    echo "$UPTIME"
}

# Función para obtener la memoria total y libre
get_memory_info() {
    MEMORY_TOTAL=$(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024 " GB"}')
    MEMORY_FREE=$(vm_stat | grep "Pages free:" | awk '{print $3}' | sed 's/\.//' | awk '{print $1*4096/1024/1024/1024}')
    MEMORY_USED=$(echo "$MEMORY_TOTAL - $MEMORY_FREE" | bc)
    MEMORY_USED_PERCENT=$(echo "scale=2; ($MEMORY_USED / ${MEMORY_TOTAL% *}) * 100" | bc)
}

# Función para obtener la versión del sistema operativo
get_os_version() {
    sw_vers -productVersion
}

# Función para obtener la información del procesador y arquitectura
get_processor_architecture() {
    local processor=$(sysctl -n machdep.cpu.brand_string)
    local architecture=$(uname -m)
    echo "$processor ($architecture)"
}

# Función para obtener la cantidad de RAM instalada
get_installed_ram() {
    system_profiler SPHardwareDataType | grep '  Memory:' | awk '{print $2}'
}

# Función para obtener la capacidad del disco y el uso
get_disk_usage() {
    local disk_usage=$(df -H / | awk 'NR==2 {print $2 " total, " $3 " used, " $5 " used percentage"}')
    echo "$disk_usage"
}

# Función para obtener la marca y velocidad de la RAM
get_ram_details() {
    local ram_details=$(system_profiler SPMemoryDataType | awk -F': ' '/Manufacturer:/ {printf "%-20s", $2}; /Speed:/ {printf "%s", $2}')
    echo "$ram_details"
}

# Función para obtener la marca del equipo y el número de serie
get_brand_serial() {
    local brand=$(system_profiler SPHardwareDataType | grep 'Model Name:' | awk '{print $3, $4}')
    local serial=$(system_profiler SPHardwareDataType | grep 'Serial Number (system):' | awk '{print $4}')
    echo "$brand, $serial"
}

# Función para obtener la información de la GPU
get_gpu_info() {
    local gpu_info=$(system_profiler SPDisplaysDataType | awk -F': ' '/Chipset Model:/ {printf "%-40s", $2}')
    echo "$gpu_info"
}

# Función para obtener el uso de memoria RAM
get_ram_usage() {
    local ram_active=$(vm_stat | grep 'Pages active:' | awk '{print $3}' | sed 's/\.//')
    local ram_used=$(echo "scale=2; ($ram_active * 4096) / 1024 / 1024 / 1024" | bc)
    echo "$ram_used GB"
}

# Función para obtener la temperatura de la CPU
get_temperature() {
    if command -v osx-cpu-temp >/dev/null 2>&1; then
        local temp=$(osx-cpu-temp)
    else
        local temp="N/A"
    fi
    echo "$temp"
}

# Función para obtener el uso de CPU
get_cpu_usage() {
    top -l 1 | grep "CPU usage" | awk '{print $3}'
}

# Función para obtener la información completa del sistema
get_system_info() {
    local os_version=$(get_os_version)
    local processor_architecture=$(get_processor_architecture)
    local ram_installed=$(get_installed_ram)
    local disk_usage=$(get_disk_usage)
    local ram_details=$(get_ram_details)
    local brand_serial=$(get_brand_serial)
    local gpu_info=$(get_gpu_info)
    local ram_usage=$(get_ram_usage)
    local temperature=$(get_temperature)
    local cpu_usage=$(get_cpu_usage)
    get_memory_info
    local memory_used=$MEMORY_USED
    local memory_total=$MEMORY_TOTAL
    local memory_used_percent=$MEMORY_USED_PERCENT

    # Mostrar información formateada
    cat <<EOF
                    'c.          | $USER@$(scutil --get ComputerName)
                 ,xNMM.          | ------------------------------------
               .OMMMMo           | OS: macOS $os_version
               OMMM0,            | Processor and Architecture: $processor_architecture
     .;loddo:' loolloddol;.      | Installed RAM: $ram_installed GB
   cKMMMMMMMMMMNWMMMMMMMMMM0:    | Disk Usage: $disk_usage
 .KMMMMMMMMMMMMMMMMMMMMMMMWd.    | RAM Details: $ram_details
 XMMMMMMMMMMMMMMMMMMMMMMMX.      | Brand and Serial: $brand_serial
;MMMMMMMMMMMMMMMMMMMMMMMM:       | GPU: $gpu_info
:MMMMMMMMMMMMMMMMMMMMMMMM:       | RAM Usage: $ram_usage
.MMMMMMMMMMMMMMMMMMMMMMMMX.      | Temperature: $temperature
 kMMMMMMMMMMMMMMMMMMMMMMMMWd.    | CPU Usage: $cpu_usage
 .XMMMMMMMMMMMMMMMMMMMMMMMMMMk
  .XMMMMMMMMMMMMMMMMMMMMMMMMK.
    kMMMMMMMMMMMMMMMMMMMMMMd
     ;KMMMMMMMWXXWMMMMMMMk.
        .;cooc;.  .;coo:.              
EOF
}

# Función para mostrar el menú principal
show_menu() {
    clear
    echo "╔═════════════════════════════════════╗"
    echo "║          MENÚ PRINCIPAL             ║"
    echo "╠═════════════════════════════════════╣"
    echo "║ 1. Información del Sistema          ║"
    echo "║ 2. Salir                            ║"
    echo "╚═════════════════════════════════════╝"
    echo -n "Seleccione una opción [1-2]: "
    read option

    case $option in
        1)
            clear
            get_system_info
            echo ""
            echo "Presione cualquier tecla para volver al menú principal..."
            read -n 1
            show_menu
            ;;
        2)
            clear
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo "Opción no válida. Intente de nuevo."
            sleep 1
            show_menu
            ;;
    esac
}

# Mostrar el menú principal
show_menu

#curl -sSL https://raw.githubusercontent.com/BrandonSepulveda/Toolbox/main/toolbox.sh -o toolbox.sh
#chmod +x toolbox.sh
#./toolbox.sh
