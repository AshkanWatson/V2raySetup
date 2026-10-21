#!/usr/bin/env bash
# v2s-iran-guard — block this server from opening connections to Iranian IPs.
#
# Why: Iranian websites/apps (banks, Digikala, Snapp, Divar, ...) see the
# foreign server IP when users browse them through the proxy. That gets the
# server IP flagged/reported and often blocks those sites anyway. Blocking
# NEW outbound connections to Iran keeps the server "invisible" to them,
# while users connecting FROM Iran keep working (their traffic is inbound and
# replies are ESTABLISHED, not NEW).
#
# Usage: v2s-iran-guard {update|apply|refresh|remove|status|check IP}
set -uo pipefail

CONF_DIR=${V2S_STATE_DIR:-/etc/v2raysetup}
LIST_DIR=$CONF_DIR/iran
ALLOW_FILE=$CONF_DIR/iran-allow.txt
EXTRA_FILE=$CONF_DIR/iran-extra.txt
DOMAINS_FILE=$CONF_DIR/iran-domains.txt
CHAIN=V2S_IRAN
SET4=v2s_ir4 SET6=v2s_ir6 ALLOW4=v2s_allow4 ALLOW6=v2s_allow6

SOURCES4=(
  https://raw.githubusercontent.com/Chocolate4U/Iran-v2ray-rules/release/text/ir.txt
  https://cdn.jsdelivr.net/gh/Chocolate4U/Iran-v2ray-rules@release/text/ir.txt
  https://raw.githubusercontent.com/ipverse/rir-ip/master/country/ir/ipv4-aggregated.txt
)
SOURCES6=(
  https://raw.githubusercontent.com/ipverse/rir-ip/master/country/ir/ipv6-aggregated.txt
)

log() { printf '[iran-guard] %s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

is_v4() { [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/([0-9]|[12][0-9]|3[0-2]))?$ ]]; }
is_v6() { [[ "$1" =~ ^[0-9A-Fa-f]*:[0-9A-Fa-f:]*(/([0-9]|[1-9][0-9]|1[01][0-9]|12[0-8]))?$ ]]; }
# Private/reserved ranges are never blocked (some lists include Iran-internal
# 10.x/172.x/192.168.x addresses; blocking them could break the host network).
is_private() {
  [[ "$1" =~ ^(0\.|10\.|127\.|169\.254\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.|22[4-9]\.|2[3-5][0-9]\.) ]] ||
    [[ "${1,,}" =~ ^(::|::1|f[cd][0-9a-f]{2}:|fe[89ab][0-9a-f]:|ff[0-9a-f]{2}:) ]]
}

# split_list IN OUT4 OUT6 — keeps only valid entries, strips comments
split_list() {
  local in=$1 o4=$2 o6=$3 line
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}; line=${line//[[:space:]]/}
    [[ -z $line ]] && continue
    is_private "$line" && continue
    if is_v4 "$line"; then echo "$line" >>"$o4"
    elif is_v6 "$line"; then echo "$line" >>"$o6"; fi
  done <"$in"
}

download() {
  local url=$1 out=$2
  curl -fsSL --connect-timeout 15 --max-time 120 "$url" -o "$out" 2>/dev/null ||
    wget -q -T 30 -O "$out" "$url" 2>/dev/null
}

