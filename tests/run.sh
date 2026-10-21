#!/usr/bin/env bash
# V2raySetup test suite — safe to run anywhere (uses --dry-run, no changes).
#   bash tests/run.sh            all tests
#   bash tests/run.sh --pty      also drive the interactive UI through a PTY
cd "$(dirname "$0")/.." || exit 1
ROOT=$PWD
PASS=0 FAIL=0
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export V2S_LOG=$TMP/test.log V2S_STATE_DIR=$TMP/state V2S_OFFLINE=1 V2S_NO_COLOR=1 PUBLIC_IP=203.0.113.7

ok() { PASS=$((PASS + 1)); printf '  \033[32m✔\033[0m %s\n' "$1"; }
ko() { FAIL=$((FAIL + 1)); printf '  \033[31m✖\033[0m %s\n' "$1"; [[ -n ${2:-} ]] && printf '%s\n' "$2" | tail -n 15 | sed 's/^/      /'; }
t() { local name=$1; shift; local out; if out=$("$@" 2>&1); then ok "$name"; else ko "$name" "$out"; fi; }

echo "● Syntax"
for f in v2raysetup.sh install.sh lib/*.sh; do t "bash -n $f" bash -n "$f"; done
if command -v shellcheck >/dev/null; then
  t "shellcheck" shellcheck -x -s bash -e SC2034,SC1091,SC2155,SC2207,SC1090,SC2001 v2raysetup.sh install.sh lib/*.sh
else echo "  (shellcheck not installed — skipped)"; fi

echo "● Validators"
# shellcheck source=/dev/null
source lib/ui.sh; source lib/core.sh; source lib/system.sh
for v in example.com sub.panel.example.co.uk a-b.ir; do t "valid_domain $v" valid_domain "$v"; done
for v in "http://x.com" "x" "-bad.com" "a..b.com" "x.com/path"; do t "invalid domain '$v'" bash -c "source lib/core.sh; ! valid_domain '$v'"; done
t "valid_port 443" valid_port 443
t "invalid port 70000" bash -c 'source lib/core.sh; ! valid_port 70000'
t "ports list '443, 8443 2053'" valid_ports_list "443, 8443 2053"
t "ports list rejects 'abc'" bash -c 'source lib/core.sh; ! valid_ports_list "443 abc"'
t "ip list v4+v6+cidr" valid_ip_list "1.2.3.4, 5.6.0.0/16 2a01:4f8::/32"
t "ip list rejects 300.1.1.1" bash -c 'source lib/core.sh; ! valid_ip_list "300.1.1.1"'
t "version_ge 5.15 4.9" version_ge 5.15 4.9
t "version_ge 4.4 4.9 is false" bash -c 'source lib/system.sh; ! version_ge 4.4 4.9'

echo "● UI helpers"
t "ui_len counts UTF-8 chars" test "$(ui_len '✻ ab → ✔')" = 8
t "ui_len strips ANSI" test "$(ui_len $'\033[1mabc\033[0m')" = 3
UI_COLS=60; out=$(ui_box "Title ✔" "line → one" "x")
w=$(while IFS= read -r l; do ui_len "$l"; done <<<"$out" | sort -u | tr '\n' ' ')
t "ui_box lines all same width ($w)" test "$w" = "60 "

echo "● Iran helpers"
source lib/iran.sh
printf '2.144.0.0/14\n5.160.0.0/16\n' >"$TMP/ir.txt"
t "ip_in_list 2.147.1.1 → in Iran list" ip_in_list 2.147.1.1 "$TMP/ir.txt"
t "ip_in_list 8.8.8.8 → not in list" bash -c "source lib/iran.sh; ! ip_in_list 8.8.8.8 '$TMP/ir.txt'"
printf '# c\n2.144.0.0/14\n10.202.10.10/31\n192.168.1.0/24\nbad\n2a01:5ec0::/29\nfe80::/10\n1.2.3.4 # x\n' >"$TMP/mixed.txt"
( source <(sed -n '/^is_v4()/,/^download()/p' lib/iran-guard.sh | sed '$d')
  : >"$TMP/o4"; : >"$TMP/o6"; split_list "$TMP/mixed.txt" "$TMP/o4" "$TMP/o6" )
t "split_list keeps public v4 (2 entries)" test "$(wc -l <"$TMP/o4")" -eq 2
t "split_list drops private 10.x / 192.168.x" bash -c "! grep -qE '^(10\\.|192\\.168)' '$TMP/o4'"
t "split_list keeps public v6, drops fe80" test "$(cat "$TMP/o6")" = "2a01:5ec0::/29"

echo "● Panel catalog"
detect_system
source lib/panels.sh
for id in "${PANEL_IDS[@]}"; do
  [[ -n ${P_NAME[$id]} && -n ${P_REPO[$id]} && ${P_RAM[$id]} -gt 0 ]] && ok "metadata $id" || ko "metadata $id"
done
t "panels command" ./v2raysetup.sh panels --no-color

echo "● Dry-run wizard (every panel)"
for id in "${PANEL_IDS[@]}"; do
  out=$(V2S_ANSWER_PANEL=$id V2S_ANSWER_FORCE=y V2S_ANSWER_DB=0 V2S_ANSWER_CHANNEL=0 V2S_ANSWER_VERSION='' \
    V2S_ANSWER_DOMAIN=vpn.example.com V2S_ANSWER_SSL_METHOD=0 V2S_ANSWER_EMAIL='' V2S_ANSWER_IRAN=1,2,3,4 \
    V2S_ANSWER_IRAN_ALLOW='' V2S_ANSWER_EXTRAS=1,2,3,4,5 V2S_ANSWER_PORTS='8443' V2S_ANSWER_GO=y \
    timeout 60 ./v2raysetup.sh install --dry-run --non-interactive --no-color </dev/null 2>&1)
  rc=$?
  if (( rc == 0 )) && grep -q "is installed" <<<"$out" && grep -q "Plan" <<<"$out"; then ok "install --dry-run $id"
  else ko "install --dry-run $id (rc=$rc)" "$out"; fi
done

echo "● Dry-run variants"
out=$(V2S_ANSWER_PANEL=3x-ui V2S_ANSWER_VERSION='' V2S_ANSWER_DOMAIN='' V2S_ANSWER_SSL_IP=1 V2S_ANSWER_IRAN=none \
  V2S_ANSWER_EXTRAS=none V2S_ANSWER_GO=y ./v2raysetup.sh install -n --non-interactive --no-color </dev/null 2>&1)
grep -q "Self-signed" <<<"$out" && ok "no domain → self-signed for IP" || ko "no domain → self-signed" "$out"
out=$(V2S_ANSWER_PANEL=pasarguard V2S_ANSWER_DB=timescaledb V2S_ANSWER_DOMAIN=p.example.com V2S_ANSWER_SSL_METHOD=1 \
  V2S_ANSWER_EMAIL='' V2S_ANSWER_CF_TOKEN=tok V2S_ANSWER_IRAN=none V2S_ANSWER_EXTRAS=none V2S_ANSWER_GO=y \
  ./v2raysetup.sh install -n --non-interactive --no-color </dev/null 2>&1)
grep -q -- "--database timescaledb" <<<"$out" && ok "PasarGuard passes --database timescaledb" || ko "PasarGuard db arg" "$out"
grep -q "dns_cf" <<<"$out" && ok "Cloudflare DNS method uses dns_cf" || ko "Cloudflare DNS" "$out"
out=$(V2S_ANSWER_PANEL=s-ui V2S_ANSWER_GO=n V2S_ANSWER_VERSION='' V2S_ANSWER_DOMAIN='' V2S_ANSWER_SSL_IP=0 V2S_ANSWER_IRAN=none \
  V2S_ANSWER_EXTRAS=none ./v2raysetup.sh install -n --non-interactive --no-color </dev/null 2>&1)
grep -q "Nothing was changed" <<<"$out" && ok "answering 'no' at review changes nothing" || ko "review cancel" "$out"
t "--help" ./v2raysetup.sh --help
t "unknown flag exits 2" bash -c '! ./v2raysetup.sh --bogus >/dev/null 2>&1'

if [[ ${1:-} == --pty ]]; then
  echo "● Interactive (PTY)"
  STEPS='[["What would you like to do?","1\r"],["Which panel do you want to install?","\u001b[B\u001b[B"],["sing-box panel","\r"],["Version to install","\r"],["Domain for the panel","\r"],["What about HTTPS","\r"],["Iran IP bypass","\u001b[B "],["Iran IP bypass","\r"],["must still reach","\r"],["Server preparation","n\r"],["Start the installation?","n"]]' \
    timeout 120 python3 tests/pty_drive.py ./v2raysetup.sh --dry-run >"$TMP/pty.log" 2>&1
  grep -q "S-UI (sing-box" "$TMP/pty.log" && grep -q "Nothing was changed" "$TMP/pty.log" && ok "arrow-key wizard via PTY" || ko "PTY wizard" "$(sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' "$TMP/pty.log")"
fi

echo
echo "Result: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
