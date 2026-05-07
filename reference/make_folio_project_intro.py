from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw
from reportlab.lib import colors
from reportlab.lib.pagesizes import landscape
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "reference" / "folio_project_intro.pdf"
TMP = Path("/private/tmp/folio_pdf_assets")
ASSETS = ROOT / "reference" / "folio_pdf_assets"

SHOT_READING = ASSETS / "interact.png"
SHOT_BOOKSHELF = ASSETS / "chapters.png"
SHOT_HOME = ASSETS / "home.png"

PAGE_W, PAGE_H = landscape((842, 595))  # A4 landscape, points


pdfmetrics.registerFont(UnicodeCIDFont("STSong-Light"))

FONT = "STSong-Light"
INK = colors.HexColor("#1D1D1F")
MUTED = colors.HexColor("#86868B")
HAIR = colors.HexColor("#E5E5EA")
PAPER = colors.HexColor("#FAFAFA")
PAPER_2 = colors.HexColor("#F5F5F7")
ACCENT = colors.HexColor("#000000")

LEFT_X = 80
RIGHT_X = 460
LEFT_COL = 25
WIDE_COL = 32


def rounded_image(src: Path, radius: int = 32) -> Path:
    TMP.mkdir(exist_ok=True)
    out = TMP / f"{src.stem}_rounded.png"
    img = Image.open(src).convert("RGB")
    crop = max(8, min(img.size) // 180)
    img = img.crop((crop, crop, img.width - crop, img.height - crop))
    bg = Image.new("RGB", img.size, "#F5F5F7")
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, *img.size), radius=radius, fill=255)
    bg.paste(img, (0, 0), mask)
    bg.save(out)
    return out


def fit_image(c: canvas.Canvas, src: Path, x: float, y: float, w: float, h: float) -> None:
    img = Image.open(src)
    iw, ih = img.size
    scale = min(w / iw, h / ih)
    dw, dh = iw * scale, ih * scale
    c.drawImage(str(src), x + (w - dw) / 2, y + (h - dh) / 2, dw, dh, mask="auto")


def reset_alpha(c: canvas.Canvas) -> None:
    if hasattr(c, "setFillAlpha"):
        c.setFillAlpha(1)
    if hasattr(c, "setStrokeAlpha"):
        c.setStrokeAlpha(1)


def text_units(char: str) -> float:
    if char.isspace():
        return 0.45
    return 0.56 if char.isascii() else 1.0


def cjk_wrap(text: str, width: float) -> list[str]:
    lines: list[str] = []
    current: list[str] = []
    units = 0.0
    for char in text:
        if char == "\n":
            lines.append("".join(current).strip())
            current = []
            units = 0.0
            continue
        char_units = text_units(char)
        if current and units + char_units > width:
            lines.append("".join(current).strip())
            current = [char]
            units = char_units
        else:
            current.append(char)
            units += char_units
    if current:
        lines.append("".join(current).strip())
    return lines


def fill_background(c: canvas.Canvas) -> None:
    c.setFillColor(PAPER)
    c.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)


def footer(c: canvas.Canvas, index: int) -> None:
    c.setStrokeColor(HAIR)
    c.setLineWidth(0.5)
    c.line(80, 48, PAGE_W - 80, 48)
    c.setFillColor(MUTED)
    c.setFont(FONT, 9)
    c.drawString(80, 30, "Velune Folio")
    c.drawRightString(PAGE_W - 80, 30, f"{index:02d} / 07")


def section(c: canvas.Canvas, index: str, title: str, eyebrow: str | None = None) -> None:
    c.setFillColor(MUTED)
    c.setFont(FONT, 11)
    c.drawString(80, PAGE_H - 80, index)
    if eyebrow:
        c.drawRightString(PAGE_W - 80, PAGE_H - 80, eyebrow)
    c.setFillColor(INK)
    c.setFont(FONT, 26)
    c.drawString(80, PAGE_H - 140, title)


def paragraph(
    c: canvas.Canvas,
    text: str,
    x: float,
    y: float,
    width_chars: int = 32,
    size: float = 14,
    leading: float = 24,
    color=INK,
) -> float:
    c.setFillColor(color)
    c.setFont(FONT, size)
    for raw in text.split("\n"):
        for line in cjk_wrap(raw, width_chars):
            c.drawString(x, y, line)
            y -= leading
        y -= leading * 0.35
    return y


