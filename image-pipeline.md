Writing down how we got the JPEG icon to a proper icon with transparent corners.


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

Requires ImageMagick (`brew install imagemagick`)
