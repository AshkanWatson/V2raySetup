#!/usr/bin/env bash
# panels.sh — catalog of V2Ray/Xray/sing-box panels and how to install them.
#
# Each panel has metadata used for the menu, the requirement check and the
# firewall. Requirements are the practical minimums from upstream docs and
# community experience; "rec" is what we recommend for ~50+ users.

PANEL_IDS=(3x-ui x-ui s-ui marzban pasarguard marzneshin hiddify remnawave h-ui xray-core npanel x-ui-franz x-ui-vaxilu)

declare -A P_NAME P_REPO P_CORE P_KIND P_DESC P_OS P_OSNOTE P_ARCH P_RAM P_RAMREC P_DISK P_PORTS P_DOCKER P_SSL P_STATUS P_URL

_panel() { # id name repo core kind ram ramrec disk docker ssl status ports arch os osnote desc
  local id=$1
  P_NAME[$id]=$2 P_REPO[$id]=$3 P_CORE[$id]=$4 P_KIND[$id]=$5 P_RAM[$id]=$6 P_RAMREC[$id]=$7
  P_DISK[$id]=$8 P_DOCKER[$id]=$9 P_SSL[$id]=${10} P_STATUS[$id]=${11} P_PORTS[$id]=${12}
  P_ARCH[$id]=${13} P_OS[$id]=${14} P_OSNOTE[$id]=${15} P_DESC[$id]=${16}
}

# ssl modes: certfile = panel reads cert files we provide
#            builtin  = panel obtains/manages SSL itself
#            proxy    = panel listens on localhost, we put nginx+SSL in front
_panel 3x-ui "3x-ui" MHSanaei/3x-ui "Xray" "single server" 256 1024 1 0 certfile active "2053" \
  "amd64 arm64 armv7 armv6 armv5 386 s390x" \
  "ubuntu debian centos rhel almalinux rocky ol fedora arch manjaro parch armbian opensuse-tumbleweed opensuse-leap alpine amzn virtuozzo" \
  "Ubuntu 20+, Debian 11+, CentOS/Alma/Rocky 8+, Fedora, Arch, Alpine" \
  "Most popular x-ui fork. Web UI, Reality/VLESS/VMess/Trojan/SS, Telegram bot, traffic limits."
_panel x-ui "x-ui (alireza0)" alireza0/x-ui "Xray" "single server" 256 1024 1 0 certfile active "54321" \
  "amd64 arm64 armv7 armv6 armv5 386 s390x" \
  "ubuntu debian centos rhel almalinux rocky ol fedora arch manjaro armbian opensuse-tumbleweed alpine amzn" \
  "Ubuntu 20+, Debian 11+, CentOS 8+, Fedora, Arch, Alpine" \
  "Stable multi-user x-ui fork with multi-protocol inbounds and Telegram bot."
_panel s-ui "S-UI" alireza0/s-ui "sing-box" "single server" 256 1024 1 0 certfile active "2095 2096" \
  "amd64 arm64 armv7 armv6 armv5 386 s390x" \
  "ubuntu debian centos rhel almalinux rocky ol fedora arch manjaro armbian opensuse-tumbleweed alpine amzn" \
  "Ubuntu 20+, Debian 11+, CentOS 8+, Fedora, Arch" \
  "sing-box panel: Hysteria2, TUIC, Reality, ShadowTLS, VLESS, Trojan, Naive. Panel :2095, sub :2096."
_panel marzban "Marzban" Gozargah/Marzban "Xray" "multi-node" 1024 2048 5 1 certfile active "8000" \
  "amd64 arm64" \
  "ubuntu debian centos rhel almalinux rocky fedora arch opensuse-leap opensuse-tumbleweed" \
  "Ubuntu 20+, Debian 11+, CentOS/Alma/Rocky 8+ (Docker)" \
  "Docker panel with REST API, subscriptions, multi-node, Telegram bot. Dashboard :8000. Less active now, see PasarGuard."
