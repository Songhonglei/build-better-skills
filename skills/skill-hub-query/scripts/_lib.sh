#!/usr/bin/env bash
# skill-hub-query: shared library
# Path discovery + token reading + curl wrapping with configurable Hub endpoint.
# Sourced by other scripts; not executed directly.
# shellcheck disable=SC2155,SC2034

set -euo pipefail
umask 077   # new cache/tmp files default to owner-only

# ---------- Path discovery ----------
_SELF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SKILL_DIR="$( cd "${_SELF_DIR}/.." && pwd )"

# ---------- Configurable Hub endpoint (env overrides) ----------
# This tool talks to any Hub that implements the documented API contract
# (see SKILL.md "Self-hosted Hub: API contract" + references/api.md).
#
# NOTE: SKILL_HUB_URL has NO baked-in public default because no single public
# Hub is guaranteed to implement this contract. You MUST set it either via env
# or in the credentials file. Examples:
#   export SKILL_HUB_URL="https://hub.your-company.com"
#   export SKILL_HUB_URL="https://my-self-hosted-hub.example"
#
# (clawhub.ai uses a different API surface and has its own CLI: `clawhub`.
#  Use this tool for hubs whose API matches the documented contract.)
HUB_URL="${SKILL_HUB_URL:-}"
HUB_API_PREFIX="${SKILL_HUB_API_PREFIX:-/api/v1/skill}"
HUB_LEGACY_API_PREFIX="${SKILL_HUB_LEGACY_API_PREFIX:-/api/skill}"
HUB_AUTH_HEADER="${SKILL_HUB_AUTH_HEADER:-Authorization}"
HUB_AUTH_SCHEME="${SKILL_HUB_AUTH_SCHEME:-Bearer }"  # trailing space intentional

# Legacy-compat alias (some downstream code historically referenced HUB_BASE)
HUB_BASE="$HUB_URL"

# ---------- XDG-compliant cache & credentials dirs ----------
_XDG_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
_XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

CACHE_DIR="${SKILL_HUB_CACHE_DIR:-${_XDG_CACHE}/skill-hub-query}"
CACHE_FILE="${CACHE_DIR}/skill-cache.json"
CACHE_META="${CACHE_DIR}/skill-cache-meta.json"
VERSIONS_FILE="${CACHE_DIR}/skill-versions.json"

CREDS_DIR="${_XDG_CONFIG}/skill-hub-query"
CREDS_FILE="${SKILL_HUB_TOKEN_FILE:-${CREDS_DIR}/credentials.json}"
CREDS_EXAMPLE="${SKILL_DIR}/credentials.example.json"

mkdir -p "$CACHE_DIR"

# ---------- Skills install directory (resolved at install.sh runtime) ----------
# Order: SKILL_HUB_SKILLS_DIR -> ~/.claude/skills -> ~/.openclaw/workspace/skills
#        -> ~/.config/skills (first existing wins, or first writable created).
resolve_skills_dir() {
  if [[ -n "${SKILL_HUB_SKILLS_DIR:-}" ]]; then
    mkdir -p "$SKILL_HUB_SKILLS_DIR" 2>/dev/null || true
    echo "$SKILL_HUB_SKILLS_DIR"
    return 0
  fi
  local d
  for d in "$HOME/.claude/skills" "$HOME/.openclaw/workspace/skills" "$HOME/.config/skills"; do
    if [[ -d "$d" ]]; then
      echo "$d"
      return 0
    fi
  done
  # None exist; create the first as a sane default
  mkdir -p "$HOME/.claude/skills"
  echo "$HOME/.claude/skills"
}

# ---------- Token reading (env first -> credentials file) ----------
load_token() {
  if [[ -n "${SKILL_HUB_TOKEN:-}" ]]; then
    echo "$SKILL_HUB_TOKEN"
    return 0
  fi
  if [[ -f "$CREDS_FILE" ]]; then
    local t
    t="$(jq -r '.token // empty' "$CREDS_FILE" 2>/dev/null)"
    if [[ -n "$t" && "$t" != "null" && "$t" != "<put-your-token-here>" ]]; then
      echo "$t"
      return 0
    fi
  fi
  return 1
}

