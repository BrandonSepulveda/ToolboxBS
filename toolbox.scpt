-- Función para obtener la información del sistema
on obtenerInformacionSistema()
	try
		set infoSistema to ""
		
		-- Obtener la versión del sistema operativo
		set versionSistema to do shell script "sw_vers -productVersion"
		
		-- Obtener la información del procesador y arquitectura
		set procesador to do shell script "sysctl -n machdep.cpu.brand_string"
		set arquitectura to do shell script "uname -m"
		
		-- Obtener la cantidad de RAM instalada en GB
		set ramInstalada to do shell script "system_profiler SPHardwareDataType | grep '  Memory:' | awk '{print $2}'"
		
		-- Obtener la capacidad del disco y el uso
		set capacidadDisco to do shell script "df -H / | awk 'NR==2 {print $2}'"
		set usoDiscoGB to do shell script "df -H / | awk 'NR==2 {print $3}'"
		set usoDiscoPorcentaje to do shell script "df -H / | awk 'NR==2 {print $5}'"
		
		-- Obtener la marca y velocidad de la RAM
		set ramDetalle to paragraphs of (do shell script "system_profiler SPMemoryDataType | grep 'Speed:'")
		set marcaRAM to do shell script "system_profiler SPMemoryDataType | grep 'Manufacturer:' | awk '{print $2}'"
		set velocidadRAM to item 1 of ramDetalle -- Tomar la primera velocidad de RAM
		
		-- Obtener la marca del equipo y el número de serie
		set marcaEquipo to do shell script "system_profiler SPHardwareDataType | grep 'Model Name:' | awk '{print $3, $4}'"
		set numeroSerie to do shell script "system_profiler SPHardwareDataType | grep 'Serial Number (system):' | awk '{print $4}'"
		
		-- Obtener información de la GPU
		set gpuInfo to paragraphs of (do shell script "system_profiler SPDisplaysDataType | grep 'Chipset Model:'")
		set gpuInfoFormateada to ""
		repeat with gpu in gpuInfo
			set gpuInfoFormateada to gpuInfoFormateada & "      " & gpu & linefeed
		end repeat
		
		-- Obtener el uso de memoria RAM
		set ramUso to do shell script "vm_stat | grep 'Pages active:' | awk '{print $3}'"
		set ramUsoTrimmed to (characters 1 through ((length of ramUso) - 1) of ramUso) as string
		set ramUsoGB to ((ramUsoTrimmed as number) * 4096) / 1024 / 1024 / 1024
		set ramUsoGBStr to (round (ramUsoGB * 100) / 100) as string
		
		-- Construir la información del sistema con formato
		set infoSistema to "
            ------------------------------------
            Versión del S.O.: " & versionSistema & "
            Procesador: " & procesador & "
            Arquitectura: " & arquitectura & "
            RAM instalada: " & ramInstalada & " GB
            Capacidad de disco: " & capacidadDisco & "
            Uso de disco: " & usoDiscoGB & " (" & usoDiscoPorcentaje & ")
            Marca de RAM: " & marcaRAM & "
            Velocidad de RAM: " & velocidadRAM & "
            Marca del equipo: " & marcaEquipo & "
            Número de serie: " & numeroSerie & "
            GPU: " & gpuInfoFormateada & "
            Uso de memoria RAM: " & ramUsoGBStr & " GB de " & ramInstalada & " GB"
		
		return infoSistema
	on error errMsg
		return "Error al obtener información del sistema: " & errMsg
	end try
end obtenerInformacionSistema

-- Función para mostrar un cuadro de diálogo con la información del sistema
on mostrarInfoSistema()
	try
		set informacionSistema to obtenerInformacionSistema()
		
		-- Mostrar cuadro de diálogo con la información del sistema con dimensiones más grandes
		display dialog informacionSistema buttons {"Información Avanzada", "Volver"} default button "Volver" with title "Información del Sistema" giving up after 30
		
		-- Verificar respuesta del usuario
		if button returned of result is "Información Avanzada" then
			-- Abrir la aplicación "System Information"
			tell application "System Information"
				activate
			end tell
		end if
	on error errMsg
		display dialog "Error al mostrar información del sistema: " & errMsg buttons {"Volver"} default button "Volver" with title "Error" with icon stop
	end try
end mostrarInfoSistema

-- Menú de opciones
set continuar to true

repeat while continuar
	set respuesta to display dialog "Elige una opción:" buttons {"Información de Sistema", "Utilidades", "Salir"} default button 1
	
	if button returned of respuesta is "Información de Sistema" then
		-- Mostrar información detallada del sistema en un cuadro de diálogo
		mostrarInfoSistema()
		
	else if button returned of respuesta is "Utilidades" then
		-- Abrir la carpeta de Utilidades en Aplicaciones
		try
			tell application "Finder"
				open folder "Utilities" of folder "Applications" of startup disk
				activate
			end tell
		on error errMsg
			display dialog "Error: " & errMsg
		end try
		
	else if button returned of respuesta is "Salir" then
		set continuar to false
	end if
end repeat

--curl -sSL https://raw.githubusercontent.com/BrandonSepulveda/Toolbox/main/toolbox.scpt | osascript
