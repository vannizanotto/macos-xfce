#!/usr/bin/env python3
# Genera il logo "ciliegia" per il boot splash Plymouth (e una preview).
# Disegna le stesse forme di assets/icons/cherry-logo.svg con pycairo.
import sys, os, cairo

def draw(ctx, s):
    ctx.scale(s / 48.0, s / 48.0)
    # gambo
    ctx.set_source_rgb(0x5a/255, 0x3b/255, 0x1a/255)
    ctx.set_line_width(2.6); ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.move_to(30, 7); ctx.curve_to(26, 14, 24, 19, 24, 24); ctx.stroke()
    # foglia
    ctx.set_source_rgb(0x3a/255, 0xa6/255, 0x55/255)
    ctx.move_to(30, 7); ctx.curve_to(36, 2, 43, 4.5, 44.5, 10)
    ctx.curve_to(38, 12, 31.5, 10.5, 30, 7); ctx.close_path(); ctx.fill()
    # ciliegia (una sola)
    ctx.set_source_rgb(0xe0/255, 0x16/255, 0x2b/255)
    ctx.arc(24, 34, 11, 0, 6.2832); ctx.fill()
    # riflesso
    ctx.set_source_rgba(1, 0.48, 0.48, 0.85)
    ctx.save(); ctx.translate(20, 30); ctx.scale(3.2, 2.4)
    ctx.arc(0, 0, 1, 0, 6.2832); ctx.fill(); ctx.restore()

def render(size, path, bg=None):
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, size, size)
    ctx = cairo.Context(surf)
    if bg:
        ctx.set_source_rgb(*bg); ctx.paint()
    draw(ctx, size)
    surf.write_to_png(path)

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    render(150, os.path.join(out, "logo.png"))                  # plymouth (trasparente)
    render(160, os.path.join(out, "cherry-preview.png"), bg=(1, 1, 1))  # preview su bianco
    print("ok:", out)