def callout(c: canvas.Canvas, x: float, y: float, w: float, text: str) -> float:
    lines = []
    for raw in text.split("\n"):
        lines.extend(cjk_wrap(raw, 26))
    
    c.setStrokeColor(MUTED)
    c.setLineWidth(1.5)
    h = len(lines) * 22
    ty = y - 10
    c.line(x, ty + 12, x, ty - h + 10)
    
    c.setFillColor(INK)
    c.setFont(FONT, 13)
    for line in lines:
        c.drawString(x + 16, ty, line)
        ty -= 22
    return ty - 20


def bullet(c: canvas.Canvas, x: float, y: float, title: str, body: str, width_chars: int = 28) -> float:
    c.setFillColor(ACCENT)
    c.circle(x + 2, y + 4, 2, stroke=0, fill=1)
    c.setFillColor(INK)
    c.setFont(FONT, 15)
    c.drawString(x + 16, y, title)
    return paragraph(c, body, x + 16, y - 26, width_chars=width_chars, size=12, leading=22, color=MUTED) - 10


def add_cover(c: canvas.Canvas) -> None:
    fill_background(c)
    c.setFillColor(ACCENT)
    c.setFont(FONT, 46)
    c.drawString(80, 400, "folio")
    
    c.setFillColor(INK)
    c.setFont(FONT, 28)
    c.drawString(80, 330, "让思想成为一种")
    c.drawString(80, 286, "可以被体验的过程")
    
    c.setFillColor(MUTED)
    c.setFont(FONT, 14)
    c.drawString(82, 240, "交互式人文阅读平台")

    c.setStrokeColor(HAIR)
    c.setLineWidth(0.5)
    c.line(80, 200, 360, 200)
    
    c.setFillColor(INK)
    c.setFont(FONT, 14)
    c.drawString(82, 160, "项目亮点")
    
    text = "以场景化叙事与选择式对话，让哲学、文学与思想像小说一样进入。\n用户不是被动听讲，而是在回应中体验思想如何生成。"
    paragraph(c, text, 82, 134, width_chars=24, size=12, leading=20, color=MUTED)

    img = rounded_image(SHOT_HOME, 16)
    fit_image(c, img, 476, 96, 268, 403)
    footer(c, 1)


def add_problem(c: canvas.Canvas) -> None:
    fill_background(c)
    section(c, "02", "问题", "从文本抵达思想，门槛仍然很高")
    text = (
        "大量哲学与人文知识，至今仍主要依赖传统文本阅读。它们以抽象概念、严密论述和漫长语境展开，"
        "对多数用户而言，进入成本高，持续阅读也容易中断。\n"
        "真正的障碍并不只是内容艰深，而是路径单一：用户往往必须先拥有一定理解能力，才能慢慢接近思想本身。"
        "这让许多值得被更多人看见的人文知识，停留在少数人能够长期抵达的范围里。"
    )
    paragraph(c, text, LEFT_X, 390, width_chars=28, size=13, leading=26)
    
    callout(
        c,
        500,
        370,
        240,
        "传统阅读的隐含前提是：\n先理解，才能进入。\n\nfolio 想反过来：\n先进入，再逐步理解。",
    )
    footer(c, 2)


def add_solution(c: canvas.Canvas) -> None:
    fill_background(c)
    section(c, "03", "解决方案", "把阅读变成可参与的过程")
    text = (
        "folio 将人文阅读转化为一种可参与的体验。用户不再只是沿着线性文本接收信息，"
        "而是通过对话与选择推进阅读，在具体情境中进入思想的展开路径。\n"
        "理解不再是读完之后才出现的结果，而是在参与、回应、迟疑与选择之间自然发生。"
        "folio 没有改变知识本身，而是改变了人与知识接触的方式。"
    )
    paragraph(c, text, LEFT_X, 390, width_chars=LEFT_COL, size=13, leading=26)
    img = rounded_image(SHOT_READING, 16)
    fit_image(c, img, RIGHT_X + 16, 96, 268, 368)
    footer(c, 3)


