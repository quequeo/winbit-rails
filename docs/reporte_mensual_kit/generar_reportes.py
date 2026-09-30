#!/usr/bin/env python3
"""
Winbit — Generador de reportes mensuales de rendimiento.

Uso:
    python generar_reportes.py archivo1.xlsx [archivo2.xlsx ...]
    python generar_reportes.py carpeta_con_excels/
    Opciones: --out carpeta_salida   (por defecto: ./salida)

Lee el Excel que exporta el admin (hojas Resumen, Anexo y Operaciones),
arma el HTML con la plantilla y lo imprime a PDF con Chrome (puppeteer).
Antes de generar, valida las cifras y avisa si algo no cierra.
"""
import sys, os, re, json, subprocess, datetime as dt
from pathlib import Path

import openpyxl
from jinja2 import Environment, FileSystemLoader

BASE = Path(__file__).resolve().parent
MESES = ["ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO", "JULIO",
         "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE"]
BE_UMBRAL = 0.001  # |rendimiento diario| <= 0,1 % se considera break even


# ---------------------------------------------------------------- formato
def _miles(n: str) -> str:
    return re.sub(r"\B(?=(\d{3})+(?!\d))", ".", n)

def num(x, dec=2, signo=False):
    if x is None:
        return "—"
    s = f"{abs(x):.{dec}f}"
    ent, _, frac = s.partition(".")
    out = _miles(ent) + ("," + frac if frac else "")
    if round(x, dec) < 0:
        out = "-" + out
    elif signo and round(x, dec) > 0:
        out = "+" + out
    return out

def usd(x, dec=2, signo=False):
    s = num(x, dec, signo)
    if s[0] in "+-":
        return f"{s[0]}USD {s[1:]}"
    return f"USD {s}"

def pct(x, dec=2, signo=True):
    return num(x * 100, dec, signo) + " %"

def clase(x, tol=0.0):
    if x is None or abs(x) <= tol:
        return "neu"
    return "pos" if x > 0 else "neg"


# ---------------------------------------------------------------- lectura
def a_fecha(v):
    if isinstance(v, dt.datetime):
        return v.date()
    if isinstance(v, dt.date):
        return v
    if isinstance(v, (int, float)):
        return (dt.datetime(1899, 12, 30) + dt.timedelta(days=float(v))).date()
    if isinstance(v, str):
        for f in ("%Y-%m-%d", "%d/%m/%Y", "%Y-%m"):
            try:
                return dt.datetime.strptime(v.strip(), f).date()
            except ValueError:
                pass
    return None

def a_hora(v):
    if isinstance(v, dt.time):
        return v.strftime("%H:%M")
    if isinstance(v, dt.datetime):
        return v.strftime("%H:%M")
    if isinstance(v, (int, float)) and 0 <= v < 1:
        m = round(v * 24 * 60)
        return f"{m // 60:02d}:{m % 60:02d}"
    return str(v).strip() if v not in (None, "") else "—"

def a_num(v):
    if v in (None, "", "—", "-"):
        return None
    if isinstance(v, (int, float)):
        return float(v)
    s = str(v).strip().replace("%", "")
    if "," in s and "." in s:
        s = s.replace(".", "").replace(",", ".")
    elif "," in s:
        s = s.replace(",", ".")
    try:
        return float(s)
    except ValueError:
        return None

def hoja(wb, nombre):
    for ws in wb.worksheets:
        if ws.title.strip().lower() == nombre:
            return ws
    raise ValueError(f"Falta la hoja '{nombre}'")

