#!/bin/bash
# Clock per genmon: mostra data+ora stile macOS e apre gsimplecal al click sul testo.
echo "<txt> $(LC_TIME=it_IT.UTF-8 date '+%a %d %b  %H:%M') </txt>"
echo "<txtclick>gsimplecal</txtclick>"
