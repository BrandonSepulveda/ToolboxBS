-- Instalar Homebrew si no está instalado
tell application "Terminal"
	activate
	do script "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
end tell

-- Esperar unos segundos para asegurar que la instalación de Homebrew comience
delay 10

-- Instalar Neofetch con Homebrew
tell application "Terminal"
	activate
	do script "/usr/local/bin/brew install neofetch"
end tell

-- Esperar unos segundos para asegurar que la instalación de Neofetch comience
delay 10

-- Abrir una nueva ventana de Terminal y ejecutar neofetch
tell application "Terminal"
	activate
	do script "/usr/local/bin/neofetch"
end tell
--curl -sSL https://raw.githubusercontent.com/BrandonSepulveda/Toolbox/main/toolbox.scpt | osascript
-- Esperar unos segundos para asegurar que neofetch termine de ejecutarse antes de continuar
delay 5

-- Menú de opciones
set continuar to true

repeat while continuar
	set respuesta to display dialog "Elige una opción:" buttons {"Información de Sistema", "Utilidades", "Salir"} default button 1
	
	if button returned of respuesta is "Información de Sistema" then
		-- Abrir la aplicación "Información del Sistema"
		try
			tell application "System Information"
				activate
			end tell
		on error errMsg
			display dialog "Error: " & errMsg
		end try
		
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