def leer_excel(path):
    wb = openpyxl.load_workbook(path, data_only=True)

    # Resumen: etiqueta en A, valor en B
    res = {}
    for a, b, *_ in hoja(wb, "resumen").iter_rows(values_only=True):
        if a:
            res[str(a).strip().lower()] = b

    def r(prefijo):
        for k, v in res.items():
            if k.startswith(prefijo.lower()):
                return v
        raise ValueError(f"Resumen: no encuentro '{prefijo}'")

    periodo = a_fecha(r("reporte mensual"))
    d = {
        "archivo": Path(path).name,
        "anio": periodo.year, "mes": periodo.month,
        "inversor": str(r("inversor")).strip(),
        "email": res.get("email"),
        "valor": a_num(r("valor portafolio")),
        "aportado_neto": a_num(r("capital aportado neto")),
        "rend_mes_usd": a_num(r("rendimiento mensual (usd")),
        "rend_mes_pct": a_num(r("rendimiento mensual winbit")),
        "acum_ingreso_usd": a_num(r("acumulado desde ingreso (usd")),
        "acum_ingreso_pct": a_num(r("acumulado desde ingreso (%")),
        "acum_anio_usd": a_num(r(f"acumulado {periodo.year} (usd")),
        "acum_anio_pct": a_num(r(f"acumulado {periodo.year} (%")),
        "saldo_ini_fecha": a_fecha(r(f"saldo inicial {periodo.year}")),
        "saldo_ini": a_num(r(f"saldo inicial {periodo.year} (usd")),
    }

    # Anexo: historial mensual
    filas = list(hoja(wb, "anexo").iter_rows(values_only=True))
    hist = []
    for f in filas[1:]:
        if not f or f[0] is None or str(f[0]).strip().upper() == "TOTAL":
            continue
        fecha = a_fecha(f[0])
        if not fecha:
            continue
        hist.append({
            "fecha": fecha,
            "pct": a_num(f[1]), "usd": a_num(f[2]),
            "ingresos": a_num(f[3]) or 0, "retiros": a_num(f[4]) or 0,
            "costo": a_num(f[5]) or 0, "valor": a_num(f[6]),
        })
    d["historial"] = hist

    # Operaciones
    ws = hoja(wb, "operaciones")
    ops, activos, resumen_ops, en_tabla = [], [], {}, False
    for f in ws.iter_rows(values_only=True):
        if not f or f[0] is None:
            continue
        a = str(f[0]).strip()
        if a.lower().startswith("activos operados") and f[1]:
            activos = re.findall(r"([A-Z]{2,5})\s*\(([^)]+)\)", str(f[1]))
            continue
        if a.lower() == "fecha":
            en_tabla = True
            continue
        if en_tabla and a_fecha(f[0]):
            ops.append({
                "fecha": a_fecha(f[0]), "activo": (f[1] or "").strip(),
                "direccion": (f[2] or "").strip().upper(),
                "apertura": a_hora(f[3]), "cierre": a_hora(f[4]),
                "usd": a_num(f[5]), "pct": a_num(f[6]),
                "ratio": a_num(f[7]),
            })
            continue
        if en_tabla:
            resumen_ops[a.lower()] = a_num(f[1])
    d["operaciones"] = sorted(ops, key=lambda o: o["fecha"], reverse=True)
    d["activos"] = activos
    d["resumen_ops"] = resumen_ops
    return d


# ---------------------------------------------------------------- lógica
def clasificar(op):
    p = op["pct"] if op["pct"] is not None else 0
    if abs(p) <= BE_UMBRAL:
        return "BE", "neu"
    return ("POSITIVO", "pos") if p > 0 else ("NEGATIVO", "neg")

def validar(d):
    av = []
    ops = d["operaciones"]
    tot = sum(o["usd"] or 0 for o in ops)
    if abs(tot - d["rend_mes_usd"]) > 0.05:
        av.append(f"La suma de operaciones da {usd(tot)} y el rendimiento mensual dice {usd(d['rend_mes_usd'])}.")
    ro = d["resumen_ops"]
    cuenta = {"POSITIVO": 0, "NEGATIVO": 0, "BE": 0}
    for o in ops:
        cuenta[o["resultado"]] += 1
    for clave, et in (("positivas", "POSITIVO"), ("negativas", "NEGATIVO"), ("break even", "BE")):
        if clave in ro and ro[clave] is not None and int(ro[clave]) != cuenta[et]:
            av.append(f"Operaciones {clave}: el Excel dice {int(ro[clave])}, la clasificación da {cuenta[et]}.")
    for o in ops:
        if not o["direccion"]:
            av.append(f"Operación del {o['fecha']:%d/%m} sin dirección (LONG/SHORT).")
    # acumulados contra el historial
    anio = [h for h in d["historial"] if h["fecha"].year == d["anio"]]
    ing = sum(h["ingresos"] for h in anio); ret = sum(h["retiros"] for h in anio)
    esperado = d["valor"] - d["saldo_ini"] - ing + ret
    if abs(esperado - d["acum_anio_usd"]) > 1:
        av.append(f"Acumulado {d['anio']}: el Excel dice {usd(d['acum_anio_usd'])}, pero valor final − saldo inicial − ingresos + retiros da {usd(esperado)}.")
    esperado_ing = d["valor"] - d["aportado_neto"]
    if abs(esperado_ing - d["acum_ingreso_usd"]) > 1:
        av.append(f"Acumulado desde el ingreso: el Excel dice {usd(d['acum_ingreso_usd'])}, pero valor − capital aportado neto da {usd(esperado_ing)}.")
    if anio and anio[-1]["valor"] is not None and abs(anio[-1]["valor"] - d["valor"]) > 1:
        av.append(f"Último valor del Anexo ({num(anio[-1]['valor'],0)}) no coincide con el valor del portafolio ({num(d['valor'])}).")
    return av


