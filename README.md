# IPTV Player

Native macOS IPTV Player App mit VLC-basiertem Streaming.

## Features

- **Live TV** - Kategorien, Kanalsuche, EPG-Anzeige
- **Filme** - Cover-Grid, Film-Infos (Genre, Cast, Plot), Fortschrittsanzeige
- **Serien** - Staffel/Episoden-Navigation, Watched-Status
- **Profil-System** - Mehrere Playlists/Accounts verwalten
- **Watch Progress** - Fortschritt wird pro Profil gespeichert
- **Video-Fullscreen** - Separates Fullscreen-Fenster nur fuer Video
- **Xtream Codes API** - Kompatibel mit allen Xtream-basierten IPTV-Servern

## Voraussetzungen

- macOS 14.0+
- Xcode 15+
- CocoaPods

## Installation (Entwicklung)

```bash
# Repository klonen
git clone https://github.com/DEIN-USERNAME/IPTV.git
cd IPTV

# Xcode-Projekt generieren
brew install xcodegen   # falls nicht installiert
xcodegen generate

# Dependencies installieren
pod install

# In Xcode oeffnen (immer .xcworkspace!)
open "IPTV Player.xcworkspace"
```

## Download

Fertige `.dmg` Dateien findest du unter [Releases](../../releases).

## Tech Stack

- SwiftUI + AppKit
- VLCKit (via CocoaPods)
- Xtream Codes API
- XcodeGen
