# Winbit · Generador de reportes mensuales

Arma el PDF del reporte mensual de rendimiento a partir del Excel que exporta el admin
(hojas **Resumen**, **Anexo** y **Operaciones**). Tipografía IBM Plex según el manual de marca.

## Requisitos (una sola vez)
- Python 3 con `openpyxl` y `jinja2`:  `pip install openpyxl jinja2`
- Node.js con puppeteer (trae su propio Chrome), dentro de esta carpeta:  `npm i puppeteer`

## Uso
    python generar_reportes.py Reporte_2026-08_Florencia_Zuccotti.xlsx
    python generar_reportes.py carpeta_con_todos_los_excels/      # uno por inversor
    python generar_reportes.py carpeta/ --out reportes_agosto

Los PDF quedan en `salida/` como `Winbit_Reporte_AAAA-MM_Nombre_Apellido.pdf`.

## Controles automáticos
Antes de generar, el script revisa y avisa (⚠) si:
- la suma de operaciones no coincide con el rendimiento mensual;
- los conteos de positivas / negativas / BE no coinciden con los del Excel;
- falta la dirección (LONG/SHORT) de alguna operación;
- los acumulados (año y desde el ingreso) no cierran con valor, saldo inicial, ingresos y retiros;
- el último valor del Anexo no coincide con el valor del portafolio.

El PDF se genera igual con los datos del Excel; los avisos son para revisar antes de enviar.

## Criterios
- Resultado de cada operación: se deriva del rendimiento diario. |rend.| ≤ 0,1 % → BE.
- Ratio: solo en operaciones positivas; en el resto, "—".
- Mes en curso de la tabla: valores exactos del Resumen; meses anteriores, del Anexo.

## Carpetas
- `plantilla/reporte.html.j2` — diseño (HTML + CSS). Textos fijos, colores y tamaños se editan acá.
- `assets/` — logos y fotos de tapa y contratapa. Para cambiar una foto, reemplazar el archivo con el mismo nombre.
- `fonts/` — IBM Plex Sans e IBM Plex Sans Condensed (licencia OFL).
