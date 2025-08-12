# 📝 Changelog - ToolboxBS

Todos los cambios notables de este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto sigue [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### ✨ Añadido
- Validación de integridad de archivos descargados
- Logging con timestamps en scripts de PowerShell
- Lógica de reintentos para descargas fallidas
- Verificación de conectividad a internet
- Manejo de errores mejorado con códigos de salida específicos
- Documentación completa de contribución
- GitHub Actions para validación automática de código
- Verificación de sintaxis PowerShell en CI/CD
- Validación básica de archivos HTML
- Escaneo de seguridad automatizado
- Verificación de enlaces externos

### 🔧 Cambiado
- Refactorizado `Tool.ps1` con mejor estructura y error handling
- Mejorado `ToolboxBS.ps1` con detección automática de PowerShell 7
- Actualizada guía de contribución con estándares de código
- Mejorados comentarios y documentación inline

### 🐛 Corregido
- Manejo robusto de errores de red en descargas
- Limpieza correcta de archivos temporales en caso de error
- Validación de archivos descargados antes de ejecución

### 🔒 Seguridad
- Agregadas verificaciones de integridad para archivos descargados
- Implementada validación de URLs antes de descargas
- Mejorada sanitización de paths de archivos temporales

## [2.1.0] - 2024-01-15

### ✨ Añadido
- Nueva interfaz web interactiva (ToolboxBSweb.html)
- Generación automática de scripts personalizados
- Selector de color dinámico para personalización
- Indicadores de progreso y feedback mejorado
- Sistema de tooltips informativos
- Funcionalidad de descarga ZIP para scripts

### 🔧 Cambiado
- Rediseñada interfaz de usuario con tema moderno
- Mejorada experiencia móvil y responsive design
- Optimizado rendimiento de la aplicación web

### 🐛 Corregido
- Problemas de compatibilidad con diferentes navegadores
- Errores en la generación de scripts complejos

## [2.0.0] - 2023-12-10

### ✨ Añadido
- Soporte completo para PowerShell 7
- Nuevas herramientas de diagnóstico del sistema
- Función de optimización de RAM con RAMMap
- Analizador de pantallazos azules
- Instalador automático de aplicaciones vía Chocolatey
- Función de reparación de red
- Diagnóstico de batería para laptops

### 🔧 Cambiado
- Migrada lógica principal a PowerShell moderno
- Mejorada interfaz gráfica con WPF
- Reorganizada estructura de archivos del proyecto

### 🗑️ Removido
- Dependencias de scripts legacy
- Herramientas obsoletas incompatibles

## [1.5.0] - 2023-10-05

### ✨ Añadido
- Función de limpieza profunda de archivos temporales
- Herramientas de configuración de Windows
- Acceso rápido a utilidades del sistema
- Función de backup automático antes de cambios

### 🔧 Cambiado
- Mejorada estabilidad general
- Optimizados tiempos de respuesta

### 🐛 Corregido
- Errores en sistemas con usuarios no-administradores
- Problemas con caracteres especiales en paths

## [1.0.0] - 2023-08-01

### ✨ Añadido
- Lanzamiento inicial de ToolboxBS
- Herramientas básicas de optimización de Windows
- Interfaz de línea de comandos
- Funciones de limpieza del sistema
- Instalación automática vía PowerShell

### 🔧 Características Iniciales
- Limpieza de archivos temporales
- Optimización básica del registro
- Configuración de servicios de Windows
- Herramientas de diagnóstico simples

---

## 🏷️ Tipos de Cambios

- **✨ Añadido** para nuevas características
- **🔧 Cambiado** para cambios en funcionalidad existente
- **🗑️ Removido** para características removidas
- **🐛 Corregido** para corrección de errores
- **🔒 Seguridad** para vulnerabilidades corregidas
- **📚 Documentación** para cambios solo en documentación
- **🎨 Estilo** para cambios que no afectan el significado del código
- **♻️ Refactorización** para cambios de código que no corrigen errores ni añaden características
- **⚡ Rendimiento** para cambios que mejoran el rendimiento
- **✅ Tests** para añadir tests faltantes o corregir tests existentes

## 📋 Notas de Migración

### De v1.x a v2.x
- Se requiere PowerShell 5.1 o superior
- Algunas herramientas legacy han sido removidas
- La interfaz ha cambiado significativamente
- Revisar scripts personalizados para compatibilidad

### De v2.0 a v2.1
- La interfaz web es ahora la forma recomendada de usar ToolboxBS
- Los scripts antiguos siguen siendo compatibles
- Nuevas características disponibles solo en la interfaz web

---

**Nota:** Las versiones siguen el formato MAJOR.MINOR.PATCH donde:
- **MAJOR**: Cambios incompatibles en la API
- **MINOR**: Funcionalidad añadida de manera compatible
- **PATCH**: Correcciones de errores compatibles