_panel pasarguard "PasarGuard" PasarGuard/panel "Xray" "multi-node" 1024 2048 5 1 certfile active "8000" \
  "amd64 arm64" \
  "ubuntu debian centos rhel almalinux rocky fedora arch opensuse-leap opensuse-tumbleweed" \
  "Ubuntu 20+, Debian 11+, CentOS/Alma/Rocky 8+ (Docker)" \
  "Actively developed Marzban successor. Docker, multi-node, groups, many DB backends. Dashboard :8000."
_panel marzneshin "Marzneshin" marzneshin/Marzneshin "Xray/sing-box/Hysteria" "multi-node" 1024 2048 5 1 certfile active "8000" \
  "amd64 arm64" \
  "ubuntu debian centos rhel almalinux rocky fedora" \
  "Ubuntu 20+, Debian 11+ (Docker)" \
  "Marzban fork with separate nodes, multi-core (Xray, sing-box, Hysteria2). Dashboard :8000."
_panel hiddify "Hiddify Manager" hiddify/Hiddify-Manager "Xray + sing-box" "single server" 1024 2048 10 0 builtin active "80 443" \
  "amd64 arm64" \
  "ubuntu" \
  "Ubuntu 22.04 / 24.04 only, fresh server" \
  "All-in-one anti-censorship toolbox (20+ protocols, Reality, Telegram proxy). Uses 80/443 itself, manages SSL & firewall."
_panel remnawave "Remnawave" remnawave/panel "Xray" "multi-node" 2048 4096 10 1 proxy active "443" \
  "amd64 arm64" \
  "ubuntu debian centos rhel almalinux rocky fedora" \
  "Ubuntu 22+, Debian 12+ recommended (Docker)" \
  "Modern panel + separate Remnawave Node on each server. Needs a domain; we put Nginx+SSL in front."
_panel h-ui "H-UI" jonssonyan/h-ui "Hysteria2" "single server" 256 512 1 0 certfile active "8081" \
  "amd64 arm64" \
  "ubuntu debian centos rhel almalinux rocky" \
  "Ubuntu 20+, Debian 11+, CentOS 8+" \
  "Lightweight Hysteria2 panel (UDP based, great on lossy networks). Panel :8081."
_panel xray-core "Xray-core only (no panel)" XTLS/Xray-core "Xray" "single server" 128 256 1 0 certfile active "443" \
  "amd64 arm64 armv7 armv6 386 s390x" \
  "ubuntu debian centos rhel almalinux rocky ol fedora arch opensuse-leap opensuse-tumbleweed amzn" \
  "Any systemd distro" \
  "Official XTLS installer: just the core as a systemd service. For experts who edit config.json."
_panel npanel "Npanel" Leiren/Npanel "Trojan-go/Gost" "single server" 256 512 1 0 certfile legacy "2060" \
  "amd64" \
  "ubuntu debian" \
  "Ubuntu 20 / Debian (apt only, amd64 only)" \
  "Legacy (last release v0.2.8 alpha). Kept for old users of this repo. Overwrites /etc/resolv.conf."
_panel x-ui-franz "x-ui (FranzKafkaYu)" FranzKafkaYu/x-ui "Xray" "single server" 256 512 1 0 certfile legacy "54321" \
  "amd64 arm64 s390x" \
  "ubuntu debian centos" \
  "Ubuntu 16+, Debian 8+, CentOS 7+" \
  "Legacy x-ui fork (Chinese/English). Prefer 3x-ui for new servers."
_panel x-ui-vaxilu "x-ui (vaxilu, original)" vaxilu/x-ui "Xray" "single server" 256 512 1 0 certfile legacy "54321" \
  "amd64 arm64 s390x" \
  "ubuntu debian centos" \
  "Ubuntu 16+, Debian 8+, CentOS 7+" \
  "The original x-ui. Unmaintained since 2021 — only for compatibility."

