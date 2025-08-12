
# 🛠️ ToolboxBS - Suite Integral de Optimización y Mantenimiento para Windows

![Descargas Totales](https://img.shields.io/github/downloads/BrandonSepulveda/ToolboxBS/total?label=Descargas%20Totales&style=for-the-badge&color=000000&labelColor=ffffff)
[![Última Versión](https://img.shields.io/github/v/release/BrandonSepulveda/ToolboxBS?label=Última%20Versión&style=for-the-badge&color=000000&labelColor=ffffff)](https://github.com/BrandonSepulveda/ToolboxBS/releases)
![Lenguaje Principal](https://img.shields.io/github/languages/top/BrandonSepulveda/ToolboxBS?style=for-the-badge&color=000000&labelColor=ffffff)
[![Licencia](https://img.shields.io/github/license/BrandonSepulveda/ToolboxBS?style=for-the-badge&label=Licencia&color=000000&labelColor=ffffff)](https://github.com/BrandonSepulveda/ToolboxBS/blob/main/LICENSE)
[![Validación de Código](https://img.shields.io/github/actions/workflow/status/BrandonSepulveda/ToolboxBS/validate.yml?label=Validación&style=for-the-badge)](https://github.com/BrandonSepulveda/ToolboxBS/actions)

---

## 📋 Descripción General

**ToolboxBS** es una potente y amigable utilidad de mantenimiento y optimización para sistemas Windows, desarrollada con PowerShell y WPF. Proporciona una interfaz moderna e intuitiva que reúne herramientas esenciales del sistema, diagnósticos y funciones de optimización en una sola aplicación centralizada.

Diseñada tanto para usuarios ocasionales como para profesionales de TI, ToolboxBS ofrece un conjunto completo de herramientas para mantener, solucionar problemas y optimizar sistemas Windows.

![Vista principal de ToolboxBS](https://github.com/user-attachments/assets/2288413e-2566-41a1-a33b-43945ff0a2ce)

---

## 🚀 Características Principales

### 🖥️ Interfaz de Usuario Moderna
- **Diseño elegante y responsivo** con tema oscuro/claro personalizable
- **Navegación intuitiva** con herramientas categorizadas
- **Estética moderna** con esquinas redondeadas y animaciones fluidas
- **Interfaz web** disponible para acceso desde cualquier navegador

### 📊 Información del Sistema
Obtén un informe detallado de tu sistema con solo un clic:

- ✅ **Versión de Windows**: Consulta la versión exacta de tu sistema operativo
- ✅ **Procesador**: Conoce el modelo y las especificaciones de tu CPU
- ✅ **Arquitectura del Sistema**: Verifica si tu sistema es de 32-bit o 64-bit
- ✅ **RAM Instalada**: Revisa la cantidad de memoria RAM disponible
- ✅ **Capacidad del Disco**: Consulta el tamaño total y espacio libre disponible
- ✅ **Información de la GPU**: Detalles sobre todas las tarjetas gráficas instaladas

### 📥 Gestor de Aplicaciones
Facilita la instalación de aplicaciones empresariales y de TI esenciales:

- ✅ Instala herramientas importantes como HP Support Assistant, Lenovo Vantage, TeamViewer, y muchas más
- ✅ Utiliza Chocolatey para gestionar la instalación de forma eficiente
- ✅ Actualiza fácilmente aplicaciones existentes
- ✅ Descarga automática de drivers específicos por fabricante

### 🔧 Verificación y Reparación del Sistema
Mantén tu sistema funcionando sin problemas:

- ✅ **Puntos de Restauración**: Genera automáticamente puntos de restauración para proteger tu sistema
- ✅ **Reparación del Sistema**: Utiliza herramientas como SFC y DISM para escanear y reparar archivos del sistema
- ✅ **Análisis de Pantallazos Azules**: Diagnóstico detallado de errores críticos del sistema
- ✅ **Diagnóstico de Batería**: Verifica la salud de la batería y genera informes detallados
- ✅ **Gestión de Controladores**: Genera informes y gestiona los drivers instalados
- ✅ **Reparación de Red**: Ejecuta comandos para solucionar problemas comunes de red

### 🧹 Limpieza y Optimización
Optimiza tu sistema eliminando archivos innecesarios y mejorando el rendimiento:

- ✅ **Limpieza de Temporales**: Elimina archivos temporales para liberar espacio en disco
- ✅ **Optimización de RAM**: Utiliza herramientas avanzadas para gestionar eficientemente la memoria
- ✅ **Configuración de Servicios**: Optimiza servicios de Windows para mejor rendimiento
- ✅ **Tweaks de Registro**: Aplicaciones seguras de optimizaciones del registro

---

## ⚠️ Licenciamiento: Por Favor, Lee con Atención

Este proyecto se distribuye bajo un **modelo de licencia dual**. Puedes elegir usarlo bajo una de las siguientes dos licencias:

### 1. Licencia Comunitaria (AGPL v3.0)
Puedes usar ToolboxBS de forma gratuita bajo los términos de la **Licencia Pública General de Affero GNU v3.0 (AGPL-3.0)**. El texto completo de la licencia está disponible en el archivo `LICENSE`. Esta opción es ideal para uso personal, estudiantes y proyectos de código abierto.

### 2. Licencia Comercial
Si deseas utilizar ToolboxBS en un **entorno comercial, gubernamental o corporativo**, o si los términos de la AGPL-3.0 no se ajustan a tu proyecto (por ejemplo, en software propietario), **debes adquirir una licencia comercial**.

El uso de este software en un contexto comercial sin una licencia válida está estrictamente prohibido.

**Para consultar y adquirir una licencia comercial, por favor contacta al autor:**
**Jhon Brandon Sepúlveda Valdés** en **jhonvaldessepulveda@gmail.com**

---

## ⚡ Instalación y Ejecución

### 🔥 Ejecución Rápida (Recomendado)

Para ejecutar ToolboxBS, abre **PowerShell como Administrador** y ejecuta el siguiente comando:

```powershell
irm "https://cutt.ly/ToolboxBS" | iex
```

*Comando alternativo:*
```powershell
irm "https://brandonsepulveda.github.io/Tool" | iex
```

### 📦 Descarga Directa

También puedes descargar el ejecutable desde las releases:

```powershell
# Descarga la última versión
Invoke-WebRequest -Uri "https://github.com/BrandonSepulveda/ToolboxBS/releases/latest/download/ToolboxBS.exe" -OutFile "ToolboxBS.exe"

# Ejecuta como administrador
Start-Process -FilePath "ToolboxBS.exe" -Verb RunAs
```

### 🌐 Interfaz Web

Accede a la interfaz web moderna desde tu navegador:
- **URL Principal**: [brandonsepulveda.github.io/ToolboxBSweb](https://brandonsepulveda.github.io/ToolboxBSweb)
- **URL Alternativa**: [Interfaz Web Local](./ToolboxBSweb.html)

---

## 💻 Requisitos del Sistema

### Mínimos
- **Sistema Operativo**: Windows 10 (versión 1803 o superior)
- **PowerShell**: 5.1 o superior
- **RAM**: 4 GB
- **Espacio en Disco**: 100 MB libres
- **Permisos**: Administrador (requerido para la mayoría de funciones)

### Recomendados
- **Sistema Operativo**: Windows 11 (última versión)
- **PowerShell**: 7.3 o superior
- **RAM**: 8 GB o más
- **Espacio en Disco**: 500 MB libres
- **Internet**: Conexión estable para descargas y actualizaciones

---

## 🎯 Casos de Uso

| Para Usuarios Domésticos | Para Profesionales de TI | Para Entornos Empresariales |
| :--- | :--- | :--- |
| Mantenimiento y limpieza rutinaria | Diagnósticos rápidos para sistemas de clientes | Optimización estandarizada de sistemas |
| Solución de problemas comunes | Instalación en lote de aplicaciones esenciales | Procedimientos de mantenimiento consistentes |
| Optimización del rendimiento | Reparación y recuperación del sistema | Gestión eficiente de software |
| Limpieza de archivos basura | Análisis de problemas de hardware | Configuración masiva de equipos |

---

## 🔒 Características de Seguridad

- ✅ **Código Abierto**: Todo el código está disponible para revisión
- ✅ **Validación Automática**: GitHub Actions valida cada cambio de código
- ✅ **Verificación de Integridad**: Los archivos descargados son verificados antes de la ejecución
- ✅ **Puntos de Restauración**: Se crean automáticamente antes de cambios importantes
- ✅ **Logging Detallado**: Registro completo de todas las operaciones realizadas
- ✅ **Manejo Seguro de Errores**: Protección contra fallos inesperados

---

## 🛠️ Desarrollo y Contribución

### Para Desarrolladores

```bash
# Clona el repositorio
git clone https://github.com/BrandonSepulveda/ToolboxBS.git
cd ToolboxBS

# Instala PowerShell 7 (recomendado)
winget install Microsoft.PowerShell

# Instala herramientas de desarrollo
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
```

### Estructura del Proyecto

```
ToolboxBS/
├── 📁 .github/          # Configuración de GitHub Actions
│   └── workflows/       # Flujos de trabajo CI/CD
├── 📁 procesos/         # Scripts de PowerShell para diferentes funciones
│   ├── infosystem.ps1   # Información del sistema
│   ├── performance.bat  # Optimización de rendimiento
│   └── ...
├── 📄 ToolboxBS.ps1     # Script principal
├── 📄 Tool.ps1          # Launcher mejorado
├── 📄 ToolboxBSweb.html # Interfaz web
├── 📄 index.html        # Página de presentación
├── 📄 README.md         # Este archivo
├── 📄 CHANGELOG.md      # Historial de cambios
├── 📄 CONTRIBUTING.md   # Guía de contribución
└── 📄 LICENSE           # Licencia del proyecto
```

### Estándares de Código

- **PowerShell**: Sigue las convenciones de [PowerShell Best Practices](https://docs.microsoft.com/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines)
- **HTML/CSS/JS**: Indentación de 4 espacios, nombres en kebab-case
- **Commits**: Formato [Conventional Commits](https://www.conventionalcommits.org/)

---

## 🧪 Testing y Validación

El proyecto incluye validación automática mediante GitHub Actions:

- ✅ **Sintaxis PowerShell**: Validación con PSScriptAnalyzer
- ✅ **Validación HTML**: Verificación de estructura y estándares
- ✅ **Escaneo de Seguridad**: Detección de patrones peligrosos
- ✅ **Verificación de Enlaces**: Comprobación de URLs externas

Para ejecutar las validaciones localmente:

```powershell
# Validar sintaxis PowerShell
Invoke-ScriptAnalyzer -Path . -Recurse

# Ejecutar pruebas básicas
.\scripts\run-tests.ps1
```

---

## 📊 Estadísticas del Proyecto

- **🌟 Estrellas**: [![GitHub stars](https://img.shields.io/github/stars/BrandonSepulveda/ToolboxBS)](https://github.com/BrandonSepulveda/ToolboxBS/stargazers)
- **🍴 Forks**: [![GitHub forks](https://img.shields.io/github/forks/BrandonSepulveda/ToolboxBS)](https://github.com/BrandonSepulveda/ToolboxBS/network)
- **🐛 Issues**: [![GitHub issues](https://img.shields.io/github/issues/BrandonSepulveda/ToolboxBS)](https://github.com/BrandonSepulveda/ToolboxBS/issues)
- **📈 Commits**: [![GitHub commits](https://img.shields.io/github/commit-activity/m/BrandonSepulveda/ToolboxBS)](https://github.com/BrandonSepulveda/ToolboxBS/commits)

---

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! Si quieres ayudar a mejorar ToolboxBS, por favor sigue estos pasos:

1. **Lee la [Guía de Contribución](CONTRIBUTING.md)** para entender nuestros estándares
2. **Haz un Fork** del repositorio
3. Crea una nueva **rama** para tu función (`git checkout -b feature/AmazingFeature`)
4. **Haz Commit** de tus cambios siguiendo [Conventional Commits](https://www.conventionalcommits.org/)
5. **Haz Push** a la rama (`git push origin feature/AmazingFeature`)
6. Abre un **Pull Request** con descripción detallada

### Tipos de Contribuciones Buscadas

- 🐛 **Reportes de errores** con pasos para reproducir
- ✨ **Nuevas características** que mejoren la funcionalidad
- 📚 **Mejoras en documentación** y guías de usuario
- 🔧 **Optimizaciones de código** y refactorización
- 🌐 **Traducciones** a otros idiomas
- 🧪 **Tests** y validaciones adicionales

---

## 📝 Changelog

Para ver el historial completo de cambios, consulta el [CHANGELOG.md](CHANGELOG.md).

### Última Versión (v2.1.0)
- ✨ Nueva interfaz web interactiva
- 🔧 Mejoras en el sistema de validación
- 🐛 Corrección de errores en descarga de archivos
- 🔒 Mejoras de seguridad en scripts

---

## 🔗 Enlaces Útiles

| Recurso | Enlace |
|---------|--------|
| 🌐 **Sitio Web** | [brandonsepulveda.github.io](https://brandonsepulveda.github.io/) |
| 📱 **Interfaz Web** | [ToolboxBS Web](https://brandonsepulveda.github.io/ToolboxBSweb) |
| 📚 **Documentación** | [Documentación Técnica](https://brandonsepulveda.github.io/Documentacion.html) |
| 📥 **Descargas** | [Releases](https://github.com/BrandonSepulveda/ToolboxBS/releases) |
| 🐛 **Reportar Bug** | [Issues](https://github.com/BrandonSepulveda/ToolboxBS/issues) |
| 💬 **Discusiones** | [GitHub Discussions](https://github.com/BrandonSepulveda/ToolboxBS/discussions) |

---

## 🔗 Conecta con el Autor

| Portafolio | LinkedIn | Instagram |
| :---: | :---: | :---: |
| [![portfolio](https://img.shields.io/badge/Mi_Portafolio-000?style=for-the-badge&logo=ko-fi&logoColor=white)](https://brandonsepulveda.github.io/) | [![linkedin](https://img.shields.io/badge/linkedin-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/jbrandonsepulveda/?originalSubdomain=co) | [![Instagram](https://img.shields.io/badge/Instagram-E4405F?style=for-the-badge&logo=instagram&logoColor=white)](https://www.instagram.com/brandonsepulveda_66) |

---

## 📄 Licencia y Copyright

Copyright © 2024-2025 Jhon Brandon Sepúlveda Valdés. Todos los derechos reservados.

Este proyecto está licenciado bajo la [GNU Affero General Public License v3.0](LICENSE) para uso comunitario.
Para uso comercial, contacta al autor para obtener una licencia comercial.

---

## ⭐ Agradecimientos

- **Comunidad de PowerShell** por las excelentes herramientas y recursos
- **Usuarios y contribuidores** que han probado y mejorado ToolboxBS
- **Proyectos de código abierto** que han inspirado características específicas
- **Microsoft** por proporcionar PowerShell y las APIs de Windows

---

## 🚀 ¿Te Gusta el Proyecto?

Si ToolboxBS te ha sido útil, considera:

- ⭐ **Darle una estrella** a este repositorio
- 🍴 **Hacer un fork** para tus propios experimentos
- 🐛 **Reportar bugs** o sugerir mejoras
- 📢 **Compartir** con otros que puedan beneficiarse
- ☕ **Apoyar el desarrollo** (información en el perfil del autor)

<br>

<div align="center">

**ToolboxBS** - Desarrollado con ❤️ por [Brandon Sepulveda](https://brandonsepulveda.github.io/)

*La Solución Integral para la Optimización de tu Sistema Windows* 💻✨

</div>
