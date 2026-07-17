"""Render interview report as Markdown -> HTML -> PDF.

Uses xhtml2pdf (pure Python, zero system dependencies) instead of
weasyprint so it works on Windows without installing GTK/MSYS2.
"""
from pathlib import Path
import uuid
import os
import platform
import markdown as md
from jinja2 import Template

from ..config import settings


# ── CJK Font Discovery ──────────────────────────────────────────
# xhtml2pdf uses ReportLab under the hood. ReportLab does NOT
# auto-discover system fonts; we must explicitly register a CJK
# font (TTF/OTF/TTC) so Chinese characters render correctly.

def _find_cjk_font() -> str:
    """Return the filesystem path to a CJK font, or '' if none found."""
    system = platform.system()

    if system == "Windows":
        win_fonts = os.environ.get("WINDIR", "C:/Windows") + "/Fonts"
        candidates = [
            os.path.join(win_fonts, "msyh.ttc"),      # Microsoft YaHei
            os.path.join(win_fonts, "msyhbd.ttc"),    # Microsoft YaHei Bold
            os.path.join(win_fonts, "simhei.ttf"),    # SimHei
            os.path.join(win_fonts, "simsun.ttc"),    # SimSun
            os.path.join(win_fonts, "simfang.ttf"),   # SimFang
            os.path.join(win_fonts, "simkai.ttf"),    # SimKai
        ]
    elif system == "Darwin":
        candidates = [
            "/System/Library/Fonts/PingFang.ttc",
            "/System/Library/Fonts/STHeiti Light.ttc",
            "/System/Library/Fonts/STHeiti Medium.ttc",
            "/Library/Fonts/Arial Unicode.ttf",
        ]
    else:  # Linux (Docker)
        candidates = [
            "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
            "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
            "/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc",
            "/usr/share/fonts/google-noto-cjk/NotoSansCJK-Regular.ttc",
            "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf",
            "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
            "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
        ]

    for p in candidates:
        if os.path.isfile(p):
            return p

    return ""


_CJK_FONT_PATH = _find_cjk_font()

# Register the font with ReportLab so xhtml2pdf can use it.
if _CJK_FONT_PATH:
    try:
        from reportlab.pdfbase import pdfmetrics
        from reportlab.pdfbase.ttfonts import TTFont

        # .ttc files are TrueType Collections — we need subfont 0.
        _is_ttc = _CJK_FONT_PATH.lower().endswith(".ttc")
        pdfmetrics.registerFont(
            TTFont(
                "CJK",
                _CJK_FONT_PATH,
                subfontIndex=0 if _is_ttc else None,
            )
        )
        _FONT_FAMILY = "'CJK', 'Microsoft YaHei', 'SimHei', 'PingFang SC', 'Noto Sans CJK SC', sans-serif"
    except Exception:
        _FONT_FAMILY = "'Microsoft YaHei', 'SimHei', 'PingFang SC', 'Noto Sans CJK SC', sans-serif"
else:
    _FONT_FAMILY = "'Microsoft YaHei', 'SimHei', 'PingFang SC', 'Noto Sans CJK SC', sans-serif"


HTML_TEMPLATE = Template("""\
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>{{ title }}</title>
<style>
body {
    font-family: {{ font_family }};
    padding: 32px;
    color: #222;
    font-size: 12pt;
}
h1 { border-bottom: 2px solid #333; padding-bottom: 8px; }
h2 { color: #1a56db; margin-top: 24px; }
h3 { color: #444; }
table { border-collapse: collapse; width: 100%%; margin: 12px 0; }
th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
.badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 12px; }
.pass { background: #d1fae5; color: #065f46; }
.fail { background: #fee2e2; color: #991b1b; }
blockquote { border-left: 3px solid #ddd; margin: 8px 0; padding: 4px 12px; color: #555; }
</style></head><body>
{{ content_html | safe }}
</body></html>
""")


def _link_callback(uri, rel):
    """xhtml2pdf link callback — we have no external resources."""
    return None


def render_pdf(title: str, markdown_text: str) -> str:
    """Render Markdown -> HTML -> PDF. Returns relative path to PDF file.

    Raises RuntimeError if PDF generation fails (e.g. no CJK font).
    """
    content_html = md.markdown(markdown_text, extensions=["tables", "fenced_code"])
    html_str = HTML_TEMPLATE.render(
        title=title,
        content_html=content_html,
        font_family=_FONT_FAMILY,
    )

    out_dir = Path(settings.STORAGE_DIR) / "reports"
    out_dir.mkdir(parents=True, exist_ok=True)
    fname = f"{uuid.uuid4().hex}.pdf"
    fpath = out_dir / fname

    from xhtml2pdf import pisa

    with open(fpath, "wb") as dest:
        pisa_status = pisa.CreatePDF(
            html_str,
            dest=dest,
            link_callback=_link_callback,
        )

    if pisa_status.err:
        raise RuntimeError(f"PDF generation failed: {pisa_status.err}")

    return str(fpath.relative_to(settings.STORAGE_DIR))
