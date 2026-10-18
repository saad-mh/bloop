"""Pull the <svg id="asset"> element out of a design-canvas artboard file.

Usage: python3 -I tool/extract_icon_svg.py <artboard.dc.html> <out.svg>
"""
import re
import sys

html = open(sys.argv[1], encoding="utf-8").read()
svg = re.search(r'<svg id="asset" data-asset=.*?</svg>', html, re.S).group(0)
svg = re.sub(r'\s+data-[a-z]+="[^"]*"', "", svg)
svg = svg.replace('<svg id="asset"', "<svg", 1)
open(sys.argv[2], "w", encoding="utf-8").write(svg + "\n")
