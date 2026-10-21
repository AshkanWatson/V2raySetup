#!/usr/bin/env bash
# core.sh — shared helpers: command runner, dry-run, downloads, state.

V2S_STATE_DIR=${V2S_STATE_DIR:-/etc/v2raysetup}
V2S_LOG=${V2S_LOG:-/var/log/v2raysetup.log}
DRY_RUN=${DRY_RUN:-0}
ASSUME_YES=${ASSUME_YES:-0}

has() { command -v "$1" >/dev/null 2>&1; }

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$V2S_LOG" 2>/dev/null || true; }

# run cmd args... — executes (or prints in dry-run). Output goes to the log.
run() {
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '  %s$ %s%s\n' "${C_MUTED}" "$*" "${C_RESET}"
    return 0
  fi
  log "\$ $*"
  "$@" >>"$V2S_LOG" 2>&1
}

# run_tty cmd args... — runs attached to the terminal (for interactive
# upstream installers). Never hidden behind a spinner.
run_tty() {
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '  %s$ %s%s\n' "${C_MUTED}" "$*" "${C_RESET}"
    return 0
  fi
  log "\$ (tty) $*"
  if [[ "${UI_IN:-/dev/stdin}" == /dev/tty ]]; then
    "$@" </dev/tty
  else
    "$@"
  fi
}

# write_file PATH MODE <<<content  — honours dry-run
write_file() {
  local path="$1" mode="${2:-644}" content
  content=$(cat)
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '  %s$ write %s (%d bytes)%s\n' "${C_MUTED}" "$path" "${#content}" "${C_RESET}"
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" >"$path" && chmod "$mode" "$path"
}

# fetch URL OUT — download with retries (curl or wget)
fetch() {
  local url="$1" out="$2" i
  for i in 1 2 3; do
    if has curl; then
      curl -fsSL --connect-timeout 15 --max-time 300 "$url" -o "$out" && return 0
    elif has wget; then
      wget -q -T 30 -O "$out" "$url" && return 0
    else
      return 127
    fi
    sleep $((i * 2))
  done
  return 1
}

# fetch_script URL — downloads an upstream installer into a temp file and
# prints its path. Downloads happen even in dry-run (read-only) unless offline.
fetch_script() {
  local url="$1" tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/v2s-XXXXXX.sh")
  if [[ "$DRY_RUN" == 1 && "${V2S_OFFLINE:-0}" == 1 ]]; then echo "$tmp"; return 0; fi
  if fetch "$url" "$tmp" && [[ -s "$tmp" ]]; then
    chmod +x "$tmp"; echo "$tmp"; return 0
  fi
  rm -f "$tmp"; return 1
}

rand_hex() { local n="${1:-32}"; if has openssl; then openssl rand -hex "$n"; else head -c "$n" /dev/urandom | od -An -tx1 | tr -d ' \n'; fi; }
rand_pass() { tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c "${1:-16}"; }

state_set() { # state_set KEY VALUE
  [[ "$DRY_RUN" == 1 ]] && return 0
  mkdir -p "$V2S_STATE_DIR"
  local f="$V2S_STATE_DIR/state.env"
  touch "$f"; chmod 600 "$f"
  grep -v "^$1=" "$f" >"$f.tmp" 2>/dev/null || true
  printf '%s=%q\n' "$1" "$2" >>"$f.tmp"
  mv "$f.tmp" "$f"
}
state_get() { # state_get KEY
  local f="$V2S_STATE_DIR/state.env"
  [[ -f "$f" ]] || return 1
  (set +u; source "$f" 2>/dev/null; printf '%s' "${!1:-}")
}

# ---------------------------------------------------------- validators ---
valid_domain() {
  UI_VALIDATION_MSG="Enter a domain like panel.example.com (no http://, no path)"
  [[ "$1" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}
valid_domain_or_empty() { [[ -z "$1" ]] || valid_domain "$1"; }
valid_email() {
  UI_VALIDATION_MSG="Enter a valid e-mail address"
  [[ "$1" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]
}
valid_email_or_empty() { [[ -z "$1" ]] || valid_email "$1"; }
valid_port() {
  UI_VALIDATION_MSG="Port must be a number between 1 and 65535"
  [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 ))
}
valid_ports_list() { # "443, 8443 2053" or empty
  UI_VALIDATION_MSG="Enter ports separated by space or comma, e.g. 443 8443 2053"
  local p; for p in ${1//,/ }; do valid_port "$p" || { UI_VALIDATION_MSG="'$p' is not a valid port"; return 1; }; done
  return 0
}
valid_ipv4() {
  local ip="$1" o
  [[ "$ip" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
  for o in "${BASH_REMATCH[@]:1}"; do (( o <= 255 )) || return 1; done
}
valid_cidr4() {
  local ip=${1%/*} m=${1#*/}
  [[ "$1" == */* ]] || m=32
  valid_ipv4 "$ip" && [[ "$m" =~ ^[0-9]+$ ]] && (( m >= 0 && m <= 32 ))
}
valid_cidr6() { [[ "$1" =~ ^[0-9A-Fa-f:]+:[0-9A-Fa-f:.]*(/[0-9]{1,3})?$ ]]; }
valid_ip_list() { # space/comma separated IPv4/IPv6/CIDR, may be empty
  UI_VALIDATION_MSG="Enter IPs or CIDRs separated by space or comma"
  local x; for x in ${1//,/ }; do valid_cidr4 "$x" || valid_cidr6 "$x" || { UI_VALIDATION_MSG="'$x' is not a valid IP/CIDR"; return 1; }; done
  return 0
}
valid_nonempty() { UI_VALIDATION_MSG="This value cannot be empty"; [[ -n "$1" ]]; }
