#!/usr/bin/env bash
# Renders the launcher, adaptive, notification, splash and logo PNGs from the
# SVG sources in assets/icons/src. Needs rsvg-convert (librsvg).
set -euo pipefail

cd "$(dirname "$0")/.."
src=assets/icons/src
res=android/app/src/main/res

render() { rsvg-convert -w "$2" -h "$2" "$1" -o "$3"; }

# Sources the other tools read directly.
render "$src/icon-master-1024.svg" 1024 assets/icons/icon-master-1024.png
render "$src/play-store-512.svg" 512 assets/icons/play-store-512.png
render "$src/splash-960.svg" 960 assets/icons/splash-960.png
render "$src/logo-mark-512.svg" 512 assets/icons/logo-mark-512.png
render "$src/adaptive-foreground-432.svg" 432 assets/icons/adaptive-foreground-432.png
render "$src/adaptive-monochrome-432.svg" 432 assets/icons/adaptive-monochrome-432.png

# density:legacy launcher:adaptive layer:status bar icon
for row in mdpi:48:108:24 hdpi:72:162:36 xhdpi:96:216:48 xxhdpi:144:324:72 xxxhdpi:192:432:96; do
  IFS=: read -r d legacy layer stat <<<"$row"
  mkdir -p "$res/mipmap-$d" "$res/drawable-$d"
  render "$src/icon-master-1024.svg" "$legacy" "$res/mipmap-$d/ic_launcher.png"
  render "$src/adaptive-foreground-432.svg" "$layer" "$res/mipmap-$d/ic_launcher_foreground.png"
  render "$src/adaptive-monochrome-432.svg" "$layer" "$res/mipmap-$d/ic_launcher_monochrome.png"
  render "$src/notification-96.svg" "$stat" "$res/drawable-$d/ic_stat_bloop.png"
done
