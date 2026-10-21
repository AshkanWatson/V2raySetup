#!/usr/bin/env bash
# V2raySetup — guided installer for V2Ray/Xray/sing-box panels.
# https://github.com/AshkanWatson/V2raySetup
#
#   v2raysetup                 interactive menu
#   v2raysetup install         guided panel installation
#   v2raysetup --help          all commands and flags
set -o pipefail

V2S_VERSION=2.0.0
V2S_DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)

for _m in ui core system panels ssl server iran; do
  # shellcheck source=/dev/null
  source "$V2S_DIR/lib/$_m.sh" || { echo "missing $V2S_DIR/lib/$_m.sh" >&2; exit 1; }
done

usage() {
  cat <<EOF
V2raySetup v$V2S_VERSION — install a V2Ray/Xray panel the easy way

Usage: v2raysetup [command] [options]

Commands:
  (none)          interactive main menu
  install         guided setup: panel → SSL → Iran bypass → firewall → tuning
  panels          list supported panels and whether this server can run them
  ssl             get / renew an SSL certificate only
  iran            block server → Iran IPs (and other Iran options)
  iran-remove     remove the Iran block
  optimize        BBR, swap, file limits, fail2ban
  firewall        open ports in the firewall
  status          show panels, certificates, Iran block, BBR
  help            this help

Options:
  -n, --dry-run          show what would be done, change nothing
  -y, --yes              accept defaults for yes/no questions
      --panel ID         preselect a panel (see 'v2raysetup panels')
      --non-interactive  never prompt; use defaults / V2S_ANSWER_* variables
      --no-color         disable colors
  -v, --version          print version

Automation: every question can be answered with an environment variable,
e.g. V2S_ANSWER_PANEL=3x-ui V2S_ANSWER_DOMAIN=vpn.example.com ...
(see HANDOFF.md for the full list).
EOF
}

# ------------------------------------------------------------ preflight ---
preflight() {
  if [[ $EUID -ne 0 && $DRY_RUN != 1 ]]; then
    ui_err "Please run as root (sudo -i), or use --dry-run to preview."
    exit 1
  fi
  if ! touch "$V2S_LOG" 2>/dev/null; then V2S_LOG=${TMPDIR:-/tmp}/v2raysetup.log; touch "$V2S_LOG"; fi
  detect_system
  fw_detect
  detect_installed_panels
}

