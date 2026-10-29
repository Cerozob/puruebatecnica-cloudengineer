"""Arma docs/entrega/entrega.html a partir de los documentos del repo.

Uso: python docs/entrega/build.py
Para el PDF: node docs/entrega/pdf.js (Chromium de Playwright), o abrir entrega.html en Chrome o Edge e
imprimir como PDF (márgenes predeterminados, sin encabezados ni pies de página del navegador).
"""
import json
import re
import sys
from pathlib import Path

import markdown

REPO_URL = "https://github.com/Cerozob/puruebatecnica-cloudengineer/tree/claude/optimistic-feynman-0baipi"
ERASER_URL = "https://app.eraser.io/workspace/Ij84o5Dz4IH3ScJQkZkG"

SECCIONES = [
    ("ia", "1. Uso de IA generativa"),
    ("actual", "2. Arquitectura actual y suposiciones"),
    ("objetivo", "3. Arquitectura objetivo"),
    ("migracion", "4. Plan de migración y modernización"),
    ("decisiones", "5. Decisiones técnicas y suposiciones"),
    ("costos", "6. Estimado de costos y recortes"),
    ("seguridad", "7. Controles de seguridad de los primeros 90 días"),
    ("iac", "8. Infraestructura como código"),
    ("anexo", "Anexo A. Decisiones en detalle"),
]

here = Path(__file__).resolve().parent
docs = here.parent
out_html = here / "entrega.html"
paginas_path = here / "paginas.json"
PAGINAS = json.loads(paginas_path.read_text()) if paginas_path.exists() else {}

LINK = re.compile(r"(?<!!)\[([^\]]+)\]\([^)]+\)")
IMG = re.compile(r"^!\[.*\]\(.*\)\n", flags=re.M)


def plain_links(md: str) -> str:
    return LINK.sub(r"\1", md)


def md_to_html(md: str) -> str:
    return markdown.markdown(plain_links(md), extensions=["tables", "sane_lists", "fenced_code"])


def drop_h1(md: str) -> str:
    md = re.sub(r"^# .*\n", "", md, count=1, flags=re.M)
    return re.sub(r"^\* Autor: .*\n", "", md, count=1, flags=re.M)


def read(name: str) -> str:
    return drop_h1((docs / name).read_text(encoding="utf-8"))


def shift(md: str) -> str:
    """Baja un nivel los encabezados (## -> #) para secciones que viven bajo un título propio."""
    return re.sub(r"^#(#+) ", r"\1 ", md, flags=re.M)


arq = read("arquitectura.md")
actual, objetivo = arq.split('<div style="page-break-after: always;"></div>')
actual = IMG.sub("", actual.replace("## Arquitectura actual\n", ""))
objetivo = objetivo.replace("## Arquitectura objetivo (12 meses)\n", "")
org_md, plat_md = objetivo.split("### Plataforma de producción")
org_md = IMG.sub("", org_md.replace("### Organización y cuentas\n", ""))
plat_md = IMG.sub("", plat_md)

uso_ia = read("uso-de-ia-generativa.md")
migracion = read("plan-migracion.md")
short = read("decisiones_short.md")
full = read("decisiones_full.md")
costos = read("costos.md")
seguridad = read("seguridad-90-dias.md")
iac = drop_h1((docs.parent / "infra" / "README.md").read_text(encoding="utf-8"))

indice = "".join(
    f'<li><a href="#{sid}"><span>{titulo}</span><span class="pag">{PAGINAS.get(sid, "")}</span></a></li>'
    for sid, titulo in SECCIONES
)

