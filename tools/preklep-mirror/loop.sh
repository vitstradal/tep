#!/bin/bash
# Obnoví zrcadlo po `touch $BASE/refresh` (a jednou denně); běží v kontejneru preklep-mirror.
set -u
BASE=${BASE:-/mirror}
umask 022

run() {
  echo "$(date -Is) export"
  if ! mongosh --quiet "$MONGO_URL" /app/mirror.js; then
    echo "$(date -Is) CHYBA exportu, viz docker logs preklep-mirror" > "$BASE/stamp"
  fi
}

run
while sleep 2; do
  if [ "$BASE/refresh" -nt "$BASE/stamp" ] || [ -z "$(find "$BASE/stamp" -mmin -1440 2>/dev/null)" ]; then
    run
  fi
done