system_report() {
  ui_step "System check"
  ui_kv "OS" "$OS_PRETTY ($ARCH)"
  ui_kv "CPU / RAM" "$CPU_CORES core(s) · ${RAM_MB}MB RAM · ${SWAP_MB}MB swap"
  ui_kv "Free disk" "${DISK_FREE_GB}GB on /"
  ui_kv "Kernel / virt" "$KERNEL · $VIRT"
  ui_kv "Public IP" "$(public_ip)"
  ui_kv "SSH port" "$SSH_PORT"
  ui_kv "Firewall" "$FW · package manager: $PKG"
  ui_kv "BBR" "$(bbr_enabled && echo enabled || echo off)"
  if (( ${#INSTALLED_PANELS[@]} )); then
    ui_kv "Installed" "${C_WARN}${INSTALLED_PANELS[*]}${C_RESET}"
  fi
  [[ $PKG == none ]] && ui_warn "No supported package manager found — some steps will fail."
  ui_blank
}

# ---------------------------------------------------------- panel picker ---
choose_panel() {
  local -a items=() id
  for id in "${PANEL_IDS[@]}"; do
    panel_check "$id"
    items+=("${P_NAME[$id]}|$(panel_badge "$PC_LEVEL") ${P_CORE[$id]} · ${P_KIND[$id]}$([[ ${P_STATUS[$id]} == legacy ]] && echo ' · legacy')")
  done
  # allow --panel <id> / V2S_ANSWER_PANEL=<id>
  local pre; if pre=$(ui_preset panel); then
    local i; for i in "${!PANEL_IDS[@]}"; do [[ ${PANEL_IDS[$i]} == "$pre" ]] && export V2S_ANSWER_PANEL=$i; done
  fi
  UI_DETAIL_FN=panel_detail UI_DETAIL_LINES=6 ui_select panel "Which panel do you want to install?" 0 "${items[@]}"
  PANEL=${PANEL_IDS[$UI_INDEX]}
  panel_check "$PANEL"
  if [[ $PC_LEVEL == fail ]]; then
    local m; for m in "${PC_MSGS[@]}"; do [[ $m == "✖"* ]] && ui_err "${m#✖ }"; done
    ui_confirm force "This server does not meet the requirements. Continue anyway?" n || { ui_info "Pick another panel or upgrade the server."; exit 1; }
  elif [[ $PC_LEVEL == warn ]]; then
    local m; for m in "${PC_MSGS[@]}"; do [[ $m == "▲"* ]] && ui_warn "${m#▲ }"; done
  fi
}

list_panels() {
  local id
  printf '%s%-14s %-26s %-22s %-8s %s%s\n' "$C_BOLD" ID NAME CORE "RAM" STATUS "$C_RESET"
  for id in "${PANEL_IDS[@]}"; do
    panel_check "$id"
    printf '%-14s %-26s %-22s %-8s %s\n' "$id" "${P_NAME[$id]}" "${P_CORE[$id]}" "${P_RAM[$id]}MB" "$(panel_badge "$PC_LEVEL")"
  done
}

# ----------------------------------------------------------- the wizard ---
wizard() {
  local total=6
  hdr() { ui_blank; printf '%s── Step %d/%d · %s %s%s\n' "$C_ACCENT" "$1" "$total" "$2" "$(ui_repeat '─' $((UI_COLS - ${#2} - 16)))" "$C_RESET"; }

  hdr 1 "Server"
  system_report

  hdr 2 "Panel"
  choose_panel
  PANEL_OPTS=()
  panel_questions "$PANEL"

  hdr 3 "Domain & SSL"
  ssl_questions "$PANEL"
  [[ $PANEL == remnawave && -n $DOMAIN && $SSL_METHOD == none ]] && ui_warn "Remnawave behind Nginx needs a certificate — you chose to skip it."

  hdr 4 "Iran bypass"
  iran_questions

  hdr 5 "Firewall & tuning"
  local -a extras=()
  local fw_on=on; [[ ${P_SSL[$PANEL]} == builtin ]] && fw_on=off
  local swap_on=off; (( RAM_MB < 2048 && SWAP_MB == 0 )) && swap_on=on
  local bbr_on=on; bbr_enabled && bbr_on=off
  ui_multiselect extras "Server preparation" \
    "Update system packages|apt/dnf upgrade (recommended on a fresh server)|on" \
    "Firewall ($FW)|open SSH($SSH_PORT), 80, 443 and panel ports, deny the rest|$fw_on" \
    "BBR + network tuning|faster TCP, bigger buffers|$bbr_on" \
    "Swap file|helps small servers (< 2GB RAM)|$swap_on" \
    "Raise open-file limits|needed for many concurrent users|on" \
    "fail2ban for SSH|ban brute-force login attempts|off"
  DO_UPDATE=${UI_SELECTED[0]} DO_FW=${UI_SELECTED[1]} DO_BBR=${UI_SELECTED[2]} DO_SWAP=${UI_SELECTED[3]} DO_LIMITS=${UI_SELECTED[4]} DO_F2B=${UI_SELECTED[5]}
  [[ ${P_SSL[$PANEL]} == builtin && $DO_FW == 1 ]] && ui_warn "${P_NAME[$PANEL]} manages its own firewall; enabling ours too may conflict."
  EXTRA_PORTS=''
  if (( DO_FW )); then
    ui_input ports "Extra inbound ports for your proxy configs (space separated, optional)" "" valid_ports_list \
      "Panel default ports (${P_PORTS[$PANEL]}) are opened automatically. Common: 443 8443 2053 2083 2087 2096"
    EXTRA_PORTS=${UI_VALUE//,/ }
  fi

  hdr 6 "Review"
  review_plan
  ui_confirm go "Start the installation?" y || { ui_info "Nothing was changed."; exit 0; }
  execute_plan
}

review_plan() {
  local -a lines=()
  lines+=("${C_BOLD}Panel${C_RESET}       ${P_NAME[$PANEL]} ${C_MUTED}(${P_CORE[$PANEL]}, github.com/${P_REPO[$PANEL]})${C_RESET}")
  [[ -n ${PANEL_OPTS[db]:-} ]] && lines+=("${C_BOLD}Database${C_RESET}    ${PANEL_OPTS[db]}")
  lines+=("${C_BOLD}Domain${C_RESET}      ${DOMAIN:-(none — using IP $(public_ip))}")
  local sslname
  case $SSL_METHOD in
    acme-http) sslname="Let's Encrypt via acme.sh (HTTP)" ;; acme-cf) sslname="Let's Encrypt via acme.sh (Cloudflare DNS)" ;;
    certbot) sslname="Let's Encrypt via certbot" ;; selfsigned) sslname="Self-signed" ;;
    *) sslname=$([[ ${P_SSL[$PANEL]} == builtin ]] && echo "handled by the panel" || echo "skip") ;;
  esac
  lines+=("${C_BOLD}SSL${C_RESET}         $sslname")
  local ir=()
  (( IRAN_BLOCK )) && ir+=("block server→Iran")
  (( IRAN_AUTOUPDATE )) && ir+=("daily update")
  (( IRAN_XRAY )) && ir+=("Xray rules")
  (( IRAN_CLIENT )) && ir+=("client guide")
  lines+=("${C_BOLD}Iran${C_RESET}        $( ((${#ir[@]})) && (IFS=,; echo "${ir[*]}" | sed 's/,/, /g') || echo 'no changes')")
  [[ -n $IRAN_ALLOW ]] && lines+=("${C_BOLD}Iran allow${C_RESET}  $IRAN_ALLOW")
  local srv=()
  (( DO_UPDATE )) && srv+=("update")
  local fwp="$SSH_PORT 80 443 ${P_PORTS[$PANEL]} $EXTRA_PORTS"
  (( DO_FW )) && srv+=("firewall: $(xargs <<<"$fwp")")
  (( DO_BBR )) && srv+=("BBR")
  (( DO_SWAP )) && srv+=("swap")
  (( DO_LIMITS )) && srv+=("limits")
  (( DO_F2B )) && srv+=("fail2ban")
  lines+=("${C_BOLD}Server${C_RESET}      $( ((${#srv[@]})) && (IFS=,; echo "${srv[*]}" | sed 's/,/, /g; s/  */ /g') || echo 'no changes')")
  ui_box "Plan" "${lines[@]}"
}