def add_innovation(c: canvas.Canvas) -> None:
    fill_background(c)
    section(c, "04", "核心创新", "重构人与思想相遇的方式")
    y = 390
    y = bullet(c, 80, y, "阅读方式的改变", "从线性文本，转向可交互、可回返、可继续的体验过程。")
    y = bullet(c, 80, y, "理解路径的改变", "从抽象推演，转向通过场景、问题与选择逐步形成直观理解。")
    bullet(c, 80, y, "学习体验的改变", "从被动接收信息，转向主动进入思想并探索不同可能。")
    
    c.setFillColor(PAPER_2)
    c.roundRect(RIGHT_X, 160, 300, 220, 12, stroke=0, fill=1)
    c.setFillColor(ACCENT)
    c.setFont(FONT, 28)
    c.drawString(RIGHT_X + 40, 300, "不是生产更多内容")
    c.drawString(RIGHT_X + 40, 250, "而是改变进入路径")
    c.setFillColor(MUTED)
    c.setFont(FONT, 12)
    c.drawString(RIGHT_X + 42, 210, "思想不再只是被阅读，而是被体验。")
    footer(c, 4)


def add_product(c: canvas.Canvas) -> None:
    fill_background(c)
    section(c, "05", "产品形式", "每一位思想者，都是一段可持续展开的体验")
    text = (
        "在 folio 中，每位思想者被构建为一个可以持续展开的阅读空间。"
        "用户通过连续的对话、选择与章节进入其中，在不同路径的推进中接触其核心观念与问题意识。\n"
        "阅读不再是一次性的获取，而是一个可以反复进入、持续生成的过程。"
        "用户并不是寻找标准答案，而是在参与思想如何形成。"
    )
    paragraph(c, text, LEFT_X, 390, width_chars=LEFT_COL, size=13, leading=26)
    img = rounded_image(SHOT_BOOKSHELF, 16)
    fit_image(c, img, RIGHT_X + 16, 96, 268, 368)
    footer(c, 5)


def add_value(c: canvas.Canvas) -> None:
    fill_background(c)
    section(c, "06", "用户价值", "更慢，但更连续；更轻，但更深入")
    left = (
        "folio 降低了人文知识的理解门槛，让更多用户能够进入哲学、文学与思想的世界。"
        "它用可感知的场景替代纯概念入口，用选择与回应建立参与感，让复杂观念先被感受，再被理解。"
    )
    paragraph(c, left, LEFT_X, 390, width_chars=LEFT_COL, size=13, leading=26)
    
    y = 350
    y = bullet(c, RIGHT_X, y, "降低门槛", "先进入具体情境，再逐步触达抽象思想。", width_chars=18)
    y = bullet(c, RIGHT_X, y, "提升参与", "用户通过回应推动阅读，理解在互动中生长。", width_chars=18)
    bullet(c, RIGHT_X, y, "抵抗碎片化", "提供一种更慢、更连续、更具沉浸感的学习路径。", width_chars=18)
    footer(c, 6)


def add_summary(c: canvas.Canvas) -> None:
    fill_background(c)
    section(c, "07", "总结", "让思想从文本中被释放出来")
    
    c.setFillColor(INK)
    c.setFont(FONT, 26)
    c.drawString(100, 360, "当阅读成为一种可以参与的过程，")
    c.drawString(100, 310, "理解不再依赖门槛，")
    c.drawString(100, 260, "而是在体验中自然发生。")
    
    c.setFillColor(MUTED)
    c.setFont(FONT, 14)
    c.drawString(102, 190, "folio 尝试让思想成为一种可以被进入、被感受、被持续探索的存在。")
    
    c.setStrokeColor(HAIR)
    c.setLineWidth(1)
    c.line(100, 150, 400, 150)
    
    c.setFillColor(ACCENT)
    url = c.beginText(100, 110)
    url.setFont("Helvetica", 15)
    url.setCharSpace(0.45)
    url.textLine("https://folio.echoverse.com")
    c.drawText(url)
    footer(c, 7)


def main() -> None:
    c = canvas.Canvas(str(OUT), pagesize=(PAGE_W, PAGE_H))
    for add in [
        add_cover,
        add_problem,
        add_solution,
        add_innovation,
        add_product,
        add_value,
        add_summary,
    ]:
        add(c)
        c.showPage()
    c.save()
    print(OUT)


if __name__ == "__main__":
    main()