# ------------------------------------------------------- requirement check ---
# panel_check ID → sets PC_LEVEL (ok|warn|fail) and PC_MSGS array
panel_check() {
  local id=$1
  PC_LEVEL=ok; PC_MSGS=()
  _pc() { PC_MSGS+=("$2 $3"); if [[ $1 == fail ]]; then PC_LEVEL=fail; elif [[ $1 == warn && $PC_LEVEL == ok ]]; then PC_LEVEL=warn; fi; }

  if os_matches "${P_OS[$id]}"; then _pc ok "✔" "OS $OS_PRETTY"
  else _pc fail "✖" "OS $OS_PRETTY not supported (needs ${P_OSNOTE[$id]})"; fi

  if [[ " ${P_ARCH[$id]} " == *" $ARCH "* ]]; then _pc ok "✔" "CPU arch $ARCH"
  else _pc fail "✖" "CPU arch $ARCH not supported (${P_ARCH[$id]})"; fi

  if [[ $id == hiddify ]] && os_matches ubuntu && ! [[ "$OS_VERSION" == 22.04 || "$OS_VERSION" == 24.04 ]]; then
    _pc fail "✖" "Hiddify needs Ubuntu 22.04 or 24.04 (you have $OS_VERSION)"
  fi
  if [[ $id == npanel && $PKG != apt ]]; then _pc fail "✖" "Npanel installer only works with apt"; fi

  if (( RAM_MB + SWAP_MB < P_RAM[$id] * 9 / 10 )); then _pc fail "✖" "RAM ${RAM_MB}MB < minimum ${P_RAM[$id]}MB"
  elif (( RAM_MB < P_RAM[$id] * 9 / 10 )); then _pc warn "▲" "RAM ${RAM_MB}MB below ${P_RAM[$id]}MB, relying on swap"
  elif (( RAM_MB < P_RAMREC[$id] * 9 / 10 )); then _pc warn "▲" "RAM ${RAM_MB}MB ok (recommended ${P_RAMREC[$id]}MB+)"
  else _pc ok "✔" "RAM ${RAM_MB}MB"; fi

  if (( DISK_FREE_GB < P_DISK[$id] )); then _pc fail "✖" "Free disk ${DISK_FREE_GB}GB < ${P_DISK[$id]}GB"
  else _pc ok "✔" "Free disk ${DISK_FREE_GB}GB"; fi

  if [[ ${P_DOCKER[$id]} == 1 && ( $VIRT == openvz || $VIRT == lxc ) ]]; then
    _pc warn "▲" "Docker on $VIRT containers often fails"
  fi
  if [[ $HAS_SYSTEMD != 1 && $id != hiddify ]]; then _pc warn "▲" "systemd not detected — services may not start"; fi
  if [[ ${P_STATUS[$id]} == legacy ]]; then _pc warn "▲" "Legacy/unmaintained project"; fi
  local p
  for p in ${P_PORTS[$id]}; do
    if port_in_use "$p"; then _pc warn "▲" "Port $p already in use by $(port_owner "$p")"; fi
  done
  return 0
}

panel_badge() {
  case $1 in
    ok) printf '%s✔ ready%s' "$C_OK" "$C_RESET" ;;
    warn) printf '%s▲ check%s' "$C_WARN" "$C_RESET" ;;
    fail) printf '%s✖ unsupported%s' "$C_ERR" "$C_RESET" ;;
  esac
}

