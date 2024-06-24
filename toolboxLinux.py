#!/usr/bin/env python3

import subprocess

# Instalar Python 3 si no está instalado
try:
    # Verificar si Python 3 está instalado
    subprocess.run(["python3", "--version"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
except subprocess.CalledProcessError:
    # Si no está instalado, intenta instalarlo (ejemplo para Ubuntu / Debian)
    print("Python 3 no está instalado. Instalando...")
    subprocess.run(["sudo", "apt", "update"], check=True)
    subprocess.run(["sudo", "apt", "install", "-y", "python3"], check=True)
    
import tkinter as tk
from tkinter import messagebox
import subprocess

# Función para obtener la información del sistema
def obtener_informacion_sistema():
    # Inicializar la cadena de información del sistema
    info_sistema = ""

    # Comandos para obtener la información del sistema
 comandos = [
    "uname -a",                                     # Información del kernel y sistema operativo
    "lsb_release -a",                               # Información de distribución y versión del sistema operativo
    "sudo dmidecode -s system-manufacturer",        # Marca del equipo
    "sudo dmidecode -s system-product-name",         # Modelo del equipo
    "sudo dmidecode -s system-serial-number",       # Número de serie del equipo
    "sudo dmidecode -s bios-version",               # Versión de BIOS
    "sudo dmidecode --type memory | grep -i manufacturer || echo 'No disponible'",  # Marca de las memorias RAM
    "sudo dmidecode --type memory | grep -i speed || echo 'No disponible'",         # Velocidad de las memorias RAM
    "df -h",                                        # Espacio en disco disponible y ocupado
    "sudo smartctl -a /dev/sda || echo 'No disponible'",                            # Información SMART del disco (reemplazar /dev/sda con tu disco)
    "sudo lshw -C display | grep -i product || echo 'No disponible'",               # Información de la tarjeta de video
    "ls -l /var/log/installer/syslog || echo 'No disponible'",                      # Verifica si el archivo syslog existe
    "sudo zgrep 'installation' /var/log/installer/syslog* | head -n 1 || echo 'No disponible'",   # Fecha de instalación del sistema
    "sensors"                                      # Información de la temperatura del equipo
]

    # Ejecutar cada comando y capturar la salida
    for comando in comandos:
        resultado = subprocess.run(comando, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        info_sistema += f"*** {comando} ***\n"
        info_sistema += resultado.stdout + "\n"
        if resultado.stderr:
            info_sistema += "Error: " + resultado.stderr + "\n"
        info_sistema += "\n"

    # Mostrar la información del sistema en una ventana emergente
    mostrar_ventana_info(info_sistema)

# Función para mostrar la información del sistema en una ventana emergente
def mostrar_ventana_info(info):
    # Crear una nueva ventana
    ventana_info = tk.Toplevel()
    ventana_info.title("Información del Sistema")

    # Organizar la información del sistema
    info_organizada = ""
    lineas = info.splitlines()
    for linea in lineas:
        if linea.startswith("***"):
            info_organizada += f"\n{linea}\n"
        else:
            info_organizada += f"{linea}\n"

    # Crear un widget de texto para mostrar la información
    texto_info = tk.Text(ventana_info, wrap=tk.WORD, padx=10, pady=10)
    texto_info.insert(tk.END, info_organizada)
    texto_info.config(state=tk.DISABLED)  # Deshabilitar la edición del texto
    texto_info.pack(expand=True, fill=tk.BOTH)

    # Botón para cerrar la ventana
    boton_cerrar = tk.Button(ventana_info, text="Cerrar", command=ventana_info.destroy)
    boton_cerrar.pack(pady=10)

# Función para instalar aplicaciones seleccionadas
def instalar_aplicaciones():
    seleccionados = [var_chrome.get(), var_anydesk.get()]

    if any(seleccionados):
        apps_instalar = []
        if var_chrome.get():
            apps_instalar.append("google-chrome-stable")
        if var_anydesk.get():
            apps_instalar.append("anydesk")

        # Instalar las aplicaciones seleccionadas
        instalar_comandos = ["sudo apt-get update"]
        for app in apps_instalar:
            instalar_comandos.append(f"sudo apt-get install -y {app}")

        comando_instalacion = " && ".join(instalar_comandos)
        resultado = subprocess.run(comando_instalacion, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        if resultado.returncode == 0:
            messagebox.showinfo("Instalación completada", "Las aplicaciones han sido instaladas correctamente.")
        else:
            messagebox.showerror("Error de instalación", f"Hubo un error durante la instalación:\n{resultado.stderr}")
    else:
        messagebox.showwarning("Nada seleccionado", "Por favor selecciona al menos una aplicación para instalar.")

# Crear la ventana principal
ventana_principal = tk.Tk()
ventana_principal.title("Toolbox")

# Marco para la información del sistema
marco_info = tk.LabelFrame(ventana_principal, text="Información del Sistema")
marco_info.pack(padx=20, pady=20, fill=tk.BOTH, expand=True)

# Botón para obtener la información del sistema
boton_obtener_info = tk.Button(marco_info, text="Obtener Información del Sistema", command=obtener_informacion_sistema)
boton_obtener_info.pack(pady=20)

# Marco para las aplicaciones
marco_apps = tk.LabelFrame(ventana_principal, text="Descargar Aplicaciones")
marco_apps.pack(padx=20, pady=20, fill=tk.BOTH, expand=True)

# Variables para las aplicaciones seleccionables
var_chrome = tk.BooleanVar()
var_anydesk = tk.BooleanVar()

# Checkbuttons para las aplicaciones
check_chrome = tk.Checkbutton(marco_apps, text="Google Chrome", variable=var_chrome)
check_chrome.pack(anchor=tk.W)
check_anydesk = tk.Checkbutton(marco_apps, text="AnyDesk", variable=var_anydesk)
check_anydesk.pack(anchor=tk.W)

# Botón para descargar e instalar
boton_descargar_instalar = tk.Button(marco_apps, text="Descargar e Instalar", command=instalar_aplicaciones)
boton_descargar_instalar.pack(pady=20)

# Iniciar el bucle principal de la ventana
ventana_principal.mainloop()
#wget -O - https://raw.githubusercontent.com/BrandonSepulveda/Toolbox/main/toolboxLinux.py | python3
