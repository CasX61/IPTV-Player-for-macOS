#!/bin/bash
# Erzeugt den Sparkle-Appcast (appcast.xml) fuer ein Release.
#
# Verwendung:
#   SPARKLE_PRIVATE_KEY=... scripts/make-appcast.sh <dmg> <version> <build> <download-url> <notes-url> [notes.txt] > appcast.xml
#
# notes.txt: optional, eine Aenderung pro Zeile (wird als Liste angezeigt)

set -euo pipefail

DMG="$1"
VERSION="$2"
BUILD="$3"
DOWNLOAD_URL="$4"
NOTES_URL="$5"
NOTES_FILE="${6:-}"

SIGN_UPDATE="$(dirname "$0")/../Pods/Sparkle/bin/sign_update"

if [ -z "${SPARKLE_PRIVATE_KEY:-}" ]; then
    echo "Fehler: SPARKLE_PRIVATE_KEY ist nicht gesetzt" >&2
    exit 1
fi

# DMG signieren -> 'sparkle:edSignature="..." length="..."'
SIGNATURE="$(echo "$SPARKLE_PRIVATE_KEY" | "$SIGN_UPDATE" --ed-key-file - "$DMG")"
if [[ "$SIGNATURE" != *"sparkle:edSignature="* ]]; then
    echo "Fehler: Signieren fehlgeschlagen: $SIGNATURE" >&2
    exit 1
fi

# Versionshinweise als HTML-Liste (Sonderzeichen escapen)
NOTES_HTML=""
if [ -n "$NOTES_FILE" ] && [ -s "$NOTES_FILE" ]; then
    NOTES_HTML="<ul>$(sed -e '/^[[:space:]]*$/d' \
        -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
        -e 's/.*/<li>&<\/li>/' "$NOTES_FILE" | tr -d '\n')</ul>"
fi

PUB_DATE="$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")"

cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>IPTV Player</title>
        <item>
            <title>Version $VERSION</title>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>$BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <sparkle:fullReleaseNotesLink>$NOTES_URL</sparkle:fullReleaseNotesLink>
            <description><![CDATA[<h2>IPTV Player $VERSION</h2>$NOTES_HTML]]></description>
            <enclosure url="$DOWNLOAD_URL" type="application/octet-stream" $SIGNATURE />
        </item>
    </channel>
</rss>
EOF
