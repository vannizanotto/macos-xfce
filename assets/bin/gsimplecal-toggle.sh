#!/bin/bash
# Toggle robusto per gsimplecal: chiude sempre un'eventuale istanza rimasta
# appesa (finestra fantasma), altrimenti la apre. Evita il popup orfano.
if pgrep -x gsimplecal >/dev/null; then
    pkill -x gsimplecal
else
    gsimplecal
fi
