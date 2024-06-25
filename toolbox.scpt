-- Abrir una nueva ventana de Terminal y ejecutar neofetch
tell application "Terminal"
	activate
	do script "neofetch"
end tell


-- Crear el diálogo inicial con botones
tell application "Finder"
	activate
	set buttonPressed to button returned of (display dialog "Seleccione una función:" buttons {"Información del Sistema", "Otra Función", "Salir"} default button "Información del Sistema")
	
	if buttonPressed is "Información del Sistema" then
		-- Obtener la versión del sistema operativo
		set osVersion to system attribute "sysv"
		
		-- Obtener información del procesador y arquitectura
		set processorInfo to do shell script "sysctl -n machdep.cpu.brand_string"
		set architecture to do shell script "uname -m"
		
		-- Obtener información de la memoria RAM instalada
		set ramInstalled to do shell script "sysctl -n hw.memsize"
		set formattedRAM to (ramInstalled / 1024 / 1024 / 1024) & " GB"
		
		-- Obtener capacidad del disco
		set diskCapacity to do shell script "df -H / | awk 'NR==2{print $2}'"
		
		-- Obtener información de la memoria RAM
		set ramInfo to do shell script "top -l 1 | awk '/PhysMem/ {print $2, $6}'"
		
		-- Obtener marca y velocidad del procesador
		set processorBrand to do shell script "sysctl -n machdep.cpu.brand_string"
		set processorSpeed to do shell script "sysctl -n hw.cpufrequency | awk '{print $0/1000000000\" GHz\"}'"
		
		-- Obtener marca del equipo y versión de BIOS
		set computerName to do shell script "scutil --get ComputerName"
		set biosVersion to do shell script "sysctl -n hw.model"
		
		-- Obtener número de serie de fábrica
		set serialNumber to do shell script "ioreg -l | grep IOPlatformSerialNumber | awk '{print $4}'"
		
		-- Obtener temperatura del sistema (requiere permisos adicionales)
		set temperature to do shell script "sudo powermetrics --samplers smc | grep -i 'CPU die temperature' | awk '{print $5}'"
		
		-- Obtener información de la GPU y uso de memoria RAM
		set gpuInfo to do shell script "system_profiler SPDisplaysDataType | grep -E 'Chipset Model:|VRAM'"
		
		-- Construir el mensaje con toda la información recolectada
		set systemInfoText to "Versión del Sistema: " & osVersion & return & ¬
			"Procesador: " & processorInfo & return & ¬
			"Arquitectura: " & architecture & return & ¬
			"RAM Instalada: " & formattedRAM & return & ¬
			"Capacidad del Disco: " & diskCapacity & return & ¬
			"Uso de Memoria RAM: " & ramInfo & return & ¬
			"Marca del Equipo: " & computerName & return & ¬
			"Versión de BIOS: " & biosVersion & return & ¬
			"Número de Serie: " & serialNumber & return & ¬
			"Temperatura del Sistema: " & temperature & " °C" & return & ¬
			"Información de la GPU: " & gpuInfo
		
		-- Mostrar la información en una ventana nueva
		display dialog systemInfoText buttons {"OK"} default button "OK" with icon note
		
	else if buttonPressed is "Otra Función" then
		display dialog "Función no implementada todavía" buttons {"OK"} default button "OK"
		
	else if buttonPressed is "Salir" then
		return -- Salir del script si se selecciona "Salir"
		
	end if
end tell


--curl -sSL https://raw.githubusercontent.com/BrandonSepulveda/Toolbox/main/toolbox.scpt | osascript
