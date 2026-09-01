# ToolboxBS v4.0

De 32 herramientas a **257**. La aplicación se reescribió por completo alrededor de un catálogo de datos: las herramientas dejaron de ser tarjetas escritas a mano en el XAML y ahora son objetos, así que la interfaz, la búsqueda, los perfiles y la navegación se generan solos.

## Novedades

**Consola integrada.** La salida de cada tarea llega en vivo a la aplicación, coloreada por tipo de línea, y queda guardada en un registro por sesión. Antes cada tarea abría su propia ventana y la salida se perdía al cerrarla.

**Dashboard en tiempo real.** CPU, memoria, disco y tiempo encendido, más ocho comprobaciones de salud: activación de Windows, protección en tiempo real de Defender, firewall, antigüedad del último parche, espacio libre, salud SMART de los discos, punto de restauración disponible y reinicio pendiente.

**Reversión de cambios.** 25 herramientas traen su propia acción de deshacer, y todo lo que escribe en el registro hace un `reg export` antes de tocar nada.

**11 rutinas de un clic.** «El equipo va lento», «Recién formateado», «Después de un virus», «Antes de formatear», «No hay internet», «Windows no actualiza», «Liberar espacio a fondo», «Periféricos que fallan» y más. La rutina marca las herramientas y te muestra la selección: el último clic siempre es tuyo.

**Búsqueda global.** `Ctrl+F` busca en las 257 sin importar el módulo en el que estés.

**Perfiles.** Guarda tu selección en un `.json` y cárgala en el siguiente equipo.

**Modo consola.** `-ListTools`, `-RunTool clean-temp,net-info`, `-ExportCatalog`, `-SelfTest`. La misma lógica sin abrir la ventana, para automatizar.

**Confirmación de riesgo.** Las 13 acciones difíciles de deshacer piden confirmación mostrando la lista exacta antes de ejecutar.

**Transparencia.** Clic derecho en cualquier tarjeta → *Ver el código que ejecuta*: se abre el PowerShell literal que va a correr, sin ejecutarlo.

## Los módulos

| Módulo | Herramientas |
| :--- | ---: |
| 🔧 Reparación | 31 |
| 🧹 Limpieza | 19 |
| ⚡ Rendimiento | 26 |
| 🛡️ Seguridad | 18 |
| 🌐 Red | 14 |
| 📊 Información | 14 |
| 🧰 Herramientas | 48 |
| 📦 Aplicaciones | 87 |

## Correcciones de la v3

- El XAML se cargaba **dos veces**: la interfaz se construía en la línea 490 y otra vez en la 1230, descartando la primera ventana entera.
- El escáner de tarjetas solo bajaba dos niveles del árbol visual, así que cualquier tarjeta anidada más profundo quedaba fuera del contador y no se ejecutaba nunca.
- `Get-WmiObject` no existe en PowerShell 7, pero el script prefería lanzar `pwsh`: «Drivers del sistema» y «Activar Windows» fallaban ahí. Ahora el motor corre siempre en Windows PowerShell 5.1, que es donde viven `Checkpoint-Computer`, `Get-ComputerRestorePoint` y `Get-AppxPackage`.
- WPF necesita un hilo STA; si se lanzaba con `-MTA` el error era ilegible. Ahora se detecta y se relanza solo.

## Ejecutar

```powershell
irm "https://cutt.ly/ToolboxBS" | iex
```

O descarga `ToolboxBS.ps1` de esta release y ejecútalo. Requiere Windows 10/11 y se auto-eleva a Administrador.

📖 [Documentación completa](https://brandonsepulveda.github.io/Documentacion.html) · 🌐 [Versión web](https://brandonsepulveda.github.io/ToolboxBSweb.html)
