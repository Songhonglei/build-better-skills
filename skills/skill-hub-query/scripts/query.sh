#!/usr/bin/env bash
# skill-hub-query: query the local cache
# Usage:
#   bash query.sh keyword <kw>
#   bash query.sh time today | this_week | last_week | this_month | last_N_days | YYYY-MM-DD | YYYY-MM-DD:YYYY-MM-DD
#   bash query.sh author <author> [--exact]
#   bash query.sh slug <exact-slug>
#   bash query.sh combo --keyword=xx --since=YYYY-MM-DD --author=xx --source=official [--exact]
set -euo pipefail
SELF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./_lib.sh
source "${SELF_DIR}/_lib.sh"

setup_legacy_notice

if [[ ! -f "$CACHE_FILE" ]]; then
  echo "[error] Cache not found. Run: bash $SELF_DIR/sync.sh" >&2
  echo "        If this is your first use, also run: bash $SELF_DIR/doctor.sh" >&2
  exit 1
fi

MODE="${1:-}"
shift || true

# ---------- Time range parser ----------
# Output: epoch ms on stdout; on failure, write error to stderr and return non-zero
parse_time_to_ms() {
  local arg="$1"
  case "$arg" in
    today)
      date -d "today 00:00:00" +%s%3N 2>/dev/null || \
        python3 -c "import datetime as d;t=d.datetime.combine(d.date.today(),d.time.min);print(int(t.timestamp()*1000))"
      ;;
    this_week)
      date -d "last monday 00:00:00" +%s%3N 2>/dev/null || \
        python3 -c "import datetime as d;t=d.date.today();m=t-d.timedelta(days=t.weekday());print(int(d.datetime.combine(m,d.time.min).timestamp()*1000))"
      ;;
    last_week)
      date -d "last monday -7 days 00:00:00" +%s%3N 2>/dev/null || \
        python3 -c "import datetime as d;t=d.date.today();m=t-d.timedelta(days=t.weekday()+7);print(int(d.datetime.combine(m,d.time.min).timestamp()*1000))"
      ;;
    this_month)
      date -d "$(date +%Y-%m-01) 00:00:00" +%s%3N
      ;;
    last_*_days)
      local n
      n="$(echo "$arg" | sed -E 's/last_([0-9]+)_days/\1/')"
      date -d "${n} days ago 00:00:00" +%s%3N
      ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      date -d "${arg} 00:00:00" +%s%3N
      ;;
    *)
      echo "[error] Unsupported time range: $arg" >&2
      echo "        Valid: today / this_week / last_week / this_month / last_N_days / YYYY-MM-DD / YYYY-MM-DD:YYYY-MM-DD" >&2
      return 1
      ;;
  esac
}

# End-of-day timestamp (YYYY-MM-DD 23:59:59.999)
day_end_ms() {
  local d="$1"
  date -d "${d} 23:59:59" +%s%3N
}

