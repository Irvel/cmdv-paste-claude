# CmdV Paste Claude

A macOS menu bar app that automatically converts clipboard images to files, making them compatible with apps like Claude that expect file attachments rather than raw image data.

## What it does

When you copy an image (Cmd+C) or take a screenshot (Cmd+Shift+3/4/5), this app automatically:

1. Detects the image in your clipboard
2. Saves it as a PNG file in a temp directory
3. Replaces the clipboard contents with a file reference

This allows you to paste images directly into Claude and other apps that don't accept raw image data from the clipboard.

## Features

- Runs silently in the menu bar
- Automatically converts clipboard images on copy/screenshot
- Manual "Convert Now" option in the menu
- Launch at Login support
- Cleans up temp files older than 1 hour

## Requirements

- macOS 13.0+
- Accessibility permissions (required to monitor keyboard events)

## Building

```bash
./build.sh
```

Then drag `CmdVPasteClaude.app` to `/Applications`.

## Icon Conversion

To convert a JPEG icon to macOS `.icns` format with transparent corners:

```bash
# 1. Trim, resize, and make corners transparent
magick icon.jpeg \
  -fuzz 3% -trim +repage \
  -filter Lanczos -resize 1024x1024! \
  icon_base.png

magick icon_base.png \
  -fuzz 10% -fill none \
  -draw "color 0,0 floodfill" \
  -draw "color 1023,0 floodfill" \
  -draw "color 0,1023 floodfill" \
  -draw "color 1023,1023 floodfill" \
  icon_transparent.png

# 2. Generate iconset with all required sizes
mkdir -p icon.iconset
for size in 16 32 128 256 512; do
  magick icon_transparent.png -filter Lanczos -resize ${size}x${size} icon.iconset/icon_${size}x${size}.png
  doublesize=$((size * 2))
  magick icon_transparent.png -filter Lanczos -resize ${doublesize}x${doublesize} icon.iconset/icon_${size}x${size}@2x.png
done

# 3. Create .icns file
iconutil -c icns icon.iconset -o AppIcon.icns

# 4. Clean up
rm -rf icon.iconset icon_base.png icon_transparent.png
```

Requires ImageMagick (`brew install imagemagick`).