# details panel shown under the panel menu for the highlighted item
panel_detail() {
  local id=${PANEL_IDS[$1]} m
  panel_check "$id"
  printf '  %s╭─ %s%s%s  %s· %s · %s · github.com/%s%s\n' "$C_MUTED" "$C_RESET$C_BOLD" "${P_NAME[$id]}" "$C_RESET" "$C_MUTED" "${P_CORE[$id]}" "${P_KIND[$id]}" "${P_REPO[$id]}" "$C_RESET"
  printf '  %s│%s %s\n' "$C_MUTED" "$C_RESET" "$(ui_trunc "${P_DESC[$id]}" $((UI_COLS - 6)))"
  printf '  %s│%s %sNeeds:%s %s · RAM %sMB+ (rec %sMB) · disk %sGB%s\n' "$C_MUTED" "$C_RESET" "$C_MUTED" "$C_RESET" \
    "$(ui_trunc "${P_OSNOTE[$id]}" 44)" "${P_RAM[$id]}" "${P_RAMREC[$id]}" "${P_DISK[$id]}" "$([[ ${P_DOCKER[$id]} == 1 ]] && echo ' · Docker')"
  local shown=0
  for m in "${PC_MSGS[@]}"; do
    [[ $m == "✔"* ]] && continue
    (( shown >= 2 )) && break
    if [[ $m == "✖"* ]]; then printf '  %s│%s %s%s%s\n' "$C_MUTED" "$C_RESET" "$C_ERR" "$m" "$C_RESET"
    else printf '  %s│%s %s%s%s\n' "$C_MUTED" "$C_RESET" "$C_WARN" "$m" "$C_RESET"; fi
    shown=$((shown + 1))
  done
  (( shown == 0 )) && printf '  %s│%s %s✔ This server meets all requirements%s\n' "$C_MUTED" "$C_RESET" "$C_OK" "$C_RESET"
  (( shown < 2 )) && printf '  %s│%s\n' "$C_MUTED" "$C_RESET"
  printf '  %s╰─%s\n' "$C_MUTED" "$C_RESET"
}

# ------------------------------------------------------------ questions ---
# Panel specific questions. Sets PANEL_ARGS (array) and PANEL_OPTS (assoc).
declare -A PANEL_OPTS
panel_questions() {
  local id=$1
  PANEL_ARGS=()
  case $id in
    marzban | marzneshin)
      ui_select db "Which database should ${P_NAME[$id]} use?" 0 \
        "sqlite|simplest, fine for < 300 users" "mysql|better for many users" "mariadb|MySQL-compatible, lighter"
      [[ $UI_VALUE != sqlite ]] && PANEL_ARGS+=(--database "$UI_VALUE")
      PANEL_OPTS[db]=$UI_VALUE ;;
    pasarguard)
      ui_select db "Which database should PasarGuard use?" 0 \
        "sqlite|simplest, fine for small setups" "timescaledb|recommended by upstream for big setups" \
        "postgresql|robust" "mysql|" "mariadb|"
      [[ $UI_VALUE != sqlite ]] && PANEL_ARGS+=(--database "$UI_VALUE")
      PANEL_OPTS[db]=$UI_VALUE ;;
    hiddify)
      ui_select channel "Which Hiddify release channel?" 0 "release|stable (recommended)" "beta|newer features, may break"
      PANEL_ARGS+=("$UI_VALUE") ;;
    3x-ui | x-ui | s-ui)
      ui_input version "Version to install (empty = latest)" "" "" "e.g. v2.6.0 — leave empty for the latest release"
      [[ -n $UI_VALUE ]] && PANEL_ARGS+=("$UI_VALUE") ;;
    remnawave)
      if [[ -z "${DOMAIN:-}" ]]; then
        ui_warn "Remnawave's dashboard must be served on a domain with HTTPS."
      fi ;;
  esac
}

