# 🤝 Guía de Contribución - ToolboxBS

¡Gracias por tu interés en contribuir a ToolboxBS! Esta guía te ayudará a entender cómo puedes colaborar de manera efectiva en el proyecto.

## 📋 Tabla de Contenidos

- [Código de Conducta](#código-de-conducta)
- [Tipos de Contribuciones](#tipos-de-contribuciones)
- [Configuración del Entorno de Desarrollo](#configuración-del-entorno-de-desarrollo)
- [Estándares de Código](#estándares-de-código)
- [Proceso de Contribución](#proceso-de-contribución)
- [Guías Específicas](#guías-específicas)
- [Reportar Errores](#reportar-errores)
- [Solicitar Características](#solicitar-características)

## 📜 Código de Conducta

Este proyecto y todos los participantes están regidos por nuestro [Código de Conducta](CODE_OF_CONDUCT.md). Al participar, se espera que respetes este código.

## 🎯 Tipos de Contribuciones

Valoramos diferentes tipos de contribuciones:

### 🐛 Reportes de Errores
- Problemas en scripts de PowerShell
- Errores en la interfaz web
- Problemas de compatibilidad
- Fallos de seguridad

### ✨ Nuevas Características
- Nuevas herramientas y utilidades
- Mejoras en la interfaz de usuario
- Optimizaciones de rendimiento
- Características de accesibilidad

### 📚 Documentación
- Mejoras en README
- Documentación técnica
- Guías de usuario
- Comentarios en código

### 🔧 Mejoras de Código
- Refactorización
- Optimizaciones
- Corrección de estilo
- Mejoras de seguridad

## 🛠️ Configuración del Entorno de Desarrollo

### Prerrequisitos

- **Windows 10/11** (recomendado para testing completo)
- **PowerShell 5.1+** o **PowerShell 7+**
- **Git** para control de versiones
- **Editor de código** (VS Code recomendado)

### Configuración

1. **Fork y Clona el repositorio:**
   ```bash
   git clone https://github.com/TU_USUARIO/ToolboxBS.git
   cd ToolboxBS
   ```

2. **Instala PowerShell 7 (recomendado):**
   ```powershell
   winget install Microsoft.PowerShell
   ```

3. **Instala herramientas de desarrollo:**
   ```powershell
   # PSScriptAnalyzer para validación de código
   Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
   
   # Pester para testing (opcional)
   Install-Module -Name Pester -Scope CurrentUser -Force
   ```

4. **Configura VS Code (opcional):**
   ```bash
   # Instala extensiones útiles
   code --install-extension ms-vscode.powershell
   code --install-extension ms-vscode.vscode-json
   ```

## 📏 Estándares de Código

### PowerShell

#### Convenciones de Nomenclatura
```powershell
# Variables - PascalCase
$TempFilePath = "C:\Temp\file.txt"

# Funciones - Verb-Noun format
function Test-NetworkConnection { }
function Write-TimestampedLog { }

# Parámetros - PascalCase
param(
    [string]$InputPath,
    [switch]$Force
)
```

#### Estructura de Scripts
```powershell
<#
.SYNOPSIS
    Breve descripción del script

.DESCRIPTION
    Descripción detallada de la funcionalidad

.PARAMETER ParameterName
    Descripción del parámetro

.EXAMPLE
    Ejemplo de uso del script

.NOTES
    Author: Tu Nombre
    Version: 1.0
    Date: YYYY-MM-DD
#>

[CmdletBinding()]
param(
    # Parámetros aquí
)

# Configuración
$ErrorActionPreference = "Stop"

# Funciones auxiliares
function FunctionName {
    # Implementación
}

# Lógica principal
try {
    # Código principal
}
catch {
    # Manejo de errores
}
```

#### Mejores Prácticas

1. **Manejo de Errores:**
   ```powershell
   try {
       # Código que puede fallar
   }
   catch [System.Net.WebException] {
       # Manejo específico para errores de red
   }
   catch {
       # Manejo general de errores
       Write-Error "Error: $($_.Exception.Message)"
   }
   ```

2. **Validación de Parámetros:**
   ```powershell
   param(
       [Parameter(Mandatory)]
       [ValidateNotNullOrEmpty()]
       [string]$Path,
       
       [ValidateRange(1, 100)]
       [int]$RetryCount = 3
   )
   ```

3. **Logging y Output:**
   ```powershell
   function Write-TimestampedHost {
       param([string]$Message, [string]$Color = "White")
       $timestamp = Get-Date -Format "HH:mm:ss"
       Write-Host "[$timestamp] $Message" -ForegroundColor $Color
   }
   ```

### HTML/CSS/JavaScript

#### Convenciones
- Usa **indentación de 4 espacios**
- Nombres de clases en **kebab-case**
- IDs en **camelCase**
- Comentarios descriptivos

#### Estructura HTML
```html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Título Descriptivo</title>
    <!-- Estilos -->
</head>
<body>
    <!-- Contenido -->
    
    <!-- Scripts al final del body -->
</body>
</html>
```

## 🔄 Proceso de Contribución

### 1. Planificación
- Revisa issues existentes antes de crear uno nuevo
- Discute características importantes antes de implementarlas
- Considera el impacto en usuarios existentes

### 2. Desarrollo
```bash
# Crea una rama para tu feature/fix
git checkout -b feature/descripcion-corta
# o
git checkout -b fix/descripcion-del-problema

# Realiza tus cambios
# Asegúrate de seguir los estándares de código

# Prueba tu código localmente
```

### 3. Testing
```powershell
# Valida sintaxis de PowerShell
foreach ($file in Get-ChildItem -Filter "*.ps1") {
    $null = [System.Management.Automation.PSParser]::Tokenize(
        (Get-Content $file.FullName -Raw), [ref]$null
    )
}

# Ejecuta PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path . -Recurse
```

### 4. Commit y Push
```bash
# Commits descriptivos en español
git add .
git commit -m "feat: añade validación de conectividad a red"
git commit -m "fix: corrige manejo de errores en descarga"
git commit -m "docs: actualiza guía de instalación"

git push origin tu-rama
```

### 5. Pull Request
- Título descriptivo en español
- Descripción detallada de los cambios
- Referencias a issues relacionados
- Screenshots si hay cambios visuales

## 📝 Guías Específicas

### Añadir Nueva Herramienta

1. **Crea el script en `/procesos/`:**
   ```powershell
   # /procesos/nueva-herramienta.ps1
   <#
   .SYNOPSIS
       Descripción de la nueva herramienta
   #>
   
   # Tu implementación aquí
   ```

2. **Actualiza la interfaz web:**
   ```html
   <!-- Añade opción en ToolboxBSweb.html -->
   <div class="tool-item" onclick="toggleSelection(this, 'nueva-herramienta', 'categoria')">
       <div class="tool-item-content">
           <div class="tool-checkbox"></div>
           <span class="tool-item-text">Nueva Herramienta</span>
       </div>
   </div>
   ```

3. **Añade comando a JavaScript:**
   ```javascript
   // En ToolboxBSweb.html, sección powershellCommands
   'nueva-herramienta': `irm 'https://raw.githubusercontent.com/BrandonSepulveda/ToolboxBS/refs/heads/main/procesos/nueva-herramienta.ps1' | iex`
   ```

### Mejorar Herramienta Existente

1. Identifica el script en `/procesos/`
2. Mejora la funcionalidad manteniendo compatibilidad
3. Actualiza documentación si es necesario
4. Prueba exhaustivamente

## 🐛 Reportar Errores

### Información Requerida

```markdown
**Descripción del Error:**
Descripción clara y concisa del problema.

**Pasos para Reproducir:**
1. Ve a '...'
2. Haz clic en '....'
3. Ejecuta comando '....'
4. Ver error

**Comportamiento Esperado:**
Descripción de lo que esperabas que pasara.

**Screenshots:**
Si aplica, añade screenshots para explicar el problema.

**Información del Sistema:**
- OS: [ej. Windows 11 22H2]
- PowerShell Version: [ej. 7.3.6]
- ToolboxBS Version: [ej. v2.1]

**Información Adicional:**
Cualquier otro contexto sobre el problema.
```

## ✨ Solicitar Características

### Template para Feature Request

```markdown
**¿Tu solicitud está relacionada con un problema? Describe:**
Descripción clara del problema. Ej. Me frustra cuando [...]

**Describe la solución que te gustaría:**
Descripción clara y concisa de lo que quieres que pase.

**Describe alternativas que hayas considerado:**
Descripción de soluciones alternativas que hayas considerado.

**Información adicional:**
Añade cualquier otro contexto o screenshots sobre la solicitud.
```

## 🏷️ Convenciones de Commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` nueva característica
- `fix:` corrección de error
- `docs:` cambios en documentación
- `style:` cambios de formato (sin cambios funcionales)
- `refactor:` refactorización de código
- `test:` añadir o modificar tests
- `chore:` tareas de mantenimiento

### Ejemplos:
```bash
feat: añade función de optimización de RAM
fix: corrige error en descarga de archivos grandes
docs: actualiza README con nuevas instrucciones
style: aplica formato consistente a scripts PS1
refactor: mejora estructura de funciones auxiliares
```

## 🔍 Revisión de Código

### Criterios de Revisión

- **Funcionalidad:** ¿El código hace lo que debe hacer?
- **Legibilidad:** ¿Es fácil de entender?
- **Mantenibilidad:** ¿Es fácil de mantener y extender?
- **Rendimiento:** ¿Es eficiente?
- **Seguridad:** ¿Maneja datos sensibles apropiadamente?
- **Compatibilidad:** ¿Funciona en diferentes versiones de Windows?

## 📞 Contacto

- **Issues:** [GitHub Issues](https://github.com/BrandonSepulveda/ToolboxBS/issues)
- **Discussions:** [GitHub Discussions](https://github.com/BrandonSepulveda/ToolboxBS/discussions)
- **Email:** jhonvaldessepulveda@gmail.com

## 📄 Licencia

Al contribuir a ToolboxBS, aceptas que tus contribuciones serán licenciadas bajo la [Licencia AGPL v3.0](LICENSE).

---

¡Gracias por contribuir a ToolboxBS! 🎉

## 👥 Autores y Colaboradores

### Autor Principal
- **Brandon Sepulveda** - [GitHub](https://github.com/BrandonSepulveda)

### Colaboradores
- **TYBYTEPRO** - Colaborador
