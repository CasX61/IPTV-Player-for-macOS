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
- **Auto-Update** - Neue Versionen werden ueber GitHub Releases erkannt und installiert (Sparkle)

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

## Release erstellen

```bash
git tag v1.0.3
git push origin v1.0.3
```

Der Workflow baut die App (Version aus dem Tag), erstellt die DMG und den Sparkle-Appcast
(`appcast.xml`) und veroeffentlicht beides als GitHub Release. Installierte Apps finden das
Update ueber `releases/latest/download/appcast.xml`.

Voraussetzung: Repository-Secret `SPARKLE_PRIVATE_KEY` (privater EdDSA-Schluessel, im
Schluesselbund unter dem Account `iptv-player` gespeichert, Export mit
`Pods/Sparkle/bin/generate_keys --account iptv-player -x <datei>`).

## Tech Stack

- SwiftUI + AppKit
- VLCKit (via CocoaPods)
- Sparkle (via CocoaPods)
- Xtream Codes API
- XcodeGen