# --------------------------------------------------------------- install ---
# panel_install ID — runs the upstream installer attached to the terminal.
panel_install() {
  local id=$1 s
  local -A url=(
    [3x-ui]=https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh
    [x-ui]=https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh
    [s-ui]=https://raw.githubusercontent.com/alireza0/s-ui/master/install.sh
    [marzban]=https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh
    [pasarguard]=https://github.com/PasarGuard/scripts/raw/main/pasarguard.sh
    [marzneshin]=https://github.com/marzneshin/Marzneshin/raw/master/script.sh
    [hiddify]=https://raw.githubusercontent.com/hiddify/Hiddify-Manager/main/common/download.sh
    [h-ui]=https://raw.githubusercontent.com/jonssonyan/h-ui/main/install.sh
    [xray-core]=https://github.com/XTLS/Xray-install/raw/main/install-release.sh
    [npanel]=https://raw.githubusercontent.com/Leiren/Npanel/master/scripts/install.sh
    [x-ui-franz]=https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install_en.sh
    [x-ui-vaxilu]=https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh
  )
  if [[ $id == remnawave ]]; then remnawave_install; return; fi

  ui_step "Downloading the official ${P_NAME[$id]} installer"
  if ! s=$(fetch_script "${url[$id]}"); then
    ui_err "Could not download ${url[$id]} (GitHub blocked? try again or set a proxy)"
    return 1
  fi
  ui_sub "${url[$id]}"
  # x-ui family installers look up the latest version through the GitHub API,
  # which is often rate-limited on VPS IPs. If the API is unreachable, resolve
  # the latest tag via the normal releases redirect and pass it explicitly.
  if [[ $id == 3x-ui || $id == x-ui || $id == s-ui ]] && (( ${#PANEL_ARGS[@]} == 0 )) && [[ $DRY_RUN != 1 ]]; then
    if ! curl -fsS --max-time 8 "https://api.github.com/repos/${P_REPO[$id]}/releases/latest" -o /dev/null 2>/dev/null; then
      local tag; tag=$(latest_tag_noapi "${P_REPO[$id]}")
      if [[ -n $tag ]]; then PANEL_ARGS=("$tag"); ui_sub "GitHub API unavailable — using latest release $tag"; fi
    fi
  fi
  ui_blank
  ui_rule
  ui_dim "  ↓ Handing over to the ${P_NAME[$id]} installer. Answer its questions below. ↓"
  ui_rule
  local rc=0
  case $id in
    marzban | pasarguard | marzneshin)
      ui_info "${C_BOLD}When the installer starts showing live logs, press Ctrl+C — V2raySetup will continue.${C_RESET}"
      # The installer ends by following logs until Ctrl+C. A no-op trap (not '')
      # keeps this script alive while the child still gets the default SIGINT.
      trap ':' INT
      run_tty bash "$s" install "${PANEL_ARGS[@]}" || rc=$?
      trap - INT
      # Ctrl+C on the log viewer (130) is a normal way to finish
      if (( rc == 130 || rc == 2 )) && has "$id"; then rc=0; fi ;;
    xray-core) run_tty bash "$s" install || rc=$? ;;
    *) run_tty bash "$s" "${PANEL_ARGS[@]}" || rc=$? ;;
  esac
  ui_rule
  rm -f "$s"
  if (( rc != 0 )); then ui_err "${P_NAME[$id]} installer exited with code $rc"; return "$rc"; fi
  ui_ok "${P_NAME[$id]} installer finished"
}

latest_tag_noapi() { # owner/repo → tag from the /releases/latest redirect
  curl -fsSI --max-time 8 "https://github.com/$1/releases/latest" 2>/dev/null |
    awk -F/ 'tolower($1) ~ /^location:/ {print $NF}' | tr -d '\r\n'
}

