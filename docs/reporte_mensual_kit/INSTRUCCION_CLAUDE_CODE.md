# Instrucción para Claude Code — Reporte mensual PDF en el admin de Winbit

> Copiá esta carpeta completa dentro del repo (por ejemplo en `docs/reporte_mensual_kit/`),
> abrí Claude Code en el proyecto y pegale el texto que está debajo de la línea.

---

Quiero que el admin genere el **reporte mensual de rendimiento en PDF** de cada inversor,
con el diseño exacto de la plantilla que está en `docs/reporte_mensual_kit/`.
Hoy lo hago exportando un Excel desde el admin y pasándolo por un script externo;
quiero eliminar ese paso y descargar los PDF directamente desde el admin.

## Material de referencia (en `docs/reporte_mensual_kit/`)
- `referencia/reporte.html.j2` — la plantilla final (HTML + CSS, sintaxis Jinja). Es la fuente de verdad del diseño: A4 horizontal (297 × 210 mm), 5 páginas, márgenes 0, fondos impresos.
- `referencia/generar_reportes.py` — la lógica que arma los datos para la plantilla: formato de números (es-AR: `1.886,11`, `-1,50 %`, `+USD 20,03`), clasificación de operaciones, gráfico SVG, validaciones y casos de mucha o poca cantidad de filas (clases `denso` / `holgado`). Portá esa lógica a Ruby tal cual; no la reinventes.
- `referencia/render_pdf.js` — cómo se imprime hoy (Chrome headless, `printBackground`, 297 × 210 mm).
- `assets/` — logos (`logo_dark_bg.png`, `logo_light_bg.png`) y fotos de tapa y contratapa.
- `fonts/` — IBM Plex Sans e IBM Plex Sans Condensed (OFL).
- `ejemplo/` — un Excel real exportado desde este admin y el PDF que debe salir de él. **El PDF generado desde Rails tiene que verse igual a `ejemplo/Winbit_Reporte_2026-08_Florencia_Zuccotti.pdf`.**

## Paso 1 — Explorar antes de tocar nada
1. Buscá la sección existente **"Reportes PDF"** y contame qué hace hoy, qué gema o motor usa para generar PDF (Grover, WickedPDF, Prawn, Ferrum…) y cómo está desplegado en Heroku (buildpacks).
2. Encontrá el código que genera el **Excel del reporte mensual** (hojas `Resumen`, `Anexo`, `Operaciones`). Los datos del PDF tienen que salir de esa misma lógica o de un servicio compartido, para que Excel y PDF nunca difieran.
3. Revisá este posible bug del export: en el ejemplo de Florencia (agosto 2026), "Acumulado 2026 (USD)" = 178,91 y "Acumulado desde ingreso (USD)" = 414,91, pero valor final − saldo inicial − ingresos + retiros = 150,11 y valor − capital aportado neto = 386,11. La diferencia (28,80) parece venir de que los acumulados se calculan con el valor de fin de julio, sin incluir el mes del reporte. Confirmá la causa y **preguntame antes de corregirlo**.

Con eso, **entrá en modo plan y proponeme el plan antes de escribir código.**

## Paso 2 — Lo que quiero construir
- **Servicio de datos** (ej. `ReporteMensual::Datos.new(inversor, anio, mes)`) que devuelva lo mismo que hoy va al Excel: resumen, historial mensual del año, operaciones del mes con el USD de la cuenta y el rendimiento % diario, activos operados.
- **Vista ERB** que porte `reporte.html.j2` sin cambiar el diseño. Fuentes e imágenes embebidas (base64 o rutas absolutas) para que el PDF no dependa de la red.
- **Motor PDF con Chrome headless** (preferencia: Grover o Ferrum, porque la plantilla usa flexbox, grid y SVG, que WickedPDF/wkhtmltopdf no renderiza bien). Si la sección actual ya usa un motor compatible, reutilizalo. Si hace falta, indicame qué buildpack agregar en Heroku.
- **En "Reportes PDF"**:
  - selector de mes;
  - botón "Descargar PDF" por inversor;
  - botón "Generar todos" que descargue un ZIP con un PDF por inversor, nombrados `Winbit_Reporte_AAAA-MM_Nombre_Apellido.pdf`;
  - una vista previa HTML del reporte (útil para revisar sin generar el PDF);
  - los **avisos de validación** (los mismos que `validar()` en el script) visibles antes de descargar: suma de operaciones vs. rendimiento mensual, conteos positivas/negativas/BE, operaciones sin dirección, acumulados que no cierran, último valor del historial vs. valor del portafolio.
- **Reglas de negocio a respetar**: resultado de cada operación según el rendimiento diario (|rend.| ≤ 0,1 % → BE); ratio visible solo en operaciones positivas ("—" en el resto); la fila del mes en curso usa los valores exactos del resumen; los meses anteriores, los del historial; positivos en verde #39836D (sobre crema) / #479785 (sobre oscuro), negativos en #C96C67.
- **Tests**: un spec que genere el PDF con datos de prueba equivalentes al ejemplo de Florencia y verifique 5 páginas y las cifras clave.

## Fuera de alcance por ahora
- **No enviar mails todavía**: el envío a inversores lo hacemos en un paso siguiente, reutilizando este PDF.
- **No desplegar a producción sin avisarme.**
