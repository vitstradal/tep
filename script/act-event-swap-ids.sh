#!/bin/bash
##
# act-event-swap-ids.sh — prohodí id dvou akcí (act_events) i s přihláškami
# a pozvánkami, takže /act/events/A ukáže dosavadní akci B a naopak.
#
# Použití (root na pikomatu):
#   act-event-swap-ids.sh A B            jen ukáže, co by prohodil
#   act-event-swap-ids.sh --proved A B   zazálohuje dotčené tabulky a prohodí
set -euo pipefail

TEP_DB=${TEP_DB:-tep_db}
PG_PORT=${PG_PORT:-5432}
BACKUP_DIR=${BACKUP_DIR:-/home/backup/act-event-swap}

proved=0
if [[ ${1:-} == --proved ]]; then proved=1; shift; fi
[[ $# == 2 && $1 =~ ^[0-9]+$ && $2 =~ ^[0-9]+$ && $1 != "$2" ]] || { sed -n '3,8p' "$0"; exit 1; }
a=$1 b=$2

psql() { sudo -u postgres psql -p "$PG_PORT" -d "$TEP_DB" -v ON_ERROR_STOP=1 -v a="$a" -v b="$b" "$@"; }

psql -q <<'SQL'
\echo == akce:
select id, event_start, title from act_events where id in (:a, :b) order by id;
\echo == přihlášky a pozvánky:
select id, (select count(*) from act_event_participants p where p.event_id = e.id) as prihlasky,
       (select count(*) from act_event_invitations i where i.event_id = e.id) as pozvanky
  from act_events e where id in (:a, :b) order by id;
SQL

n=$(psql -Atc "select count(*) from act_events where id in ($a, $b)")
[[ $n == 2 ]] || { echo "obě akce $a a $b musí existovat" >&2; exit 1; }

if (( ! proved )); then
  echo "nic nezměněno; prohodí: $0 --proved $a $b"
  exit 0
fi

mkdir -p "$BACKUP_DIR"
zaloha="$BACKUP_DIR/act-events-$a-$b-$(date +%Y%m%d-%H%M%S).sql"
sudo -u postgres pg_dump -p "$PG_PORT" -d "$TEP_DB" --data-only \
  -t act_events -t act_event_participants -t act_event_invitations > "$zaloha"
echo "== záloha: $zaloha"

psql -q <<'SQL'
begin;
\set t -1
update act_events set id = :t where id = :a;
update act_events set id = :a where id = :b;
update act_events set id = :b where id = :t;
update act_event_participants set event_id = :t where event_id = :a;
update act_event_participants set event_id = :a where event_id = :b;
update act_event_participants set event_id = :b where event_id = :t;
update act_event_invitations set event_id = :t where event_id = :a;
update act_event_invitations set event_id = :a where event_id = :b;
update act_event_invitations set event_id = :b where event_id = :t;
commit;
\echo == po prohození:
select id, event_start, title from act_events where id in (:a, :b) order by id;
SQL
