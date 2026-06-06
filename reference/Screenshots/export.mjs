import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";
import { enSlides, zhSlides } from "./slides.js";

const WIDTH = 1242;
const HEIGHT = 2688;
const TITLE_X = 96;
const TITLE_Y = 224;
const TITLE_FONT_SIZE = 102;
const TITLE_LINE_HEIGHT = 116;

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const outputRoot = path.join(scriptDir, "exports");

function localeInputDir(locale) {
  return path.join(scriptDir, locale === "zh" ? "screenshots_zh" : "screenshots_en");
}

function splitEnglishTitle(title, maxChars = 17) {
  const words = title.split(/\s+/);
  const lines = [];
  let current = "";

  for (const word of words) {
    const next = current ? `${current} ${word}` : word;
    if (next.length <= maxChars || current.length === 0) {
      current = next;
      continue;
    }
    lines.push(current);
    current = word;
  }

  if (current) {
    lines.push(current);
  }

  return lines.slice(0, 3);
}

function splitTitle(title, locale) {
  if (title.includes("\n")) {
    return title.split("\n");
  }

  if (locale === "zh") {
    return title.match(/.{1,9}/g) ?? [title];
  }

  return splitEnglishTitle(title);
}

function escapeXml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function accentFor(accent) {
  if (accent === "mist") {
    return {
      top: "rgba(198, 210, 255, 0.12)",
      bottom: "rgba(210, 220, 255, 0.08)",
      baseTop: "#080a0e",
      baseBottom: "#050609",
    };
  }

  if (accent === "ember") {
    return {
      top: "rgba(255, 212, 170, 0.1)",
      bottom: "rgba(255, 244, 200, 0.08)",
      baseTop: "#0b0a09",
      baseBottom: "#070707",
    };
  }

  return {
    top: "rgba(255, 255, 255, 0.08)",
    bottom: "rgba(255, 255, 255, 0.06)",
    baseTop: "#08080a",
    baseBottom: "#060607",
  };
}

function buildStars() {
  const stars = [
    [92, 182, 2.6, 0.68],
    [182, 324, 1.8, 0.34],
    [918, 210, 2.1, 0.48],
    [1024, 406, 1.7, 0.28],
    [822, 1880, 1.7, 0.24],
    [152, 2220, 2, 0.38],
    [1130, 2412, 1.5, 0.22],
    [438, 564, 2.3, 0.3],
    [598, 1368, 1.8, 0.42],
    [1064, 930, 2.2, 0.36],
    [492, 2460, 2.7, 0.5],
    [742, 2108, 1.4, 0.28],
  ];

  return stars
    .map(
      ([cx, cy, r, opacity]) =>
        `<circle cx="${cx}" cy="${cy}" r="${r}" fill="white" opacity="${opacity}" />`,
    )
    .join("");
}

function slugify(value) {
  return value
    .replace(/\s+/g, "-")
    .replace(/[^\p{L}\p{N}-]+/gu, "")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .toLowerCase();
}

async function createSlide(locale, slide) {
  const filename = `${slide.image}-${locale}.PNG`;
  const imagePath = path.join(localeInputDir(locale), filename);
  const imageBuffer = await fs.readFile(imagePath);
  const imageData = `data:image/png;base64,${imageBuffer.toString("base64")}`;
  const titleLines = splitTitle(slide.title, locale);
  const titleTspans = titleLines
    .map((line, index) => {
      const dy = index === 0 ? 0 : TITLE_LINE_HEIGHT;
      return `<tspan x="${TITLE_X}" dy="${dy}">${escapeXml(line)}</tspan>`;
    })
    .join("");

  const palette = accentFor(slide.accent);
  const frameWidth = 970;
  const frameHeight = Math.round((frameWidth * 2688) / 1242);
  const sideInset = 52;
  const frameX = slide.align === "left" ? sideInset : WIDTH - sideInset - frameWidth;
  const frameY = 706;
  const rotation = slide.pose === "straight" ? 0 : slide.align === "left" ? -4 : 4;
  const titleFamily =
    locale === "zh"
      ? "'Songti SC','STHeiti SC','Hiragino Sans GB','PingFang SC',sans-serif"
      : "'New York','Times New Roman','Baskerville','Iowan Old Style',serif";

  const svg = `
    <svg width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="${palette.baseTop}" />
          <stop offset="100%" stop-color="${palette.baseBottom}" />
        </linearGradient>
        <radialGradient id="glowTop" cx="0.22" cy="0.18" r="0.42">
          <stop offset="0%" stop-color="${palette.top}" />
          <stop offset="100%" stop-color="rgba(255,255,255,0)" />
        </radialGradient>
        <radialGradient id="glowBottom" cx="0.78" cy="0.82" r="0.34">
          <stop offset="0%" stop-color="${palette.bottom}" />
          <stop offset="100%" stop-color="rgba(255,255,255,0)" />
        </radialGradient>
        <filter id="shadow" x="-20%" y="-20%" width="140%" height="160%">
          <feDropShadow dx="0" dy="30" stdDeviation="42" flood-color="rgba(0,0,0,0.45)" />
        </filter>
        <clipPath id="screenClip">
          <rect x="0" y="0" width="${frameWidth}" height="${frameHeight}" rx="52" ry="52" />
        </clipPath>
      </defs>
      <rect width="${WIDTH}" height="${HEIGHT}" rx="44" fill="url(#bg)" />
      <rect width="${WIDTH}" height="${HEIGHT}" rx="44" fill="url(#glowTop)" />
      <rect width="${WIDTH}" height="${HEIGHT}" rx="44" fill="url(#glowBottom)" />
      ${buildStars()}
      <text
        x="${TITLE_X}"
        y="${TITLE_Y}"
        fill="rgba(244,245,247,0.98)"
        font-size="${TITLE_FONT_SIZE}"
        font-family="${titleFamily}"
        font-weight="600"
        letter-spacing="-3"
      >${titleTspans}</text>
      <g transform="translate(${frameX} ${frameY}) rotate(${rotation} ${frameWidth / 2} ${frameHeight / 2})" filter="url(#shadow)">
        <rect width="${frameWidth}" height="${frameHeight}" rx="52" fill="rgba(15,15,16,0.84)" />
        <image
          href="${imageData}"
          x="0"
          y="0"
          width="${frameWidth}"
          height="${frameHeight}"
          preserveAspectRatio="xMidYMid slice"
          clip-path="url(#screenClip)"
        />
        <rect width="${frameWidth}" height="${frameHeight}" rx="52" fill="none" stroke="rgba(255,255,255,0.1)" />
      </g>
    </svg>
  `;

  return sharp(Buffer.from(svg))
    .flatten({ background: "#060607" })
    .removeAlpha()
    .png()
    .toBuffer();
}

async function exportLocale(locale, slides) {
  const outputDir = path.join(outputRoot, locale);
  await fs.rm(outputDir, { recursive: true, force: true });
  await fs.mkdir(outputDir, { recursive: true });

  for (const slide of slides) {
    const fileName = `${slide.index}-${slugify(slide.title) || "slide"}.png`;
    const png = await createSlide(locale, slide);
    await fs.writeFile(path.join(outputDir, fileName), png);
  }
}

const target = process.argv[2] ?? "all";

if (target === "zh" || target === "all") {
  await exportLocale("zh", zhSlides);
}

if (target === "en" || target === "all") {
  await exportLocale("en", enSlides);
}

console.log(`Exported screenshots to ${outputRoot}`);