# Common jq filter builder (uses --arg/--argjson, no shell injection)
# Args: keyword author source since(ms) until(ms) [exact=0/1]
#       empty string means "don't filter on this dimension"
#       exact=1 means author matches owner.handle / .email / .displayName exactly,
#       otherwise default contains-substring (backwards compatible)
run_combo_filter() {
  local kw="${1:-}" author="${2:-}" src="${3:-}" since="${4:-0}" until="${5:-0}" exact="${6:-0}"
  # Lowercase keyword via jq (avoid shell `tr` byte-level handling for UTF-8 input)
  local kw_lower
  kw_lower="$(echo "$kw" | jq -Rr 'ascii_downcase' 2>/dev/null || echo "$kw")"
  local result
  result="$(jq \
    --arg kw "$kw_lower" \
    --arg author "$author" \
    --arg src "$src" \
    --argjson since "$since" \
    --argjson until "$until" \
    --argjson exact "$exact" \
    '
    [to_entries[].value | select(
      (
        ($kw == "")
        or (.slug // "" | ascii_downcase | contains($kw))
        or (.displayName // "" | ascii_downcase | contains($kw))
        or (.summary // "" | ascii_downcase | contains($kw))
      )
      and
      (
        ($author == "")
        or (
          if $exact == 1 then
            ((.owner.displayName // "") == $author)
            or ((.owner.handle // "") == $author)
            or ((.owner.email // "") == $author)
          else
            (.owner.displayName // "" | contains($author))
            or (.owner.handle // "" | contains($author))
            or (.owner.email // "" | contains($author))
          end
        )
      )
      and
      (
        ($src == "") or (.source == $src)
      )
      and
      (
        ($since == 0) or ((.updatedAt // 0) >= $since)
      )
      and
      (
        ($until == 0) or ((.updatedAt // 0) <= $until)
      )
    )] | sort_by(.updatedAt) | reverse
    ' "$CACHE_FILE")"

  if [[ "$(echo "$result" | jq 'length' 2>/dev/null || echo 0)" == "0" ]]; then
    echo "[info] No matching skill. Try:" >&2
    echo "       - different keyword or check spelling" >&2
    echo "       - refresh cache: bash $SELF_DIR/sync.sh --full" >&2
  fi
  echo "$result"
}

case "$MODE" in
  keyword)
    KW="${1:-}"
    if [[ -z "$KW" ]]; then
      echo "[error] keyword: missing argument" >&2
      exit 1
    fi
    run_combo_filter "$KW" "" "" 0 0
    ;;

  time)
    arg="${1:-}"
    if [[ -z "$arg" ]]; then
      echo "[error] time: missing argument" >&2
      exit 1
    fi
    if [[ "$arg" == *":"* ]]; then
      start_str="${arg%:*}"; end_str="${arg#*:}"
      since="$(parse_time_to_ms "$start_str")" || exit 1
      until="$(day_end_ms "$end_str")" || exit 1
      run_combo_filter "" "" "" "$since" "$until"
    elif [[ "$arg" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      since="$(parse_time_to_ms "$arg")" || exit 1
      until="$(day_end_ms "$arg")" || exit 1
      run_combo_filter "" "" "" "$since" "$until"
    else
      since="$(parse_time_to_ms "$arg")" || exit 1
      run_combo_filter "" "" "" "$since" 0
    fi
    ;;

  author)
    A=""
    EXACT=0
    for arg in "$@"; do
      case "$arg" in
        --exact) EXACT=1 ;;
        --*)
          echo "[error] author: unknown flag: $arg (valid: --exact)" >&2
          exit 1
          ;;
        *)
          if [[ -z "$A" ]]; then
            A="$arg"
          else
            echo "[error] author: only one argument allowed; extra: $arg" >&2
            exit 1
          fi
          ;;
      esac
    done
    if [[ -z "$A" ]]; then
      echo "[error] author: missing argument" >&2
      echo "        Usage: bash query.sh author <author> [--exact]" >&2
      echo "        Example (exact): bash query.sh author alice@example.com --exact" >&2
      exit 1
    fi
    run_combo_filter "" "$A" "" 0 0 "$EXACT"
    ;;

  slug)
    S="${1:-}"
    if [[ -z "$S" ]]; then
      echo "[error] slug: missing argument" >&2
      exit 1
    fi
    slug_result="$(jq --arg s "$S" '.[$s] // null' "$CACHE_FILE")"
    if [[ "$slug_result" == "null" ]]; then
      echo "[info] Slug '$S' not found in cache. May be: typo / stale cache / removed." >&2
      echo "       Try: bash $SELF_DIR/sync.sh --full and re-query, or use 'keyword' for fuzzy search." >&2
    fi
    echo "$slug_result"
    ;;

  combo)
    KW=""; AUTHOR=""; SOURCE=""; SINCE=0; UNTIL=0; EXACT=0
    for arg in "$@"; do
      case "$arg" in
        --keyword=*) KW="${arg#*=}" ;;
        --author=*)  AUTHOR="${arg#*=}" ;;
        --source=*)  SOURCE="${arg#*=}" ;;
        --exact)     EXACT=1 ;;
        --since=*)
          SINCE="$(parse_time_to_ms "${arg#*=}")" || exit 1
          ;;
        --until=*)
          if [[ "${arg#*=}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            UNTIL="$(day_end_ms "${arg#*=}")"
          else
            UNTIL="$(parse_time_to_ms "${arg#*=}")" || exit 1
          fi
          ;;
        *)
          echo "[error] combo: unknown flag: $arg" >&2
          echo "        Valid: --keyword=xx --author=xx --source=official|personal|external --since=YYYY-MM-DD --until=YYYY-MM-DD [--exact]" >&2
          exit 1
          ;;
      esac
    done
    if [[ -n "$SOURCE" && "$SOURCE" != "official" && "$SOURCE" != "personal" && "$SOURCE" != "external" ]]; then
      echo "[error] --source must be one of: official / personal / external (got: $SOURCE)" >&2
      exit 1
    fi
    run_combo_filter "$KW" "$AUTHOR" "$SOURCE" "$SINCE" "$UNTIL" "$EXACT"
    ;;

  *)
    cat >&2 <<EOF
Usage:
  bash query.sh keyword <kw>
  bash query.sh time today | this_week | last_week | this_month | last_N_days | YYYY-MM-DD | YYYY-MM-DD:YYYY-MM-DD
  bash query.sh author <author> [--exact]
  bash query.sh slug <exact-slug>
  bash query.sh combo --keyword=xx --author=xx --source=official|personal|external --since=YYYY-MM-DD --until=YYYY-MM-DD [--exact]

Notes:
  author / combo default to substring (contains) matching.
  With --exact, owner.email / owner.handle / owner.displayName must match exactly,
  which is useful when an exact handle/email needs to be locked in
  (e.g. avoid 'alice' matching 'alice2' too).
EOF
    exit 1
    ;;
esac