execute_plan() {
  local failed=0
  ui_blank
  ui_step "Preparing the server"
  ui_spin "Installing base tools (curl, socat, openssl…)" ensure_base_packages || failed=1
  if (( DO_UPDATE )); then ui_spin "Refreshing package lists" pkg_refresh; ui_spin "Upgrading system packages (can take a few minutes)" pkg_upgrade || ui_warn "Upgrade had errors — continuing"; fi
  (( DO_SWAP )) && { create_swap $((RAM_MB < 1024 ? 1024 : 2048)) || true; }
  (( DO_BBR )) && { enable_bbr || true; }
  (( DO_LIMITS )) && raise_limits
  if (( DO_FW )); then
    # shellcheck disable=SC2086
    ui_spin "Configuring firewall ($FW)" fw_setup 80 443 ${P_PORTS[$PANEL]} $EXTRA_PORTS || ui_warn "Firewall setup failed — check $V2S_LOG"
  fi
  (( DO_F2B )) && { install_fail2ban || true; }

  if [[ $SSL_METHOD != none ]]; then
    ui_blank; ui_step "SSL certificate"
    if ! ssl_issue; then
      ui_err "Could not get a certificate. The panel will be installed without it."
      ui_sub "Fix DNS / port 80 and run:  v2raysetup ssl"
      SSL_METHOD=none
    fi
  fi

  ui_blank; ui_step "Installing ${P_NAME[$PANEL]}"
  PANEL_OK=0
  if ! panel_install "$PANEL"; then
    failed=1
    ui_err "Panel installation failed. Full log: $V2S_LOG"
    ui_confirm continue_after_fail "Continue with the remaining steps (Iran bypass, summary)?" y || exit 1
  else
    PANEL_OK=1
    state_set PANEL "$PANEL"
    [[ $SSL_METHOD != none ]] && { panel_apply_ssl "$PANEL"; ssl_set_reload; }
  fi

  if (( IRAN_BLOCK || IRAN_XRAY || IRAN_CLIENT )); then
    ui_blank; ui_step "Iran bypass"
    (( IRAN_BLOCK )) && { iran_apply || { failed=1; ui_err "Iran block failed — see $V2S_LOG"; }; }
    (( IRAN_XRAY )) && iran_write_xray_rules
    (( IRAN_CLIENT )) && iran_write_client_guide
  fi

  if (( DO_FW )) && [[ $DRY_RUN != 1 ]]; then
    local found; found=$(detect_panel_ports)
    local p new=''
    for p in $found; do [[ " 80 443 $SSH_PORT ${P_PORTS[$PANEL]} $EXTRA_PORTS " == *" $p "* ]] || new+="$p "; done
    if [[ -n $new ]]; then
      ui_info "The panel is listening on: ${new}"
      if ui_confirm open_detected "Open these ports in the firewall too?" y; then
        # shellcheck disable=SC2086
        ui_spin "Opening ${new}" fw_allow $new
        [[ $FW == firewalld ]] && run firewall-cmd --reload
      fi
    fi
  fi

  final_summary "$failed"
  return "$failed"
}

