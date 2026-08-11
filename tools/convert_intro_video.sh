#!/usr/bin/env bash
# The opening intro, converted for Godot.
#
# Godot's VideoStreamPlayer plays exactly ONE container: Ogg Theora (.ogv). It
# does not play MP4/H.264, and it fails quietly — the node sits there showing
# nothing rather than reporting an unsupported format, which is a genuinely
# horrible afternoon if you do not know this going in. So the source stays
# wherever it was authored and this produces the file the game actually ships.
#
# Quality: -q:v 7 of 10. Theora is an old codec and needs a higher quality
# number than H.264 would to look equivalent; below about 6 the dark office
# footage bands badly in the gradients, which is most of this trailer.
#
# Usage:  tools/convert_intro_video.sh <source.mp4>
set -euo pipefail

SRC="${1:-$HOME/Downloads/hooshang_trailer_v3.mp4}"
OUT="$(dirname "$0")/../assets/video/intro.ogv"

mkdir -p "$(dirname "$OUT")"
ffmpeg -y -i "$SRC" -c:v libtheora -q:v 7 -c:a libvorbis -q:a 4 "$OUT"
echo "wrote $OUT"
