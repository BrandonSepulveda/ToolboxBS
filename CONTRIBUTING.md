# Contribuir a ToolboxBS

Gracias por querer aportar. Desde la v4 agregar una utilidad es cuestión de minutos:
las herramientas son **datos**, no interfaz, así que no hay que tocar el XAML ni la
lógica de la ventana.

---

## Agregar una herramienta

Todo el catálogo vive en `src/ToolboxBS.ps1`, en el bloque `$Global:Catalog`.
Cada herramienta es una llamada a la función `T`:

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

### Los campos

| Campo | Valores | Qué hace |
| :--- | :--- | :--- |
| `Id` | kebab-case único | Identificador. Es lo que acepta `-RunTool`. Prefíjalo con su categoría (`clean-`, `net-`…) |
| `Name` | texto corto | Título de la tarjeta |
| `Desc` | una línea | Qué hace, en lenguaje de usuario. Aparece bajo el título y en la documentación |
| `Icon` | hex de Segoe MDL2 | Por ejemplo `E74D`. Solo la aplicación de escritorio lo usa |
| `Cat` | `repair` `clean` `perf` `sec` `net` `info` `tools` `apps` | En qué módulo aparece |
| `Risk` | `safe` `care` `danger` | `danger` hace que la app pida confirmación mostrando la lista antes de ejecutar |
| `Run` | `inline` `term` | `inline` va a la consola integrada. Usa `term` solo si la herramienta es interactiva o tarda muchísimo (SFC, DISM, exámenes completos) |
| `Code` | PowerShell | Lo que se ejecuta |
| `Revert` | PowerShell (opcional) | Cómo deshacerlo. Si lo pones, la tarjeta queda marcada como reversible |

### El preludio

Cada tarea recibe un bloque de funciones comunes ya definidas. Úsalas en vez de
reinventarlas: hacen que la salida se vea igual en toda la aplicación y que la
consola integrada pueda colorearla.

| Función | Para qué |
| :--- | :--- |
| `HR "TITULO"` | Encabezado de sección |
| `Step "..."` | Paso dentro de la tarea |
| `OK` / `INFO` / `WARN` / `ERR` | Resultado de una acción |
| `ROW "clave" "valor"` | Línea de dato alineada |
| `Human $bytes` | Formatea tamaños (KB, MB, GB) |
| `Set-Reg $ruta $nombre $valor [$tipo]` | Escribe en el registro |
| `Backup-Reg $ruta $etiqueta` | `reg export` antes de tocar nada |
| `Remove-Reg $ruta $nombre` | Borra un valor |
| `Purge-Folder $ruta "Etiqueta"` | Vacía una carpeta y devuelve los bytes liberados |
| `Stop-Svc` / `Start-Svc` | Servicios |
| `Need-Winget` | Comprueba winget antes de usarlo |
| `BSDir "reportes"` | Devuelve la carpeta de salida, creándola si falta |
| `Get-NirTool` | Descarga una utilidad de NirSoft |

### Reglas que evitan sustos

1. **Nunca uses `Read-Host` en una tarea `inline`.** Corre en un proceso hijo sin
   consola interactiva y se quedaría colgada. Si necesitas interacción, usa `Run = 'term'`.
2. **Si escribes en el registro, llama antes a `Backup-Reg`** y escribe el `Revert`.
3. **Marca `Risk = 'danger'`** si el cambio no se deshace solo: borrados definitivos,
   desinstalaciones masivas, cambios de arranque.
4. **Los here-strings van con el terminador en la columna 0.** PowerShell lo exige, y
   el generador de la versión web inyecta tu código tal cual.
5. **Sin acentos en la salida.** El texto viaja por un proceso hijo redirigido; los
   nombres y descripciones sí llevan acentos, la salida de consola no.

---

## Validar antes de abrir el PR

```powershell
# Comprueba ids duplicados, que todo compile y que la interfaz se construya
.\src\ToolboxBS.ps1 -SelfTest

# Prueba tu herramienta aislada, sin abrir la ventana
.\src\ToolboxBS.ps1 -RunTool tu-id

# Revisa cómo queda descrita en el catálogo
.\src\ToolboxBS.ps1 -ListTools
```

El `-SelfTest` es lo mismo que corre la CI en cada push. Si pasa en tu equipo, pasa allá.

---

## Flujo

1. Haz un **fork** del repositorio.
2. Crea una rama: `git checkout -b feature/mi-herramienta`.
3. Agrega tu herramienta y valida con `-SelfTest`.
4. Commit y push.
5. Abre un **Pull Request** contando qué problema resuelve la herramienta.

---

## Reportar un fallo

Cada sesión deja su registro completo en `Documentos\ToolboxBS\logs`. Adjunta ese
archivo al issue: trae la salida literal de la tarea y el error exacto, que es
mucho más útil que una descripción de memoria.