def grafico(puntos, w=1000, h=150):
    """SVG de línea con los valores del portafolio."""
    vals = [v for _, v in puntos]
    lo, hi = min(vals), max(vals)
    paso = _paso_lindo((hi - lo) / 3 or 100)
    y0 = (lo // paso) * paso
    y1 = y0 + paso * max(2, int(-(-(hi - y0) // paso)))
    pl, pr, pt, pb = 70, 24, 22, 30
    iw, ih = w - pl - pr, h - pt - pb
    X = lambda i: pl + iw * i / (len(puntos) - 1)
    Y = lambda v: pt + ih * (1 - (v - y0) / (y1 - y0))
    g = [f'<svg viewBox="0 0 {w} {h}" width="100%" xmlns="http://www.w3.org/2000/svg">']
    t = y0
    while t <= y1 + 1e-6:
        g.append(f'<line x1="{pl}" x2="{w-pr}" y1="{Y(t):.1f}" y2="{Y(t):.1f}" class="gl"/>')
        g.append(f'<text x="{pl-10}" y="{Y(t)+3.5:.1f}" class="ya">USD {num(t,0)}</text>')
        t += paso
    path = " ".join(f"{'M' if i == 0 else 'L'}{X(i):.1f},{Y(v):.1f}" for i, (_, v) in enumerate(puntos))
    area = path + f" L{X(len(puntos)-1):.1f},{pt+ih} L{X(0):.1f},{pt+ih} Z"
    g.append(f'<path d="{area}" class="area"/>')
    g.append(f'<path d="{path}" class="ln"/>')
    for i, (et, v) in enumerate(puntos):
        ult = i == len(puntos) - 1
        g.append(f'<circle cx="{X(i):.1f}" cy="{Y(v):.1f}" r="{4.5 if ult else 3.2}" class="{"pt last" if ult else "pt"}"/>')
        anchor = "start" if i == 0 else ("end" if ult else "middle")
        g.append(f'<text x="{X(i):.1f}" y="{h-8}" class="xa" text-anchor="{anchor}">{et}</text>')
    lv = puntos[-1][1]
    g.append(f'<text x="{X(len(puntos)-1):.1f}" y="{Y(lv)-11:.1f}" class="lbl" text-anchor="end">USD {num(lv)}</text>')
    g.append("</svg>")
    return "".join(g)

def _paso_lindo(x):
    import math
    e = 10 ** math.floor(math.log10(x))
    for m in (1, 2, 2.5, 5, 10):
        if x <= m * e:
            return m * e
    return 10 * e


def contexto(d):
    mes_txt = f"{MESES[d['mes']-1]} {d['anio']}"
    for o in d["operaciones"]:
        o["resultado"], o["cls"] = clasificar(o)
    avisos = validar(d)

    anio = [h for h in d["historial"] if h["fecha"].year == d["anio"] and h["fecha"].month <= d["mes"]]
    filas = []
    for h in anio:
        actual = h["fecha"].month == d["mes"]
        valor = d["valor"] if actual else h["valor"]
        r_usd = d["rend_mes_usd"] if actual else h["usd"]
        r_pct = d["rend_mes_pct"] if actual else h["pct"]
        dec = 2 if actual else 0
        filas.append({
            "mes": f"{h['fecha']:%m/%y}", "actual": actual,
            "valor": num(valor, dec), "ingresos": num(h["ingresos"], 0),
            "retiros": num(h["retiros"], 0), "costo": num(h["costo"], 0),
            "pct": pct(r_pct or 0, 2 if actual else 1), "usd": num(r_usd or 0, 2, True),
            "cls": clase(r_usd),
        })
    puntos = [(f"{d['saldo_ini_fecha']:%d/%m/%y}", d["saldo_ini"])]
    puntos += [(f"{h['fecha']:%m/%y}", d["valor"] if h["fecha"].month == d["mes"] else h["valor"]) for h in anio]

    ops = [{
        "fecha": f"{o['fecha']:%d/%m}", "activo": o["activo"], "direccion": o["direccion"] or "—",
        "apertura": o["apertura"], "cierre": o["cierre"], "resultado": o["resultado"], "cls": o["cls"],
        "usd": usd(o["usd"], 2, True), "usd_cls": clase(o["usd"]),
        "pct": pct(o["pct"] or 0, 1) if o["pct"] else "0,0 %",
        "ratio": num(o["ratio"], 2) if o["ratio"] is not None and o["resultado"] == "POSITIVO" else "—",
    } for o in d["operaciones"]]
    cuenta = {k: sum(1 for o in d["operaciones"] if o["resultado"] == k) for k in ("POSITIVO", "NEGATIVO", "BE")}

    return {
        "fonts": (BASE / "fonts").as_uri(), "assets": (BASE / "assets").as_uri(),
        "mes_txt": mes_txt, "anio": d["anio"],
        "inversor": d["inversor"],
        "fecha_cierre": f"{_ultimo_dia(d['anio'], d['mes']):%d/%m/%Y}",
        "valor": usd(d["valor"]), "aportado_neto": usd(d["aportado_neto"]),
        "k_mes": (pct(d["rend_mes_pct"]), usd(d["rend_mes_usd"], 2, True), clase(d["rend_mes_usd"])),
        "k_anio": (pct(d["acum_anio_pct"]), usd(d["acum_anio_usd"], 2, True), clase(d["acum_anio_usd"])),
        "k_ing": (pct(d["acum_ingreso_pct"]), usd(d["acum_ingreso_usd"], 2, True), clase(d["acum_ingreso_usd"])),
        "saldo_ini_fecha": f"{d['saldo_ini_fecha']:%d/%m/%Y}", "saldo_ini": usd(d["saldo_ini"]),
        "grafico": grafico(puntos, h=150 if len(filas) <= 9 else 112),
        "filas": filas, "denso": len(filas) > 9,
        "acum_pct": pct(d["acum_anio_pct"]), "acum_usd": num(d["acum_anio_usd"], 2, True) + " USD",
        "acum_cls": clase(d["acum_anio_usd"]),
        "activos": d["activos"], "ops": ops, "ops_denso": len(ops) > 16,
        "n_ops": len(ops), "n_pos": cuenta["POSITIVO"], "n_neg": cuenta["NEGATIVO"], "n_be": cuenta["BE"],
        "neto_mes": usd(d["rend_mes_usd"], 2, True), "rend_mes": pct(d["rend_mes_pct"]),
    }, avisos

def _ultimo_dia(y, m):
    return (dt.date(y + (m == 12), m % 12 + 1, 1) - dt.timedelta(days=1))

def nombre_pdf(d):
    limpio = re.sub(r"[^A-Za-z0-9]+", "_", _sin_tildes(d["inversor"])).strip("_")
    return f"Winbit_Reporte_{d['anio']}-{d['mes']:02d}_{limpio}.pdf"

def _sin_tildes(s):
    import unicodedata
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")


# ---------------------------------------------------------------- main
def main(argv):
    out = BASE / "salida"
    args = []
    it = iter(argv)
    for a in it:
        if a == "--out":
            out = Path(next(it))
        else:
            args.append(a)
    archivos = []
    for a in args:
        p = Path(a)
        archivos += sorted(p.glob("*.xlsx")) if p.is_dir() else [p]
    if not archivos:
        print(__doc__); return 1
    out.mkdir(parents=True, exist_ok=True)
    env = Environment(loader=FileSystemLoader(BASE / "plantilla"), autoescape=True)
    tpl = env.get_template("reporte.html.j2")
    trabajos, total_avisos = [], 0
    for x in archivos:
        if x.name.startswith("~$"):
            continue
        d = leer_excel(x)
        ctx, avisos = contexto(d)
        html = out / (nombre_pdf(d)[:-4] + ".html")
        html.write_text(tpl.render(**ctx), encoding="utf-8")
        pdf = out / nombre_pdf(d)
        trabajos.append({"html": str(html), "pdf": str(pdf)})
        print(f"• {d['inversor']} → {pdf.name}")
        for a in avisos:
            print(f"    ⚠ {a}")
        total_avisos += len(avisos)
    subprocess.run(["node", str(BASE / "render_pdf.js"), json.dumps(trabajos)], check=True)
    for t in trabajos:
        os.remove(t["html"])
    print(f"\nListo: {len(trabajos)} PDF en {out}  ({total_avisos} avisos)")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