# ------------------------------------------------------------- remnawave ---
remnawave_install() {
  local dir=/opt/remnawave
  ui_spin "Installing Docker (if missing)" ensure_docker || return 1
  run mkdir -p "$dir"
  ui_spin "Downloading Remnawave docker-compose.yml" fetch https://raw.githubusercontent.com/remnawave/backend/refs/heads/main/docker-compose-prod.yml "$dir/docker-compose.yml" || return 1
  ui_spin "Downloading Remnawave .env template" fetch https://raw.githubusercontent.com/remnawave/backend/refs/heads/main/.env.sample "$dir/.env" || return 1
  if [[ $DRY_RUN != 1 ]]; then
    local pg; pg=$(rand_pass 24)
    local k
    for k in APP_SECRET JWT_AUTH_SECRET JWT_API_TOKENS_SECRET WEBHOOK_SECRET_HEADER; do
      sed -i -E "s|^${k}=.*|${k}=$(rand_hex 32)|" "$dir/.env"
    done
    sed -i -E "s|^METRICS_PASS=.*|METRICS_PASS=$(rand_pass 20)|" "$dir/.env"
    sed -i -E "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$pg|" "$dir/.env"
    sed -i -E "s|^(DATABASE_URL=\"postgresql://postgres:)[^@]*@|\1$pg@|" "$dir/.env"
    if [[ -n "${DOMAIN:-}" ]]; then
      sed -i -E "s|^PANEL_DOMAIN=.*|PANEL_DOMAIN=$DOMAIN|; s|^SUB_PUBLIC_DOMAIN=.*|SUB_PUBLIC_DOMAIN=$DOMAIN/api/sub|" "$dir/.env"
    fi
    chmod 600 "$dir/.env"
  fi
  ui_ok "Generated random secrets and database password in $dir/.env"
  # Docker Hub rate-limits shared VPS IPs (HTTP 429) — retry the pull a few times.
  ui_spin "Pulling Remnawave images" bash -c "cd $dir && for i in 1 2 3 4; do docker compose pull && exit 0; echo 'retrying in \$((i * 15))s'; sleep \$((i * 15)); done; exit 1" || return 1
  ui_spin "Starting Remnawave containers" bash -c "cd $dir && docker compose up -d" || return 1
  PANEL_OPTS[local_url]="http://127.0.0.1:3000"
}

# nginx reverse proxy with SSL in front of a local panel port
nginx_reverse_proxy() { # domain upstream_port
  local d=$1 up=$2
  has nginx || ui_spin "Installing Nginx" pkg_install nginx || return 1
  write_file "/etc/nginx/conf.d/v2s-$d.conf" 644 <<EOF
# generated by V2raySetup
map \$http_upgrade \$connection_upgrade { default upgrade; "" close; }
server {
    listen 80;
    server_name $d;
    location /.well-known/acme-challenge/ { root /var/www/html; }
    location / { return 301 https://\$host\$request_uri; }
}
server {
    listen 443 ssl;
    http2 on;
    server_name $d;
    ssl_certificate     $CERT_FULLCHAIN;
    ssl_certificate_key $CERT_KEY;
    ssl_protocols TLSv1.2 TLSv1.3;
    location / {
        proxy_pass http://127.0.0.1:$up;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
    }
}
EOF
  if [[ $DRY_RUN != 1 ]]; then
    local t; t=$(nginx -t 2>&1)
    # older nginx (< 1.25.1) does not know "http2 on;"
    if grep -q 'unknown directive "http2"' <<<"$t"; then
      sed -i 's/^    listen 443 ssl;/    listen 443 ssl http2;/; /^    http2 on;/d' "/etc/nginx/conf.d/v2s-$d.conf"
      t=$(nginx -t 2>&1)
    fi
    # servers with IPv6 disabled: the stock default site's "listen [::]:80" breaks nginx
    if grep -q 'Address family not supported' <<<"$t" && [[ -f /etc/nginx/sites-enabled/default ]]; then
      sed -i -E 's/^(\s*listen \[::\].*)$/# disabled by V2raySetup (no IPv6): \1/' /etc/nginx/sites-enabled/default
      ui_info "IPv6 is disabled on this server — turned off IPv6 listen lines in the default Nginx site."
    fi
  fi
  ui_spin "Testing Nginx config" nginx -t || return 1
  if [[ $HAS_SYSTEMD == 1 ]]; then
    ui_spin "Reloading Nginx" bash -c 'systemctl enable --now nginx && systemctl reload nginx'
  else
    ui_spin "Reloading Nginx" bash -c 'nginx -s reload 2>/dev/null || nginx'
  fi
}

# ------------------------------------------------------ SSL integration ---
# Wire an issued certificate into the installed panel (best effort).
panel_apply_ssl() {
  local id=$1
  [[ -z "${CERT_FULLCHAIN:-}" ]] && return 0
  case $id in
    3x-ui | x-ui | x-ui-franz | x-ui-vaxilu)
      if [[ -x /usr/local/x-ui/x-ui ]] || [[ $DRY_RUN == 1 ]]; then
        # 3x-ui: "setting -webCert", alireza0/x-ui: "cert -webCert"
        if ui_spin "Setting panel certificate" bash -c "/usr/local/x-ui/x-ui setting -webCert '$CERT_FULLCHAIN' -webCertKey '$CERT_KEY' || /usr/local/x-ui/x-ui cert -webCert '$CERT_FULLCHAIN' -webCertKey '$CERT_KEY'"; then
          ui_spin "Restarting x-ui" systemctl restart x-ui
          PANEL_OPTS[https]=1
        else
          ui_warn "Could not set it automatically. In the panel: Settings → Panel → Certificate paths."
        fi
      fi ;;
    marzban | pasarguard | marzneshin)
      local env=/opt/$id/.env data=/var/lib/$id
      [[ $id == marzneshin ]] && env=/etc/opt/marzneshin/.env
      if [[ -f $env || $DRY_RUN == 1 ]]; then
        run mkdir -p "$data/certs"
        run cp -L "$CERT_FULLCHAIN" "$data/certs/fullchain.pem"
        run cp -L "$CERT_KEY" "$data/certs/key.pem"
        if [[ $DRY_RUN != 1 ]]; then
          sed -i -E '/^#? *UVICORN_SSL_(CERTFILE|KEYFILE)/d' "$env"
          printf 'UVICORN_SSL_CERTFILE = "%s"\nUVICORN_SSL_KEYFILE = "%s"\n' "$data/certs/fullchain.pem" "$data/certs/key.pem" >>"$env"
        fi
        ui_ok "Added UVICORN_SSL_* to $env"
        has "$id" && ui_spin "Restarting ${P_NAME[$id]}" "$id" restart -n
        PANEL_OPTS[https]=1
        # re-copy on renewal
        CERT_RELOAD_CMD="cp -L $CERT_FULLCHAIN $data/certs/fullchain.pem && cp -L $CERT_KEY $data/certs/key.pem && $id restart -n"
      fi ;;
    remnawave)
      nginx_reverse_proxy "$DOMAIN" 3000 && PANEL_OPTS[https]=1
      CERT_RELOAD_CMD="systemctl reload nginx" ;;
    hiddify) : ;;
    *) ui_info "Set these paths in the panel's TLS/certificate settings:"
       ui_kv "Certificate" "$CERT_FULLCHAIN"; ui_kv "Private key" "$CERT_KEY" ;;
  esac
}