cmd_update() {
  mkdir -p "$LIST_DIR"
  local tmp; tmp=$(mktemp -d); trap 'rm -rf "$tmp"' RETURN
  local u ok=0
  : >"$tmp/v4"; : >"$tmp/v6"
  for u in "${SOURCES4[@]}"; do
    if download "$u" "$tmp/src" && [[ -s $tmp/src ]]; then
      split_list "$tmp/src" "$tmp/v4" "$tmp/v6"
      if (( $(wc -l <"$tmp/v4") >= 100 )); then log "IPv4 list from $u"; ok=1; break; fi
      : >"$tmp/v4"; : >"$tmp/v6"
    fi
  done
  (( ok )) || { [[ -s $LIST_DIR/ir4.txt ]] && { log "download failed, keeping previous list"; return 0; }; die "could not download any Iran IP list"; }
  if (( $(wc -l <"$tmp/v6") < 10 )); then
    for u in "${SOURCES6[@]}"; do
      download "$u" "$tmp/src6" && split_list "$tmp/src6" "$tmp/x4" "$tmp/v6" && break
    done
  fi
  # extra CIDRs and resolved domains
  [[ -f $EXTRA_FILE ]] && split_list "$EXTRA_FILE" "$tmp/v4" "$tmp/v6"
  if [[ -f $DOMAINS_FILE ]]; then
    local d ip
    while IFS= read -r d || [[ -n $d ]]; do
      d=${d%%#*}; d=${d//[[:space:]]/}; [[ -z $d ]] && continue
      while read -r ip _; do
        if is_v4 "$ip"; then echo "$ip" >>"$tmp/v4"; elif is_v6 "$ip"; then echo "$ip" >>"$tmp/v6"; fi
      done < <(getent ahosts "$d" 2>/dev/null | awk '{print $1}' | sort -u)
    done <"$DOMAINS_FILE"
  fi
  sort -u "$tmp/v4" >"$LIST_DIR/ir4.txt"
  sort -u "$tmp/v6" >"$LIST_DIR/ir6.txt"
  date -u '+%F %T UTC' >"$LIST_DIR/updated"
  log "saved $(wc -l <"$LIST_DIR/ir4.txt") IPv4 and $(wc -l <"$LIST_DIR/ir6.txt") IPv6 ranges"
}

# load_set NAME FAMILY FILE — atomic swap so the set is never empty
load_set() {
  local name=$1 fam=$2 file=$3 tmpset=${1}_tmp
  {
    echo "create $name hash:net family $fam hashsize 4096 maxelem 262144 -exist"
    echo "create $tmpset hash:net family $fam hashsize 4096 maxelem 262144 -exist"
    echo "flush $tmpset"
    [[ -f $file ]] && grep -vE '^\s*(#|$)' "$file" | sed "s/^/add $tmpset /;s/\$/ -exist/"
    echo "swap $tmpset $name"
    echo "destroy $tmpset"
  } | ipset restore
}

# rules IPT SET ALLOW
install_rules() {
  local ipt=$1 set=$2 allow=$3 parent
  $ipt -w -N $CHAIN 2>/dev/null || true
  $ipt -w -F $CHAIN
  $ipt -w -A $CHAIN -m set --match-set "$allow" dst -j RETURN
  $ipt -w -A $CHAIN -p tcp -m set --match-set "$set" dst -m conntrack --ctstate NEW -j REJECT --reject-with tcp-reset
  $ipt -w -A $CHAIN -m set --match-set "$set" dst -m conntrack --ctstate NEW -j REJECT
  for parent in OUTPUT FORWARD; do
    $ipt -w -C $parent -j $CHAIN 2>/dev/null || $ipt -w -I $parent 1 -j $CHAIN
  done
}

cmd_apply() {
  command -v ipset >/dev/null || die "ipset is not installed"
  command -v iptables >/dev/null || die "iptables is not installed"
  [[ -s $LIST_DIR/ir4.txt ]] || cmd_update
  : >"$CONF_DIR/.allow4"; : >"$CONF_DIR/.allow6"
  [[ -f $ALLOW_FILE ]] && split_list "$ALLOW_FILE" "$CONF_DIR/.allow4" "$CONF_DIR/.allow6"
  load_set "$SET4" inet "$LIST_DIR/ir4.txt" || die "failed to load IPv4 set"
  load_set "$ALLOW4" inet "$CONF_DIR/.allow4"
  install_rules iptables "$SET4" "$ALLOW4" || die "failed to install IPv4 rules"
  if command -v ip6tables >/dev/null && [[ -s $LIST_DIR/ir6.txt ]] && ip6tables -w -L >/dev/null 2>&1; then
    if ! { load_set "$SET6" inet6 "$LIST_DIR/ir6.txt" && load_set "$ALLOW6" inet6 "$CONF_DIR/.allow6" &&
      install_rules ip6tables "$SET6" "$ALLOW6"; }; then log "IPv6 rules skipped"; fi
  fi
  rm -f "$CONF_DIR/.allow4" "$CONF_DIR/.allow6"
  log "active: $(ipset list $SET4 2>/dev/null | grep -c '/' ) IPv4 ranges blocked (outbound NEW connections only)"
}

cmd_remove() {
  local ipt parent
  for ipt in iptables ip6tables; do
    command -v $ipt >/dev/null || continue
    for parent in OUTPUT FORWARD; do
      while $ipt -w -D $parent -j $CHAIN 2>/dev/null; do :; done
    done
    $ipt -w -F $CHAIN 2>/dev/null; $ipt -w -X $CHAIN 2>/dev/null
  done
  local s; for s in $SET4 $SET6 $ALLOW4 $ALLOW6; do ipset destroy "$s" 2>/dev/null; done
  log "removed all Iran block rules"
}

cmd_status() {
  if iptables -w -C OUTPUT -j $CHAIN 2>/dev/null; then
    echo "state:    ACTIVE"
  else
    echo "state:    inactive"
  fi
  echo "ipv4:     $(ipset list $SET4 2>/dev/null | grep -c '/') ranges"
  echo "ipv6:     $(ipset list $SET6 2>/dev/null | grep -c '/') ranges"
  echo "allowed:  $(ipset list $ALLOW4 2>/dev/null | grep -cE '^[0-9]') entries"
  echo "updated:  $(cat "$LIST_DIR/updated" 2>/dev/null || echo never)"
}

cmd_check() { # is an IP inside the Iran list?
  local ip=$1
  if ipset test $SET4 "$ip" 2>/dev/null; then echo "$ip is in the Iran list"; return 0; fi
  echo "$ip is NOT in the Iran list"; return 1
}

case "${1:-}" in
  update) cmd_update ;;
  apply) cmd_apply ;;
  refresh) cmd_update && cmd_apply ;;
  remove) cmd_remove ;;
  status) cmd_status ;;
  check) cmd_check "${2:?IP required}" ;;
  *) echo "usage: $0 {update|apply|refresh|remove|status|check IP}"; exit 2 ;;
esac