final_summary() {
  local failed=$1 host=${DOMAIN:-$(public_ip)} scheme=http n
  [[ ${PANEL_OPTS[https]:-0} == 1 || $SSL_METHOD != none || ${P_SSL[$PANEL]} == builtin ]] && scheme=https
  local -a lines=()
  if (( failed )); then lines+=("${C_WARN}▲ Finished with some errors — see ${V2S_LOG}${C_RESET}")
  else lines+=("${C_OK}✔ ${P_NAME[$PANEL]} is installed${C_RESET}"); fi
  lines+=("")
  if [[ ${PANEL_OK:-0} != 1 ]]; then
    lines+=("${C_ERR}✖ ${P_NAME[$PANEL]} was not installed.${C_RESET} Fix the error above and run: v2raysetup install")
    lines+=("")
  else
  local p1; p1=$(awk '{print $1}' <<<"${P_PORTS[$PANEL]}")
  case $PANEL in
    hiddify | remnawave) lines+=("Panel URL    ${C_INFO}https://${host}${C_RESET} ${C_MUTED}(exact admin link printed above)${C_RESET}") ;;
    3x-ui | x-ui | s-ui | x-ui-franz | x-ui-vaxilu) lines+=("Panel URL    ${C_INFO}${scheme}://${host}:<port>/<path>${C_RESET} ${C_MUTED}(shown by installer)${C_RESET}") ;;
    xray-core) lines+=("Config       /usr/local/etc/xray/config.json") ;;
    *) lines+=("Panel URL    ${C_INFO}${scheme}://${host}:${p1}/${C_RESET}") ;;
  esac
  [[ -n ${CERT_FULLCHAIN:-} ]] && lines+=("Certificate  $CERT_FULLCHAIN" "Private key  $CERT_KEY")
  lines+=("")
  while IFS= read -r n; do [[ -n $n ]] && lines+=("${C_MUTED}›${C_RESET} $n"); done < <(panel_post_notes "$PANEL")
  fi
  (( IRAN_BLOCK )) && [[ $(state_get IRAN_BLOCK) == 1 || $DRY_RUN == 1 ]] && lines+=("${C_MUTED}›${C_RESET} Iran block active · check: v2s-iran-guard status")
  lines+=("${C_MUTED}›${C_RESET} Re-run this tool any time:  v2raysetup")
  ui_blank
  ui_box "Done" "${lines[@]}"
  if [[ $DRY_RUN != 1 ]]; then
    local f=/root/v2raysetup-summary.txt
    { printf 'V2raySetup summary — %s\n\n' "$(date)"; for n in "${lines[@]}"; do ui_strip "$n"; done; } >"$f" 2>/dev/null && chmod 600 "$f" && ui_dim "  Summary saved to $f"
  fi
}

# ------------------------------------------------------ single commands ---
cmd_ssl() {
  ui_step "SSL certificate"
  local saved; saved=$(state_get PANEL 2>/dev/null)
  PANEL=${saved:-3x-ui}
  [[ ${P_SSL[$PANEL]} == builtin ]] && PANEL=3x-ui
  ssl_questions "$PANEL"
  [[ $SSL_METHOD == none ]] && { ui_info "Nothing to do."; return 0; }
  ensure_base_packages
  ssl_issue || return 1
  if [[ -n $saved ]] && ui_confirm apply_ssl "Apply this certificate to ${P_NAME[$saved]} now?" y; then
    PANEL_OPTS=(); panel_apply_ssl "$saved"; ssl_set_reload
  fi
}