CSS = """
@page { size: A4; margin: 18mm 16mm 18mm 16mm;
  @bottom-center { content: counter(page); font: 9pt sans-serif; color: #666; } }
@page diagrama { size: A4 landscape; margin: 12mm; }
@page portada { @bottom-center { content: none; } }
html { font: 10.5pt/1.5 'Helvetica Neue', Arial, sans-serif; color: #1a1a1a; }
body { margin: 0; }
h1 { font-size: 20pt; margin: 0 0 10pt; color: #FF9900; border-bottom: 2px solid #FF9900; padding-bottom: 4pt; }
h2 { font-size: 13.5pt; margin: 16pt 0 6pt; color: #FF9900; break-after: avoid; }
h3 { font-size: 11.5pt; margin: 12pt 0 4pt; break-after: avoid; }
h4 { font-size: 10.5pt; margin: 10pt 0 3pt; break-after: avoid; }
section { break-before: page; }
section.portada { break-before: auto; page: portada; height: 250mm; display: flex; flex-direction: column; justify-content: center; }
.portada h1 { font-size: 28pt; border: none; }
.portada .sub { font-size: 14pt; color: #444; margin: 0 0 24pt; }
section.diagrama { page: diagrama; }
.diagrama h1 { font-size: 15pt; margin-bottom: 6pt; }
.diagrama img { width: 100%; height: 160mm; object-fit: contain; display: block; border: 1px solid #c9d2db; box-sizing: border-box; }
table { border-collapse: collapse; width: 100%; font-size: 8.8pt; margin: 6pt 0; }
th, td { border: 1px solid #c9d2db; padding: 3pt 5pt; vertical-align: top; text-align: left; }
thead th { background: #fff0d9; }
tr { break-inside: avoid; }
code { font-family: Menlo, Consolas, monospace; font-size: 0.9em; background: #f2f4f6; padding: 0 2pt; }
pre { font: 8pt/1.35 Menlo, Consolas, monospace; background: #f6f8fa; padding: 6pt 8pt; white-space: pre-wrap; break-inside: avoid; }
pre code { background: none; padding: 0; }
.nota { font-size: 9pt; color: #555; }
hr { border: none; border-top: 1px solid #e3e7eb; margin: 14pt 0; }
ol.indice { list-style: none; padding: 0; margin: 12pt 0; font-size: 11.5pt; }
ol.indice li { margin: 0 0 8pt; }
ol.indice a { display: flex; color: #1a1a1a; text-decoration: none; }
ol.indice a span:first-child { flex: 1; border-bottom: 1px dotted #FF9900; margin-right: 6pt; }
ol.indice .pag { color: #FF9900; font-weight: 700; }
a { color: #c47400; }
blockquote { margin: 6pt 0; padding-left: 10pt; border-left: 3px solid #c9d2db; color: #444; }
"""

doc = f"""<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>Kova: arquitectura objetivo y plan de migración</title>
<style>{CSS}</style>
</head>
<body>

<section class="portada">
<h1>Kova: arquitectura objetivo y plan de migración</h1>
<p class="sub">Prueba técnica · Platform / Cloud Engineer</p>
<p>Autor: <strong>Camilo Rozo</strong></p>
<p class="nota">Repositorio (documentos, libros de costos y esqueleto de Terraform):<br><a href="{REPO_URL}">{REPO_URL}</a></p>
<p class="nota">Diagramas editables (Eraser):<br><a href="{ERASER_URL}">{ERASER_URL}</a></p>
</section>

<section id="indice">
<h1>Contenido</h1>
<ol class="indice">{indice}</ol>
</section>

<section id="ia">
<h1>1. Uso de IA generativa</h1>
{md_to_html(uso_ia)}
</section>

<section class="diagrama" id="actual">
<h1>2. Arquitectura actual y suposiciones</h1>
<img src="../diagramas/as-is.svg" alt="Arquitectura actual de Kova">
</section>
<section>
{md_to_html(actual)}
</section>

<section class="diagrama" id="objetivo">
<h1>3. Arquitectura objetivo: organización y cuentas</h1>
<img src="../diagramas/objetivo-organizacion.svg" alt="Organización objetivo">
</section>
<section>
{md_to_html(org_md)}
</section>

<section class="diagrama">
<h1>3. Arquitectura objetivo: plataforma de producción</h1>
<img src="../diagramas/objetivo-plataforma.svg" alt="Plataforma objetivo">
</section>
<section>
{md_to_html(plat_md)}
</section>

<section id="migracion">
<h1>4. Plan de migración y modernización</h1>
{md_to_html(migracion)}
</section>

<section id="decisiones">
<h1>5. Decisiones técnicas y suposiciones</h1>
{md_to_html(short)}
</section>

<section id="costos">
<h1>6. Estimado de costos y recortes</h1>
{md_to_html(costos)}
</section>

<section id="seguridad">
<h1>7. Controles de seguridad de los primeros 90 días</h1>
{md_to_html(seguridad)}
</section>

<section id="iac">
<h1>8. Infraestructura como código</h1>
{md_to_html(iac)}
</section>

<section id="anexo">
<h1>Anexo A. Decisiones en detalle</h1>
{md_to_html(full)}
</section>

</body>
</html>
"""
out_html.write_text(doc, encoding="utf-8")
print("ok", out_html, file=sys.stderr)
