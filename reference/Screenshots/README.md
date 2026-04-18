# App Store Screenshots

This folder is isolated from the website (`site`) and contains all screenshot-related assets and scripts.

## Structure

- `screenshots_en/*.png`: English source screenshots
- `screenshots_zh/*.png`: Chinese source screenshots
- `slides.js`: Titles and layout config
- `export.mjs`: PNG export script
- `exports/{en,zh}/*.png`: Generated App Store screenshots (`1242x2688`)

## Usage

```bash
cd reference/screenshots
npm install
npm run export
```

Optional:

```bash
npm run export:zh
npm run export:en
```
