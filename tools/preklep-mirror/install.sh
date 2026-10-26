#!/bin/bash
# Instalace zrcadla překlepu (kontejner preklep-mirror vedle Overleafu). Spouští root na pikomatu:
#   tools/preklep-mirror/install.sh
# Opakovatelné; po změně mirror.js/loop.sh stačí pustit znovu.
set -euo pipefail

SRC=$(cd "$(dirname "$0")" && pwd)
APP=/usr/local/lib/preklep-mirror
BASE=/home/pikomat/preklep-mirror.d
LINK=/home/pikomat/preklep-mirror
DATA=/home/www/overleaf/data/overleaf/data
GROUP=pikomat

[ "$(id -u)" = 0 ] || { echo "spusť jako root" >&2; exit 1; }
IMAGE=$(docker inspect -f '{{.Config.Image}}' mongo)
GID=$(getent group "$GROUP" | cut -d: -f3)
OWNER=$(stat -c %u "$DATA/user_files")
echo "obraz $IMAGE, uživatel $OWNER:$GID"

install -d -o root -g root -m 755 "$APP"
install -o root -g root -m 644 "$SRC/mirror.js" "$SRC/loop.sh" "$APP/"
sed -e "s|@IMAGE@|$IMAGE|" -e "s|@USER@|$OWNER:$GID|" -e "s|@DATA@|$DATA|" -e "s|@BASE@|$BASE|" \
    "$SRC/compose.yml" > "$APP/compose.yml"
chmod 644 "$APP/compose.yml"

install -d -o "$OWNER" -g "$GROUP" -m 2775 "$BASE"
[ -e "$BASE/refresh" ] || install -o "$OWNER" -g "$GROUP" -m 664 /dev/null "$BASE/refresh"

# dosavadní zrcadlo (adresář) se přesune jako první generace, nic se nemaže
if [ -d "$LINK" ] && [ ! -L "$LINK" ]; then
  mv "$LINK" "$BASE/gen-0"
  chown -R "$OWNER:$GROUP" "$BASE/gen-0"
  ln -sfn gen-0 "$BASE/current"
fi
ln -sfn preklep-mirror.d/current "$LINK"

docker compose -f "$APP/compose.yml" up -d --force-recreate

echo -n "čekám na první export"
before=$(stat -c %Y "$BASE/stamp" 2>/dev/null || echo 0)
for _ in $(seq 90); do
  now=$(stat -c %Y "$BASE/stamp" 2>/dev/null || echo 0)
  if [ "$now" != "$before" ]; then echo; head -1 "$BASE/stamp"; ls -l "$LINK" "$BASE/current"; exit 0; fi
  echo -n .; sleep 2
done
echo; echo "export nedoběhl, viz: docker logs preklep-mirror" >&2
exit 1
