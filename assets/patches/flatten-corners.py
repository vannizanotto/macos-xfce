#!/usr/bin/env python3
# Appiattisce a quadro gli angoli SUPERIORI del tema xfwm4, così picom può
# arrotondare tutti e 4 gli angoli in modo uniforme (top disegnati dal tema +
# bottom da picom non combaciano mai). Riempie il quarto trasparente di ogni
# PNG d'angolo col colore della titlebar (campionato dal bordo inferiore opaco).
#
# Uso: flatten-corners.py /percorso/al/tema/xfwm4
import sys, os
from PIL import Image

CORNERS = ["top-left-active.png", "top-right-active.png",
           "top-left-inactive.png", "top-right-inactive.png"]

def titlebar_color(im):
    """Colore opaco più frequente sull'ultima riga (= fill titlebar)."""
    w, h = im.size
    px = im.load()
    counts = {}
    for x in range(w):
        r, g, b, a = px[x, h - 1]
        if a > 250:
            counts[(r, g, b, 255)] = counts.get((r, g, b, 255), 0) + 1
    if not counts:
        return (214, 214, 214, 255)  # fallback grigio chiaro
    return max(counts, key=counts.get)

def flatten(path):
    im = Image.open(path).convert("RGBA")
    fill = titlebar_color(im)
    bg = Image.new("RGBA", im.size, fill)
    bg.alpha_composite(im)          # mette l'angolo originale sopra il fondo pieno
    bg.save(path)

def main(xfwm_dir):
    if not os.path.isdir(xfwm_dir):
        print("dir non trovata:", xfwm_dir); return 1
    bak = os.path.join(xfwm_dir, "_backup_corners")
    os.makedirs(bak, exist_ok=True)
    done = 0
    for name in CORNERS:
        p = os.path.join(xfwm_dir, name)
        if not os.path.isfile(p):
            continue
        b = os.path.join(bak, name)
        if not os.path.exists(b):
            Image.open(p).save(b)   # backup una volta
        flatten(p)
        done += 1
    print(f"angoli appiattiti: {done} (backup in {bak})")
    return 0

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("uso: flatten-corners.py <tema>/xfwm4"); sys.exit(2)
    sys.exit(main(sys.argv[1]))
