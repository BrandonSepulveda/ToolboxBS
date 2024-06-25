-- Abrir una nueva ventana de Terminal y ejecutar neofetch
tell application "Terminal"
	activate
	do script "neofetch"
end tell


-- Obtener información del sistema
set osVersion to system attribute "sysv"
set hostName to system attribute "HOSTNAME"
set kernelVersion to do shell script "uname -r"
set uptime to do shell script "uptime"
set packages to do shell script "brew list | wc -l | tr -d '[:space:]'"
set shellVersion to do shell script "echo $SHELL"
set resolution to do shell script "system_profiler SPDisplaysDataType | awk '/Resolution:/ {print $2, $3}'"
set desktopEnvironment to "Aqua" -- DE: Aqua para macOS
set windowManager to do shell script "defaults read com.apple.windowserver | grep -w 'Quartz' | head -n 1 | awk '{print $NF}'"
set wmTheme to "Blue (Dark)" -- Puedes ajustar este valor según tu preferencia
set terminalApp to "Apple_Terminal"
set terminalFont to do shell script "defaults read com.apple.Terminal 'Default Window Settings'"
set cpuInfo to do shell script "sysctl -n machdep.cpu.brand_string"
set gpuInfo to do shell script "system_profiler SPDisplaysDataType | grep -E 'Chipset Model:|VRAM'"
set memoryInfo to do shell script "top -l 1 | awk '/PhysMem/ {print $2, $6}'"
set totalMemory to do shell script "sysctl -n hw.memsize | awk '{print $0/1024/1024/1024\" GB\"}'"
set currentMemory to do shell script "vm_stat | awk '/Pages active/ {print $3 * 4096 / 1024 / 1024 \" MB\"}'"
set modelInfo to do shell script "sysctl -n hw.model"
set serialNumber to do shell script "system_profiler SPHardwareDataType | awk '/Serial/ {print $4}'"

-- Logo de Apple Unicode
set appleLogo to ""

-- Construir el mensaje con toda la información recolectada
set systemInfoText to appleLogo & " BrandonSepulveda@Jhons-MacBook-Pro.local" & return & ¬
	"----------------------------------------" & return & ¬
	"OS: macOS " & osVersion & return & ¬
	"Host: " & hostName & return & ¬
	"Kernel: " & kernelVersion & return & ¬
	"Uptime: " & uptime & return & ¬
	"Packages: " & packages & return & ¬
	"Shell: " & shellVersion & return & ¬
	"Resolution: " & resolution & return & ¬
	"DE: " & desktopEnvironment & return & ¬
	"WM: " & windowManager & return & ¬
	"WM Theme: " & wmTheme & return & ¬
	"Terminal: " & terminalApp & return & ¬
	"Terminal Font: " & terminalFont & return & ¬
	"CPU: " & cpuInfo & return & ¬
	"GPU: " & gpuInfo & return & ¬
	"Memory: " & memoryInfo & " (" & currentMemory & " / " & totalMemory & ")" & return & ¬
	"Model: " & modelInfo & return & ¬
	"Serial: " & serialNumber

-- Mostrar la información en un cuadro de diálogo
tell application "Finder"
	activate
	display dialog systemInfoText buttons {"OK"} default button "OK" with icon note
end tell
