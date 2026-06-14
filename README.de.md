# macOS-XFCE (Dual-DE: XFCE & Cinnamon)

Verwandelt einen **Linux Mint / Ubuntu Desktop mit XFCE oder Cinnamon** in den **macOS Sonoma**-Stil:
WhiteSur-Theme, SF Pro-Schriftart, Menüleiste mit globalem Menü + Spotlight (XFCE), Plank-Dock,
Compositor mit Unschärfe/Ecken/Schatten/Animationen (picom unter XFCE), Ausschalt-Dialog, Hot
Corners, Mission Control, Touchpad-Gesten, Benachrichtigungen, **Anmeldebildschirm** (Webkit-Greeter)
und **Boot-Splash** (Plymouth).

> Getestet unter Linux Mint 22 (Ubuntu 24.04 noble) + XFCE 4.18 / Cinnamon + LightDM.
> Unter anderen Desktops/Display-Managern müssen einige Teile möglicherweise angepasst werden.

## Vorschau

Menü-Logo (Zitrone statt Apfel):

<img src="docs/lemon-logo.png" width="96" alt="Zitronen-Logo">

> Desktop- und Anmeldebildschirm-Screenshots werden noch hinzugefügt.

## Installation

```bash
git clone https://github.com/vannizanotto/macos-xfce.git && cd macos-xfce
./install.sh                 # Basis (ohne Anmeldebildschirm oder Boot-Splash)
```

Beispiele:

```bash
./install.sh --dpi 192           # mit 2x HiDPI-Skalierung (Retina-ähnliche Bildschirme)
./install.sh --greeter --plymouth   # installiert auch Anmeldebildschirm und Boot-Splash
./install.sh --no-sf-pro            # Inter statt SF Pro verwenden
./install.sh --only picom,power     # nur bestimmte Komponenten neu installieren
./install.sh --yes                  # nicht-interaktiv
```

**Wichtig**: Führen Sie das Skript **als normaler Benutzer** aus, NICHT mit `sudo` (es wird
nach dem Passwort fragen, wo es benötigt wird: Pakete, Greeter, Plymouth). Nach der Installation
**abmelden/anmelden**: Panel, Tastenkombinationen und Autostart werden in der neuen Sitzung angewendet.

### Hauptoptionen

| Option | Effekt |
|---|---|
| `--dpi N` | Legt die Skalierung fest (`Xft.DPI` für XFCE, text-scaling für Cinnamon). Z.B. 144≈1.5×, 192≈2×, 240≈2.5×. Standard: unverändert. |
| `--greeter` | Installiert den nody-greeter Anmeldebildschirm (benötigt die `.deb`, siehe unten). |
| `--plymouth` | Installiert den Zitronen-Boot-Splash (generiert das initramfs neu). |
| `--no-sf-pro` | SF Pro nicht herunterladen, Inter verwenden. |
| `--no-animations` | picom ohne Animationen (keine Kompilierung aus dem Quellcode). |
| `--no-whitesur` | WhiteSur nicht installieren (geht davon aus, dass es bereits vorhanden ist). |
| `--no-packages` | Überspringt `apt install`. |
| `--only LISTE` | Führt nur die aufgelisteten Komponenten aus. |
| `--yes` | Nicht-interaktiver Modus. |

Komponenten für `--only`: `packages,theme,sfpro,panel,dock,scaling,picom,power,corners,touchegg,notify,wallpaper,greeter,plymouth`.

## Anmeldebildschirm (nody-greeter)

Ist nicht in apt: Laden Sie die `.deb` für Ihr Ubuntu aus den Releases des Projekts herunter und installieren Sie sie,
führen Sie dann die Greeter-Komponente aus:

```bash
# https://github.com/JezerM/nody-greeter/releases
sudo apt install ./nody-greeter-*.deb
./install.sh --only greeter
```

Test ohne Abmelden: `nody-greeter --mode debug --theme macos` (im Debug-Modus erscheint ein Popup
"Unable to determine socket to daemon": das ist normal).

## Was NICHT enthalten ist (und warum)

- **SF Pro** — gehört Apple, darf nicht weitergegeben werden. Der Installer **lädt es herunter** vom Apple CDN
  auf Ihren PC (`--no-sf-pro`, um Inter zu verwenden).
- **WhiteSur** (Theme/Symbole/Cursor) — on the fly geklont von
  [vinceliuice](https://github.com/vinceliuice), dann gepatcht (Ecken + monochrome Batterie).
- **Riesige Symbolsets** `WhiteSur` / `WhiteSur-dark` — werden vom Installer von vinceliuice verwaltet.

## Hinweise / Anpassungen

- **HiDPI**: Titelleisten-Schaltflächen und Greeter-px skalieren nicht mit DPI → der Installer wählt die
  xfwm4-Variante (`-hdpi`/`-xhdpi`) basierend auf `--dpi`, aber der Greeter ist für ~2× Bildschirme optimiert.
- **Panel-Höhe**: Der Anti-Überlappungs-Rand (`xfwm4/margin_top`) beträgt 52px. Wenn Sie die
  Panel-Höhe ändern, aktualisieren Sie ihn.
- Die **Unschärfe** der Menüleiste ist nur mit einem bunten oberen Hintergrundbild sichtbar (ein freier Farbverlauf
  `gradient-light.jpg` ist enthalten; generieren Sie ihn neu mit `assets/wallpapers/gen_wallpaper.py`).
- Animationen erfordern `picom-anim` (FT-Labs Fork) aus dem Quellcode kompiliert: Der Installer bittet
  um Bestätigung; verwenden Sie `--no-animations` zum Überspringen.
- **Cinnamon-Unterstützung**: Der Installer verwendet eine Abstraktionsschicht (`lib/de.sh`), um sowohl XFCE als auch Cinnamon nativ zu unterstützen.

## Deinstallation

```bash
./uninstall.sh
```

Stellt vernünftige Standards wieder her, entfernt Autostart/Skripte und die `*.macos-bak`-Backups von
Panel/Tastenkombinationen. Themes, Symbole und Schriftarten müssen manuell entfernt werden.

## Marken und Lizenz

> **Nicht verbunden mit oder unterstützt von Apple Inc.** Dies ist ein *macOS-Stil*-Anpassungsprojekt
> für Linux. "macOS", "SF Pro" und Apple-Marken gehören Apple Inc.

Um Urheberrechts-/Markenprobleme zu minimieren, gibt das Repo **keine Apple-Assets weiter**:

- **Logo**: kein angebissener Apfel → **Zitronen**-Symbol, gefärbt von
  [Noto Emoji](https://github.com/googlefonts/noto-emoji) (Apache-2.0), verwendet im Menü und Boot-Splash.
- **SF Pro Schriftart**: nicht enthalten; der Installer **lädt sie herunter** vom Apple CDN auf Ihren PC oder
  verwendet Inter (`--no-sf-pro`).
- **Hintergrundbild**: keine macOS-Hintergrundbilder, sondern **generierte Farbverläufe** (frei).

Code und Konfiguration: **MIT**. Credits: **Noto Emoji** © Google (**Apache-2.0**),
**WhiteSur** © vinceliuice (**GPL-3.0**, zur Laufzeit geklont).
