import { spawnSync } from "node:child_process";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import zlib from "node:zlib";

const assetDir = path.resolve("apps/desktop/assets");
const iconsetDir = path.join(assetDir, "TabFix.iconset");
const outputIcns = path.join(assetDir, "tab-fix.icns");
const outputMenubarPng = path.join(assetDir, "tab-fix-menubar.png");

const pngFiles = [
  ["icon_16x16.png", 16],
  ["icon_16x16@2x.png", 32],
  ["icon_32x32.png", 32],
  ["icon_32x32@2x.png", 64],
  ["icon_128x128.png", 128],
  ["icon_128x128@2x.png", 256],
  ["icon_256x256.png", 256],
  ["icon_256x256@2x.png", 512],
  ["icon_512x512.png", 512],
  ["icon_512x512@2x.png", 1024]
];

rmSync(iconsetDir, { recursive: true, force: true });
mkdirSync(iconsetDir, { recursive: true });

for (const [fileName, size] of pngFiles) {
  writeFileSync(path.join(iconsetDir, fileName), renderLogoPng(size));
}

writeFileSync(outputMenubarPng, renderLogoPng(44));

const result = spawnSync("iconutil", ["-c", "icns", iconsetDir, "-o", outputIcns], {
  stdio: "inherit"
});

if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

function renderLogoPng(size) {
  const pixels = Buffer.alloc(size * size * 4);
  const scale = size / 96;
  const rect = {
    x: 10 * scale,
    y: 10 * scale,
    width: 76 * scale,
    height: 76 * scale,
    radius: 12 * scale
  };
  const red = [223, 55, 45, 255];
  const white = [255, 253, 249, 255];

  for (let y = 0; y < size; y += 1) {
    for (let x = 0; x < size; x += 1) {
      const index = (y * size + x) * 4;

      if (insideRoundedRect(x + 0.5, y + 0.5, rect)) {
        pixels.set(red, index);
      }

      if (insideT(x + 0.5, y + 0.5, scale)) {
        pixels.set(white, index);
      }
    }
  }

  return encodePng(size, size, pixels);
}

function insideT(x, y, scale) {
  const top = x >= 30 * scale && x <= 66 * scale && y >= 28 * scale && y <= 40 * scale;
  const stem = x >= 42 * scale && x <= 54 * scale && y >= 40 * scale && y <= 70 * scale;
  return top || stem;
}

function insideRoundedRect(x, y, rect) {
  const right = rect.x + rect.width;
  const bottom = rect.y + rect.height;

  if (x < rect.x || x > right || y < rect.y || y > bottom) {
    return false;
  }

  const innerLeft = rect.x + rect.radius;
  const innerRight = right - rect.radius;
  const innerTop = rect.y + rect.radius;
  const innerBottom = bottom - rect.radius;

  if ((x >= innerLeft && x <= innerRight) || (y >= innerTop && y <= innerBottom)) {
    return true;
  }

  const cornerX = x < innerLeft ? innerLeft : innerRight;
  const cornerY = y < innerTop ? innerTop : innerBottom;
  return Math.hypot(x - cornerX, y - cornerY) <= rect.radius;
}

function encodePng(width, height, rgba) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const raw = Buffer.alloc((width * 4 + 1) * height);

  for (let y = 0; y < height; y += 1) {
    const rawOffset = y * (width * 4 + 1);
    raw[rawOffset] = 0;
    rgba.copy(raw, rawOffset + 1, y * width * 4, (y + 1) * width * 4);
  }

  return Buffer.concat([
    signature,
    chunk("IHDR", Buffer.concat([
      uint32(width),
      uint32(height),
      Buffer.from([8, 6, 0, 0, 0])
    ])),
    chunk("IDAT", zlib.deflateSync(raw)),
    chunk("IEND", Buffer.alloc(0))
  ]);
}

function chunk(type, data) {
  const typeBuffer = Buffer.from(type);
  return Buffer.concat([
    uint32(data.length),
    typeBuffer,
    data,
    uint32(crc32(Buffer.concat([typeBuffer, data])))
  ]);
}

function uint32(value) {
  const buffer = Buffer.alloc(4);
  buffer.writeUInt32BE(value >>> 0);
  return buffer;
}

function crc32(buffer) {
  let crc = 0xffffffff;

  for (const byte of buffer) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
  }

  return (crc ^ 0xffffffff) >>> 0;
}