cmd_iran() {
  iran_questions
  (( IRAN_BLOCK )) && iran_apply
  (( IRAN_XRAY )) && iran_write_xray_rules
  (( IRAN_CLIENT )) && iran_write_client_guide
  ui_blank; iran_status
}

cmd_optimize() {
  local swap_on=off; (( RAM_MB < 2048 && SWAP_MB == 0 )) && swap_on=on
  ui_multiselect extras "What should we tune?" \
    "BBR + network tuning|faster TCP|on" "Swap file|for < 2GB RAM|$swap_on" \
    "Raise open-file limits||on" "fail2ban for SSH||off" "Update system packages||off"
  local s=("${UI_SELECTED[@]}")
  (( s[4] )) && { ui_spin "Refreshing package lists" pkg_refresh; ui_spin "Upgrading packages" pkg_upgrade; }
  (( s[0] )) && enable_bbr
  (( s[1] )) && create_swap $((RAM_MB < 1024 ? 1024 : 2048))
  (( s[2] )) && raise_limits
  (( s[3] )) && install_fail2ban
  ui_ok "Done"
}

cmd_firewall() {
  ui_input ports "Ports to open (tcp+udp)" "80 443" valid_ports_list "SSH ($SSH_PORT) is always kept open"
  # shellcheck disable=SC2086
  ui_spin "Configuring $FW" fw_setup ${UI_VALUE//,/ }
  [[ $DRY_RUN != 1 ]] && fw_status | sed 's/^/  /'
}

cmd_status() {
  system_report
  ui_step "Certificates"; ssl_status
  ui_step "Iran block"; iran_status
  ui_step "Listening panel ports"; ui_sub "$(detect_panel_ports)"
}

main_menu() {
  while true; do
    ui_select menu "What would you like to do?" 0 \
      "Install a panel|guided setup: panel, SSL, Iran bypass, firewall" \
      "SSL certificate|get or renew a certificate" \
      "Iran bypass|block server → Iran IPs, Xray rules, client guide" \
      "Optimize server|BBR, swap, limits, fail2ban" \
      "Firewall|open ports" \
      "Status|panels, certificates, Iran block" \
      "Remove Iran block|undo the Iran firewall rules" \
      "Exit|"
    case $UI_INDEX in
      0) wizard; return ;;  # exit status of the wizard
      1) cmd_ssl ;;
      2) cmd_iran ;;
      3) cmd_optimize ;;
      4) cmd_firewall ;;
      5) cmd_status ;;
      6) iran_remove ;;
      *) return 0 ;;
    esac
    [[ -n ${V2S_ANSWER_MENU:-} ]] && return 0
    ui_blank
  done
}

# ---------------------------------------------------------------- main ---
main() {
  local cmd=''
  while (( $# )); do
    case $1 in
      -n | --dry-run) DRY_RUN=1 ;;
      -y | --yes) ASSUME_YES=1 ;;
      --panel) export V2S_ANSWER_PANEL=${2:?--panel needs an id}; shift ;;
      --panel=*) export V2S_ANSWER_PANEL=${1#*=} ;;
      --non-interactive) export V2S_NONINTERACTIVE=1 ;;
      --no-color) export V2S_NO_COLOR=1 ;;
      -v | --version) echo "$V2S_VERSION"; exit 0 ;;
      -h | --help | help) usage; exit 0 ;;
      install | panels | ssl | iran | iran-remove | optimize | firewall | status | menu) cmd=$1 ;;
      *) echo "Unknown argument: $1 (see --help)" >&2; exit 2 ;;
    esac
    shift
  done
  ui_init
  preflight
  case $cmd in
    panels) list_panels; exit 0 ;;
    status) cmd_status; exit 0 ;;
  esac
  ui_banner
  case $cmd in
    install) wizard || exit 1 ;;
    ssl) cmd_ssl ;;
    iran) cmd_iran ;;
    iran-remove) iran_remove ;;
    optimize) cmd_optimize ;;
    firewall) cmd_firewall ;;
    *) main_menu ;;
  esac
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