# Mask token for safe display: show first 4 + last 2 chars only
mask_token() {
  local t="$1"
  local n=${#t}
  if [[ -z "$t" ]]; then
    echo ""
  elif [[ "$n" -le 8 ]]; then
    echo "***"
  else
    echo "${t:0:4}***${t:$((n-2)):2}"
  fi
}

# Warn (don't block) when credentials file has loose perms on shared machines
check_creds_perms() {
  if [[ -f "$CREDS_FILE" ]]; then
    local perm
    perm="$(stat -c '%a' "$CREDS_FILE" 2>/dev/null || stat -f '%Lp' "$CREDS_FILE" 2>/dev/null || echo "")"
    if [[ -n "$perm" && "$perm" != "600" && "$perm" != "400" ]]; then
      echo "[warn] $CREDS_FILE permission is $perm (recommend 600); run: chmod 600 \"$CREDS_FILE\"" >&2
    fi
  fi
}

# Read endpoint override from credentials file (lets users keep a per-Hub profile)
load_endpoint() {
  if [[ -n "${SKILL_HUB_URL:-}" ]]; then
    echo "$SKILL_HUB_URL"
    return 0
  fi
  if [[ -f "$CREDS_FILE" ]]; then
    local e
    e="$(jq -r '.endpoint // empty' "$CREDS_FILE" 2>/dev/null)"
    if [[ -n "$e" && "$e" != "null" ]]; then
      echo "$e"
      return 0
    fi
  fi
  # No URL configured anywhere
  echo ""
}

# Verify a Hub URL is configured; if not, emit an actionable error and exit.
# Most commands call this before any network operation.
#
# IMPORTANT: callers MUST invoke this OUTSIDE a $(...) command substitution,
# because `exit` inside cmdsub only kills the subshell, not the parent
# (the parent silently continues with an empty assignment). Pattern:
#
#     require_hub_url || exit $?       # fail-fast in current shell
#     endpoint="$(load_endpoint)"
#
# Do NOT write `endpoint="$(require_hub_url)"` — that hides the exit code.
require_hub_url() {
  local url
  url="$(load_endpoint)"
  if [[ -z "$url" ]]; then
    cat >&2 <<EOF
[error] No Skill Hub URL is configured.

This tool talks to any Hub that implements the documented API contract.
Configure your Hub URL via either:

  [option A: env var]
    export SKILL_HUB_URL="https://hub.your-company.com"

  [option B: credentials file]
    mkdir -p "$(dirname "$CREDS_FILE")"
    cp "${CREDS_EXAMPLE}" "${CREDS_FILE}"
    chmod 600 "${CREDS_FILE}"
    # then edit the .endpoint and .token fields

(For clawhub.ai specifically, use the official 'clawhub' CLI — its API surface
differs from the one this tool implements.)

See: $SKILL_DIR/SKILL.md (section: "Self-hosted Hub: API contract")
     $SKILL_DIR/references/api.md
EOF
    return 2
  fi
  return 0
}

# Read custom auth header / scheme from credentials file (env wins, file fills gaps)
load_auth_header() {
  # Distinguish "unset" from "explicitly empty" via parameter-set check
  if [[ "${SKILL_HUB_AUTH_HEADER+x}" == "x" ]]; then
    echo "$SKILL_HUB_AUTH_HEADER"
    return 0
  fi
  if [[ -f "$CREDS_FILE" ]]; then
    local h
    h="$(jq -r '.authHeader // empty' "$CREDS_FILE" 2>/dev/null)"
    if [[ -n "$h" && "$h" != "null" ]]; then
      echo "$h"
      return 0
    fi
  fi
  echo "Authorization"
}

load_auth_scheme() {
  # Distinguish "unset" from "explicitly empty" (e.g. for X-API-Key auth without prefix)
  local scheme=""
  if [[ "${SKILL_HUB_AUTH_SCHEME+x}" == "x" ]]; then
    scheme="$SKILL_HUB_AUTH_SCHEME"
  elif [[ -f "$CREDS_FILE" ]]; then
    local s
    s="$(jq -r '.authScheme // empty' "$CREDS_FILE" 2>/dev/null)"
    if [[ -n "$s" && "$s" != "null" ]]; then
      scheme="$s"
    else
      scheme="Bearer "
    fi
  else
    scheme="Bearer "
  fi

  # Auto-append trailing space if non-empty and missing one (common user mistake).
  # Header becomes "Authorization: <scheme><token>" so we always want the separator
  # when a scheme is set; explicit empty (X-API-Key style) keeps no space.
  if [[ -n "$scheme" && "${scheme: -1}" != " " ]]; then
    scheme="${scheme} "
  fi
  echo "$scheme"
}

# ---------- Token-missing friendly error ----------
die_no_token() {
  cat >&2 <<EOF
[error] No SKILL_HUB_TOKEN found, and the legacy fallback channel is unavailable.

Configure a token in one of two ways:

[Option A: environment variable] (recommended for CI/temp)
  export SKILL_HUB_TOKEN="<your-token>"

[Option B: credentials file] (recommended for daily use)
  Path : ${CREDS_FILE}
  Template: ${CREDS_EXAMPLE}
  Quick :
    mkdir -p "$(dirname "$CREDS_FILE")"
    cp "${CREDS_EXAMPLE}" "${CREDS_FILE}"
    chmod 600 "${CREDS_FILE}"
    # then edit the .endpoint and .token fields

[Where to get the token]
  Ask your Hub administrator for an API token.

[Full diagnosis]
  bash ${SKILL_DIR}/scripts/doctor.sh
EOF
  exit 2
}

# ---------- OpenAPI path -> legacy path mapping ----------
# OpenAPI: <HUB_API_PREFIX>/<op>                 (e.g. /api/v1/skill/search)
# Legacy : <HUB_LEGACY_API_PREFIX>/<op>          (e.g. /api/skill/search)
# Note: ?page= -> ?current= rewrite preserved for legacy Hubs that use ?current=
legacy_path_for() {
  local oapi_path="$1"
  local legacy_path="${oapi_path/${HUB_API_PREFIX}\//${HUB_LEGACY_API_PREFIX}\/}"
  legacy_path="${legacy_path//\?page=/\?current=}"
  legacy_path="${legacy_path//&page=/&current=}"
  echo "$legacy_path"
}

# ---------- One-shot legacy-fallback notice ----------
# Use a file marker (not env var) so the notice survives across subshells
# created by command substitution. The marker path lives in
# _LEGACY_NOTICE_MARKER, which children inherit via env.

setup_legacy_notice() {
  local marker
  marker="$(mktemp 2>/dev/null || mktemp -t skill-hub-notice)"
  rm -f "$marker"
  export _LEGACY_NOTICE_MARKER="$marker"
  trap 'rm -f "${_LEGACY_NOTICE_MARKER:-}"' EXIT
}

show_legacy_notice() {
  local marker="${_LEGACY_NOTICE_MARKER:-}"
  if [[ -z "$marker" ]]; then
    marker="$(mktemp 2>/dev/null || mktemp -t skill-hub-notice)"
    rm -f "$marker"
  fi
  if [[ -f "$marker" ]]; then
    return 0
  fi
  cat >&2 <<NOTICE_EOF
[info] No SKILL_HUB_TOKEN configured; falling back to the legacy (unauthenticated) channel.
       - Works for: searching and installing public skills
       - Does not work for: private skills (download requires a token)
       - Long-term: ask your Hub maintainer for a token, then:
           export SKILL_HUB_TOKEN="..."        # one-off
           or write it to: ${CREDS_FILE}
NOTICE_EOF
  touch "$marker"
}

# ---------- Internal: HTTP GET with response validation ----------
# Usage: _http_get <full_url> [token]
# When token is non-empty, sends "<HUB_AUTH_HEADER>: <HUB_AUTH_SCHEME><token>".
_http_get() {
  local url="$1"
  local token="${2:-}"

  local tmp_body tmp_status
  tmp_body="$(mktemp)"
  tmp_status="$(mktemp)"

  local -a curl_opts=(-fsS --max-time 30 -o "$tmp_body" -w "%{http_code}")
  if [[ -n "$token" ]]; then
    local hdr scheme
    hdr="$(load_auth_header)"
    scheme="$(load_auth_scheme)"
    curl_opts+=(-H "${hdr}: ${scheme}${token}")
  fi

  if ! curl "${curl_opts[@]}" "$url" > "$tmp_status" 2>/dev/null; then
    local code
    code="$(cat "$tmp_status" 2>/dev/null || echo "000")"
    echo "${tmp_body}|${tmp_status}|HTTP_ERR|${code}"
    return 1
  fi

  local status
  status="$(cat "$tmp_status")"
  echo "${tmp_body}|${tmp_status}|OK|${status}"
}

# ---------- Unified API call (auto-routes: token -> OpenAPI; none -> legacy) ----------
# Usage: api_get "${HUB_API_PREFIX}/search?keyword=xx"
# Output: response body (JSON) on stdout. Errors exit 3 or 4.
api_get() {
  local path="$1"
  local endpoint
  require_hub_url || exit $?
  endpoint="$(load_endpoint)"

  local token=""
  local actual_path="$path"
  if token="$(load_token 2>/dev/null)"; then
    : # have token; use OpenAPI path
  else
    actual_path="$(legacy_path_for "$path")"
    show_legacy_notice
    token=""
  fi

  local result
  if ! result="$(_http_get "${endpoint}${actual_path}" "$token")"; then
    IFS='|' read -r tmp_body tmp_status _ code <<< "$result"
    echo "[error] HTTP ${code} request failed: ${actual_path}" >&2
    if [[ -s "$tmp_body" ]]; then
      cat "$tmp_body" >&2
    fi
    rm -f "$tmp_body" "$tmp_status"
    exit 3
  fi

  IFS='|' read -r tmp_body tmp_status _ status <<< "$result"

  if [[ "$status" != "200" ]]; then
    echo "[error] HTTP ${status}: ${actual_path}" >&2
    cat "$tmp_body" >&2
    rm -f "$tmp_body" "$tmp_status"
    exit 3
  fi

  # Response envelope check (both OpenAPI and legacy use {code, message, data})
  local code success
  code="$(jq -r '.code // empty' "$tmp_body" 2>/dev/null || echo "")"
  success="$(jq -r '.success // empty' "$tmp_body" 2>/dev/null || echo "")"
  if [[ -n "$code" && "$code" != "200" ]]; then
    local msg
    msg="$(jq -r '.message // ""' "$tmp_body" 2>/dev/null || echo "")"
    echo "[error] API business error code=${code}: ${msg}" >&2
    rm -f "$tmp_body" "$tmp_status"
    exit 4
  fi
  if [[ "$success" == "false" ]]; then
    local msg
    msg="$(jq -r '.message // .errorMsg // ""' "$tmp_body" 2>/dev/null || echo "")"
    echo "[error] API success=false: ${msg}" >&2
    rm -f "$tmp_body" "$tmp_status"
    exit 4
  fi

  cat "$tmp_body"
  rm -f "$tmp_body" "$tmp_status"
}

# Download a skill ZIP via the legacy download endpoint.
# Usage: api_download <slug> [version] <out_file>
api_download() {
  local slug="$1" version="$2" out="$3"
  local endpoint
  require_hub_url || exit $?
  endpoint="$(load_endpoint)"

  local url="${endpoint}${HUB_LEGACY_API_PREFIX}/download/${slug}"
  if [[ -n "$version" ]]; then
    url="${url}?version=${version}&track=true"
  else
    url="${url}?track=true"
  fi

  # Drop -f so we can capture body on 4xx too; classify by HTTP code
  # Download: bigger budget for zip transfers. Override with SKILL_HUB_DOWNLOAD_TIMEOUT.
  local dl_timeout="${SKILL_HUB_DOWNLOAD_TIMEOUT:-120}"
  local -a curl_opts=(-sSL --max-time "$dl_timeout" -o "$out" -w "%{http_code}")
  local token=""
  if token="$(load_token 2>/dev/null)"; then
    local hdr scheme
    hdr="$(load_auth_header)"
    scheme="$(load_auth_scheme)"
    curl_opts+=(-H "${hdr}: ${scheme}${token}")
  else
    show_legacy_notice
  fi

  local http_code
  if ! http_code="$(curl "${curl_opts[@]}" "$url" 2>/dev/null)"; then
    echo "[error] Download failed: ${slug} (network error, check connectivity)" >&2
    rm -f "$out"
    exit 3
  fi

  case "$http_code" in
    200) : ;;
    404)
      echo "[error] Skill '${slug}' not found (HTTP 404)" >&2
      echo "       Run: bash $SKILL_DIR/scripts/query.sh slug ${slug} to verify the slug${version:+ / version '$version'}" >&2
      rm -f "$out"
      exit 3
      ;;
    403)
      echo "[error] Skill '${slug}' access denied (HTTP 403, private skill)" >&2
      if [[ -z "$token" ]]; then
        echo "       This skill is private. Set SKILL_HUB_TOKEN or run: bash $SKILL_DIR/scripts/doctor.sh" >&2
      else
        echo "       Your token has no permission for this private skill. Ask the skill owner for access." >&2
      fi
      rm -f "$out"
      exit 3
      ;;
    401)
      echo "[error] Authentication failed (HTTP 401): token invalid or expired. Refresh the token or remove it to fall back to legacy." >&2
      rm -f "$out"
      exit 3
      ;;
    *)
      echo "[error] Download failed: ${slug} (HTTP ${http_code})" >&2
      [[ -s "$out" ]] && { echo "       Response head:" >&2; head -c 300 "$out" >&2; echo >&2; }
      rm -f "$out"
      exit 3
      ;;
  esac

  # JSON error body detection: some Hubs return 200 + JSON error masquerading as a ZIP
  if [[ "$(head -c 1 "$out" 2>/dev/null)" == "{" ]]; then
    local err_code err_msg
    err_code="$(jq -r '.code // empty' "$out" 2>/dev/null || echo "")"
    err_msg="$(jq -r '.message // .errorMsg // empty' "$out" 2>/dev/null || echo "")"
    if [[ "$err_code" == "403" ]]; then
      echo "[error] Skill '${slug}' is private (response code=403): ${err_msg}" >&2
      echo "       Ask the skill owner for access, or configure SKILL_HUB_TOKEN with appropriate scope." >&2
    elif [[ -n "$err_code" ]]; then
      echo "[error] API returned code=${err_code}: ${err_msg} (slug=${slug})" >&2
    else
      echo "[error] Response is not a ZIP (looks like an error JSON):" >&2
      head -c 500 "$out" >&2; echo >&2
    fi
    rm -f "$out"
    exit 5
  fi

  # Verify ZIP magic
  local ftype
  ftype="$(file -b "$out" 2>/dev/null || echo "")"
  if [[ "$ftype" != Zip* ]]; then
    echo "[error] Response is not a ZIP (file type: ${ftype}). Body head:" >&2
    head -c 500 "$out" >&2
    echo >&2
    rm -f "$out"
    exit 5
  fi
}