# --------------------------------------------------------- after install ---
panel_post_notes() {
  local id=$1
  case $id in
    3x-ui | x-ui | x-ui-franz | x-ui-vaxilu)
      echo "Manage the panel with:  x-ui   (menu: change port/user/password, SSL, logs)"
      [[ $id == 3x-ui ]] && echo "Login info is printed by the installer; show it again with: x-ui settings" ;;
    s-ui) echo "Manage with: s-ui   · Panel http://IP:2095/app/ · Subscriptions :2096" ;;
    marzban | pasarguard | marzneshin)
      echo "Create the first admin:  $id cli admin create --sudo"
      echo "Dashboard path: /dashboard/  ·  manage: $id up|down|logs|update" ;;
    hiddify) echo "Open the admin link printed by the installer. Menu: hiddify (or bash /opt/hiddify-manager/menu.sh)" ;;
    remnawave)
      echo "Open https://${DOMAIN:-YOUR_DOMAIN} and register the first (super-admin) account."
      echo "Then install Remnawave Node on each proxy server (Nodes → Add node shows the docker-compose)."
      echo "No domain? Use an SSH tunnel:  ssh -L 3000:127.0.0.1:3000 root@SERVER  → http://127.0.0.1:3000" ;;
    h-ui) echo "Panel: http://IP:8081 — default login is printed by the installer; change it immediately." ;;
    xray-core) echo "Edit /usr/local/etc/xray/config.json then: systemctl restart xray" ;;
    npanel) echo "Panel: http://IP:2060 — see https://github.com/Leiren/Npanel" ;;
  esac
}
