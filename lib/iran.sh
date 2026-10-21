#!/usr/bin/env bash
# iran.sh — "bypass Iran" options: block server→Iran traffic, Xray routing
# rules and a client "Iran direct" guide.

IRAN_GUARD_BIN=/usr/local/sbin/v2s-iran-guard

# Default Iranian services whose IPs are always added (resolved on update).
IRAN_DEFAULT_DOMAINS="digikala.com snapp.ir snappfood.ir tapsi.ir app.tapsi.ir divar.ir aparat.com
shaparak.ir bmi.ir mellat.ir bankmellat.ir sb24.ir torob.com filimo.com namava.ir telewebion.com
shad.ir rubika.ir eitaa.com bale.ai soroush-app.ir irancell.ir mci.ir my.mci.ir sep.ir zarinpal.com
snapp.taxi cafebazaar.ir myket.ir"

# Legacy IPs from the old installapt.sh/installyum.sh scripts
IRAN_LEGACY_IPS="185.188.106.10 86.104.35.19 185.143.234.225 185.143.233.81"

ip2int() { local IFS=.; read -r a b c d <<<"$1"; echo $(((a << 24) + (b << 16) + (c << 8) + d)); }
# ip_in_list IP FILE — pure bash IPv4 CIDR match
ip_in_list() {
  local ip; ip=$(ip2int "$1") || return 1
  local cidr net mask
  while IFS= read -r cidr; do
    [[ $cidr == *.*/* ]] || continue
    net=$(ip2int "${cidr%/*}"); mask=${cidr#*/}
    (( mask == 0 )) && return 0
    (( (ip >> (32 - mask)) == (net >> (32 - mask)) )) && return 0
  done <"$2"
  return 1
}

iran_questions() {
  IRAN_BLOCK=0 IRAN_AUTOUPDATE=0 IRAN_XRAY=0 IRAN_CLIENT=0 IRAN_ALLOW=''
  ui_blank
  ui_dim "  Iranian sites & apps (banks, Digikala, Snapp, Divar, ...) can flag a foreign server"
  ui_dim "  that connects to them. Blocking server→Iran keeps your IP clean. Users in Iran can"
  ui_dim "  still connect to the server — only outgoing connections to Iran are blocked."
  ui_multiselect iran "Iran IP bypass / protection options" \
    "Block server → Iran IPs|firewall (ipset), all Iranian IP ranges + services|on" \
    "Auto-update the Iran IP list daily|systemd timer / cron|on" \
    "Xray routing rules|block geoip:ir + .ir domains inside the panel config|off" \
    "Client 'Iran direct' guide|how users route Iranian sites without the proxy|on"
  IRAN_BLOCK=${UI_SELECTED[0]} IRAN_AUTOUPDATE=${UI_SELECTED[1]} IRAN_XRAY=${UI_SELECTED[2]} IRAN_CLIENT=${UI_SELECTED[3]}
  (( IRAN_BLOCK == 0 )) && IRAN_AUTOUPDATE=0
  if (( IRAN_BLOCK )); then
    ui_input iran_allow "Iranian IPs this server must still reach (tunnel/relay server), optional" "" valid_ip_list \
      "e.g. an Iran bridge server used by a reverse tunnel — leave empty if none"
    IRAN_ALLOW=${UI_VALUE//,/ }
  fi
}

iran_install_guard() {
  local src="$V2S_DIR/lib/iran-guard.sh"
  local -a need=()
  has ipset || need+=(ipset)
  has iptables || need+=(iptables)
  if (( ${#need[@]} )); then ui_spin "Installing ${need[*]}" pkg_install "${need[@]}" || return 1; fi
  run install -m 755 "$src" "$IRAN_GUARD_BIN"
  run mkdir -p "$V2S_STATE_DIR"
  if [[ $DRY_RUN != 1 ]]; then
    [[ -f $V2S_STATE_DIR/iran-domains.txt ]] || {
      echo "# Iranian services — resolved and blocked on every update. One domain per line."
      tr ' ' '\n' <<<"$IRAN_DEFAULT_DOMAINS" | grep -v '^$'
    } >"$V2S_STATE_DIR/iran-domains.txt"
    [[ -f $V2S_STATE_DIR/iran-extra.txt ]] || {
      echo "# Extra IPs/CIDRs to block (one per line)."
      tr ' ' '\n' <<<"$IRAN_LEGACY_IPS"
    } >"$V2S_STATE_DIR/iran-extra.txt"
    {
      echo "# Iranian IPs this server may still connect to (tunnel/relay servers)."
      local x; for x in $IRAN_ALLOW; do echo "$x"; done
    } >"$V2S_STATE_DIR/iran-allow.txt"
  fi
  ui_ok "Installed $IRAN_GUARD_BIN"
  ui_sub "Edit lists in $V2S_STATE_DIR/iran-{domains,extra,allow}.txt"
}

iran_apply() {
  iran_install_guard || return 1
  ui_spin "Downloading Iran IP ranges" "$IRAN_GUARD_BIN" update || return 1
  # Safety: never block if this server itself is in Iran
  local me; me=$(public_ip)
  if [[ $DRY_RUN != 1 ]] && valid_ipv4 "$me" && ip_in_list "$me" "$V2S_STATE_DIR/iran/ir4.txt"; then
    ui_warn "This server ($me) is inside Iran — blocking Iran would break it. Skipped."
    return 0
  fi
  ui_spin "Blocking outbound connections to Iran" "$IRAN_GUARD_BIN" apply || return 1
  iran_persist
  state_set IRAN_BLOCK 1
}

iran_persist() {
  if [[ $HAS_SYSTEMD == 1 ]]; then
    write_file /etc/systemd/system/v2s-iran-guard.service 644 <<EOF
[Unit]
Description=V2raySetup: block outbound connections to Iranian IPs
After=network-online.target ufw.service firewalld.service docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$IRAN_GUARD_BIN apply
ExecStop=$IRAN_GUARD_BIN remove

[Install]
WantedBy=multi-user.target
EOF
    write_file /etc/systemd/system/v2s-iran-update.service 644 <<EOF
[Unit]
Description=V2raySetup: refresh Iranian IP list
After=network-online.target

[Service]
Type=oneshot
ExecStart=$IRAN_GUARD_BIN refresh
EOF
    write_file /etc/systemd/system/v2s-iran-update.timer 644 <<'EOF'
[Unit]
Description=V2raySetup: refresh Iranian IP list daily

[Timer]
OnCalendar=*-*-* 04:20:00
RandomizedDelaySec=30m
Persistent=true

[Install]
WantedBy=timers.target
EOF
    run systemctl daemon-reload
    run systemctl enable v2s-iran-guard.service
    if (( IRAN_AUTOUPDATE )); then run systemctl enable --now v2s-iran-update.timer; fi
    ui_ok "Rules restored on boot$( (( IRAN_AUTOUPDATE )) && echo ' and list refreshed daily')"
  else
    local cron="@reboot $IRAN_GUARD_BIN apply"
    (( IRAN_AUTOUPDATE )) && cron+=$'\n'"20 4 * * * $IRAN_GUARD_BIN refresh"
    if ! has crontab && [[ $DRY_RUN != 1 ]]; then
      ui_spin "Installing cron" pkg_install cron || true
    fi
    if run bash -c "(crontab -l 2>/dev/null | grep -v v2s-iran-guard; echo '$cron') | crontab -"; then
      ui_ok "Cron entries added for boot$( (( IRAN_AUTOUPDATE )) && echo ' and daily refresh')"
    else
      ui_warn "No systemd or cron: the block is active now but will NOT survive a reboot."
      ui_sub "After reboot run: $IRAN_GUARD_BIN apply"
    fi
  fi
}

iran_remove() {
  [[ -x $IRAN_GUARD_BIN ]] && run "$IRAN_GUARD_BIN" remove
  if [[ $HAS_SYSTEMD == 1 ]]; then
    run systemctl disable --now v2s-iran-update.timer
    run systemctl disable v2s-iran-guard.service
    run rm -f /etc/systemd/system/v2s-iran-{guard.service,update.service,update.timer}
    run systemctl daemon-reload
  fi
  has crontab && run bash -c "crontab -l 2>/dev/null | grep -v v2s-iran-guard | crontab -"
  state_set IRAN_BLOCK 0
  ui_ok "Iran block removed"
}

iran_write_xray_rules() {
  local out=$V2S_STATE_DIR/xray-iran-routing.json
  write_file "$out" 644 <<'EOF'
{
  "_comment": "V2raySetup: add these to the \"routing.rules\" array of your Xray config (top of the list). In 3x-ui: Xray Configs → Routing Rules, or paste into the Advanced JSON. Requires an outbound with tag \"blocked\" (protocol blackhole) — panels create it by default.",
  "rules": [
    { "type": "field", "outboundTag": "blocked", "ip": ["geoip:ir"] },
    { "type": "field", "outboundTag": "blocked", "domain": ["geosite:category-ir", "regexp:.*\\.ir$"] }
  ],
  "outbound_if_missing": { "tag": "blocked", "protocol": "blackhole", "settings": {} }
}
EOF
  ui_ok "Xray routing rules written to $out"
  ui_sub "3x-ui/x-ui: Xray Configs → Routing → add rule: Outbound 'blocked', IP 'geoip:ir', Domain 'geosite:category-ir'"
  ui_sub "Marzban/PasarGuard: Core Settings → paste the rules into routing.rules"
}

iran_write_client_guide() {
  local out=$V2S_STATE_DIR/client-iran-direct.md
  write_file "$out" 644 <<'EOF'
# Iran direct — client side routing

Iranian sites should be opened WITHOUT the proxy (faster, and banks/shops work).

## v2rayNG (Android)
Settings → Routing settings → "Domain strategy: IPIfNonMatch" →
Pre-defined rule set: choose "Iran" (or add to Direct URL/IP:
`geosite:category-ir`, `geoip:ir`, `regexp:.*\.ir$`). Also enable "Bypass LAN".
For better lists, download Chocolate4U geo files in Settings → Geo files:
- https://github.com/Chocolate4U/Iran-v2ray-rules/releases/latest/download/geoip.dat
- https://github.com/Chocolate4U/Iran-v2ray-rules/releases/latest/download/geosite.dat

## Hiddify App / NekoBox / Karing
Settings → Region: **Iran (ir)** → "Bypass LAN" + "Direct Iran sites" on.

## v2rayN (Windows)
Routing settings → select the "Bypass Iran" / custom rule set with
Direct: `geosite:category-ir, geoip:ir, geoip:private`.

## Streisand / V2Box / FoXray (iOS)
Routing → add rule: GEOIP `ir` → Direct, DOMAIN-SUFFIX `ir` → Direct.

## Raw Xray client JSON
```json
{ "routing": { "domainStrategy": "IPIfNonMatch", "rules": [
  { "type": "field", "outboundTag": "direct", "domain": ["geosite:category-ir", "regexp:.*\\.ir$"] },
  { "type": "field", "outboundTag": "direct", "ip": ["geoip:ir", "geoip:private"] }
] } }
```
EOF
  ui_ok "Client guide written to $out"
}

iran_status() {
  if [[ -x $IRAN_GUARD_BIN ]]; then "$IRAN_GUARD_BIN" status | sed 's/^/  /'; else ui_dim "  not installed"; fi
}
