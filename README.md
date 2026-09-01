# 🛠️ ToolboxBS — Suite Integral de Optimización y Mantenimiento para Windows

![Descargas Totales](https://img.shields.io/github/downloads/BrandonSepulveda/ToolboxBS/total?label=Descargas%20Totales&style=for-the-badge&color=000000&labelColor=ffffff)
[![Última Versión](https://img.shields.io/github/v/release/BrandonSepulveda/ToolboxBS?label=Última%20Versión&style=for-the-badge&color=000000&labelColor=ffffff)](https://github.com/BrandonSepulveda/ToolboxBS/releases)
![Lenguaje Principal](https://img.shields.io/github/languages/top/BrandonSepulveda/ToolboxBS?style=for-the-badge&color=000000&labelColor=ffffff)
[![Licencia](https://img.shields.io/github/license/BrandonSepulveda/ToolboxBS?style=for-the-badge&label=Licencia&color=000000&labelColor=ffffff)](https://github.com/BrandonSepulveda/ToolboxBS/blob/main/LICENSE)

---

## 📋 Qué es

**ToolboxBS** es la navaja suiza de Windows: **257 herramientas** de reparación, limpieza, rendimiento, seguridad, diagnóstico de red e instalación de software, en una sola aplicación nativa hecha con PowerShell y WPF.

Está pensada tanto para el usuario que quiere mantener su equipo como para el técnico que atiende decenas de máquinas al día y necesita hacer siempre lo mismo, rápido y sin olvidar pasos.

| Módulo | Herramientas | Para qué sirve |
| :--- | ---: | :--- |
| 🔧 Reparación | 31 | Componentes de Windows, red, impresión, audio, arranque, controladores |
| 🧹 Limpieza | 19 | Recuperar espacio sin tocar archivos personales |
| ⚡ Rendimiento | 26 | Energía, efectos, servicios, arranque, telemetría, bloatware |
| 🛡️ Seguridad | 18 | Defender, cuentas, persistencias, cifrado, endurecimiento |
| 🌐 Red | 14 | IP, DNS, WiFi, velocidad, dispositivos de la LAN, VPN |
| 📊 Información | 14 | Reportes de hardware, discos, claves, inventario, garantía |
| 🧰 Herramientas | 48 | Consolas nativas y utilidades de técnico |
| 📦 Aplicaciones | 87 | Instalación desatendida vía winget |

---

## ⚡ Ejecución rápida

Abre **PowerShell como Administrador** y ejecuta:

```powershell
irm "https://cutt.ly/ToolboxBS" | iex
```

*Alternativa:*

```powershell
irm "https://brandonsepulveda.github.io/Tool" | iex
```

También puedes descargar el `.ps1` firmado desde [Releases](https://github.com/BrandonSepulveda/ToolboxBS/releases) y ejecutarlo directamente. Requiere Windows 10/11; se auto-eleva a Administrador si hace falta.

### 🌐 ¿Prefieres no descargar nada?

La [**versión web**](https://brandonsepulveda.github.io/ToolboxBSweb.html) es un producto independiente: marcas las herramientas que necesitas, la página arma un `.bat` en tu navegador y tú lo ejecutas. No instala nada, no envía datos a ningún servidor y puedes leer el script completo antes de correrlo.

📖 [**Documentación completa**](https://brandonsepulveda.github.io/Documentacion.html) — qué hace cada una de las 257 herramientas.

---

## ✨ Novedades de la v4

- **Consola integrada.** La salida de cada tarea llega en vivo a la aplicación, coloreada por tipo de línea, y queda guardada en un registro por sesión. Antes cada tarea abría su propia ventana y la salida se perdía al cerrarla.
- **Dashboard en tiempo real.** CPU, memoria, disco y tiempo encendido, más ocho comprobaciones de salud: activación, Defender, firewall, antigüedad del último parche, espacio libre, salud SMART, punto de restauración y reinicio pendiente.
- **Reversión de cambios.** 25 herramientas traen su propia acción de deshacer, y todo lo que escribe en el registro hace un `reg export` antes de tocar nada.
- **Rutinas de un clic.** 11 flujos armados para los casos que más se repiten: «El equipo va lento», «Recién formateado», «Después de un virus», «Antes de formatear», «No hay internet»…
- **Búsqueda global.** `Ctrl+F` busca en las 257 herramientas sin importar el módulo.
- **Perfiles.** Guarda tu selección en un `.json` y cárgala en el siguiente equipo.
- **Modo consola.** La misma lógica sin abrir la ventana, para automatizar.
- **Confirmación de riesgo.** Las 13 acciones difíciles de deshacer piden confirmación mostrando la lista exacta antes de ejecutar.

---

## 🖥️ Modo consola

```powershell
# Listar las 257 herramientas con su id y categoría
.\ToolboxBS.ps1 -ListTools

# Ejecutar una o varias sin interfaz gráfica
.\ToolboxBS.ps1 -RunTool clean-temp,net-info

# Volcar el catálogo a JSON (metadata)
.\ToolboxBS.ps1 -ExportCatalog catalogo.json

# Volcar el catálogo con el código de cada herramienta
.\ToolboxBS.ps1 -ExportCatalog catalogo.full.json -WithCode

# Validar el script después de editarlo
.\ToolboxBS.ps1 -SelfTest
```

---

## 🧩 Arquitectura: el catálogo es la única fuente de verdad

Desde la v4 las herramientas **son datos, no interfaz**. Cada una es un objeto creado con la función `T`:

```powershell
T -Id 'clean-temp' -Cat 'clean' -Icon 'E74D' -Risk 'safe' -Run 'inline' `
    -Name 'Purgar temporales' `
    -Desc 'Temp de usuario y de Windows, Prefetch e informes de errores' -Code @'
HR "LIMPIEZA DE ARCHIVOS TEMPORALES"
$tot = 0
$tot += Purge-Folder $env:TEMP "Temp del usuario"
$tot += Purge-Folder "$env:SystemRoot\Temp" "Temp de Windows"
HR ("TOTAL LIBERADO: " + (Human $tot))
'@
```

La interfaz, la búsqueda, el contador, los perfiles y la navegación se generan solos a partir de esa lista. **Agregar una utilidad es agregar un objeto**: no se toca el XAML.

| Campo | Valores | Para qué |
| :--- | :--- | :--- |
| `Id` | kebab-case único | Lo que acepta `-RunTool` |
| `Cat` | `repair` `clean` `perf` `sec` `net` `info` `tools` `apps` | En qué módulo aparece |
| `Risk` | `safe` `care` `danger` | `danger` pide confirmación antes de ejecutar |
| `Run` | `inline` `term` | Consola integrada, o ventana propia si es interactiva |
| `Code` | PowerShell | Lo que se ejecuta |
| `Revert` | PowerShell (opcional) | Acción de deshacer |

El **preludio** —un bloque de funciones comunes: `Step`, `OK`, `WARN`, `ERR`, `ROW`, `Human`, `Set-Reg`, `Backup-Reg`, `Purge-Folder`— se inyecta en cada tarea, así que el código de cada herramienta se lee casi como pseudocódigo.

Ese mismo catálogo alimenta la versión web y la documentación mediante `-ExportCatalog`, para que las tres cosas no se contradigan nunca.

### Cómo agregar una herramienta

1. Añade una llamada a `T` en el bloque `$Global:Catalog` de `src/ToolboxBS.ps1`.
2. Valida: `.\src\ToolboxBS.ps1 -SelfTest` — comprueba ids duplicados, que el código compile y que la interfaz se construya.
3. Pruébala aislada: `.\src\ToolboxBS.ps1 -RunTool tu-id`.
4. Abre un Pull Request.

Está todo detallado en [CONTRIBUTING.md](CONTRIBUTING.md), incluidas las funciones
del preludio que puedes usar y las reglas que evitan sustos.

---

## 📁 Dónde quedan los archivos

Todo lo que genera se guarda en tu carpeta de Documentos, nunca en rutas ocultas:

| Carpeta | Contenido |
| :--- | :--- |
| `Documentos\ToolboxBS\logs` | Registro completo de cada sesión |
| `Documentos\ToolboxBS\reportes` | Informes HTML y CSV: equipo, software, eventos, drivers, WiFi, espacio |
| `Documentos\ToolboxBS\backups` | Respaldos del registro, drivers, claves de BitLocker y de producto |
| `Documentos\ToolboxBS\perfiles` | Tus selecciones guardadas |

---

## 🔐 Transparencia

ToolboxBS pide privilegios de Administrador porque casi todo lo que hace los necesita. A cambio:

- **Puedes leer lo que va a ejecutar antes de ejecutarlo.** Clic derecho en cualquier tarjeta → *Ver el código que ejecuta*. En la versión web, el enlace «ver código» de cada tarjeta.
- **Todo queda registrado.** Cada sesión deja su log completo en disco.
- **No hay telemetría.** La herramienta no envía nada a ningún servidor propio. Las descargas que hace (Sysinternals, NirSoft, winget) van directo a su origen oficial y están a la vista en el código.
- **El `.ps1` de las releases está firmado digitalmente.** Verifícalo con `Get-AuthenticodeSignature .\ToolboxBS.ps1`.

---

## ⚠️ Licenciamiento: por favor, lee con atención

Este proyecto se distribuye bajo un **modelo de licencia dual**. Puedes elegir usarlo bajo una de las siguientes dos licencias:

### 1. Licencia Comunitaria (AGPL v3.0)

Puedes usar ToolboxBS de forma gratuita bajo los términos de la **Licencia Pública General de Affero GNU v3.0 (AGPL-3.0)**. El texto completo está en el archivo `LICENSE`. Esta opción es ideal para uso personal, estudiantes y proyectos de código abierto.

### 2. Licencia Comercial

Si deseas utilizar ToolboxBS en un **entorno comercial, gubernamental o corporativo**, o si los términos de la AGPL-3.0 no se ajustan a tu proyecto (por ejemplo, en software propietario), **debes adquirir una licencia comercial**.

El uso de este software en un contexto comercial sin una licencia válida está estrictamente prohibido.

**Para consultar y adquirir una licencia comercial, contacta al autor:**
**Jhon Brandon Sepúlveda Valdés** — **jhonvaldessepulveda@gmail.com**

---

## 🚀 Casos de uso

| Para usuarios domésticos | Para profesionales de TI | Para entornos empresariales |
| :--- | :--- | :--- |
| Mantenimiento y limpieza rutinaria | Diagnóstico rápido de equipos de clientes | Optimización estandarizada |
| Solución de problemas comunes | Respaldo de drivers y claves antes de formatear | Procedimientos consistentes |
| Optimización del rendimiento | Reporte HTML para entregar al cliente | Mantenimiento programado |
| Instalación de software post-formateo | Perfiles reutilizables entre equipos | Inventario de software |

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas.

1. Haz un **fork** del repositorio.
2. Crea una **rama** (`git checkout -b feature/mi-herramienta`).
3. Añade tu herramienta al catálogo y valida con `-SelfTest`.
4. Haz **commit** y **push**.
5. Abre un **Pull Request**.

---

## 🔗 Conecta con el autor

| Portafolio | LinkedIn | Instagram |
| :---: | :---: | :---: |
| [![portfolio](https://img.shields.io/badge/Mi_Portafolio-000?style=for-the-badge&logo=ko-fi&logoColor=white)](https://brandonsepulveda.github.io/) | [![linkedin](https://img.shields.io/badge/linkedin-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/jbrandonsepulveda/?originalSubdomain=co) | [![Instagram](https://img.shields.io/badge/Instagram-E4405F?style=for-the-badge&logo=instagram&logoColor=white)](https://www.instagram.com/brandonsepulveda_66) |

<br>

**ToolboxBS** — Desarrollado por [Brandon Sepulveda](https://brandonsepulveda.github.io/) 💻✨
