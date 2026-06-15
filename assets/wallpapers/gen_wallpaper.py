#!/usr/bin/env python3
# Genera sfondi a gradiente LIBERI (niente asset Apple), con la parte alta
# colorata e satura così il blur della menu bar si vede. Output:
#   gradient-light.jpg  -> wallpaper desktop
#   gradient-dark.jpg   -> sfondo del greeter (sotto il velo scuro)
import sys, os
from PIL import Image

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def gradient(w, h, stops):
    """stops = [(pos0..1, (r,g,b)), ...] ordinati per pos. Gradiente verticale."""
    img = Image.new("RGB", (1, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        # trova il segmento
        for i in range(len(stops) - 1):
            p0, c0 = stops[i]; p1, c1 = stops[i + 1]
            if p0 <= t <= p1:
                lt = 0 if p1 == p0 else (t - p0) / (p1 - p0)
                px[0, y] = lerp(c0, c1, lt); break
        else:
            px[0, y] = stops[-1][1]
    return img.resize((w, h))

# "Big Sur aurora": teal in alto -> blu -> magenta in basso. La parte alta
# satura fa risaltare il blur della menu bar.
LIGHT = [(0.0, (25, 195, 178)), (0.45, (46, 107, 255)), (1.0, (193, 58, 255))]
DARK  = [(0.0, (34, 46, 92)), (0.5, (44, 32, 74)), (1.0, (14, 15, 24))]

def main(out):
    W, H = 2560, 1600
    gradient(W, H, LIGHT).save(os.path.join(out, "gradient-light.jpg"), quality=88)
    gradient(W, H, DARK ).save(os.path.join(out, "gradient-dark.jpg"),  quality=88)
    print("ok:", out)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__)))
