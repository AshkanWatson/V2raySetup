#!/usr/bin/env bash
# ssl.sh — obtain TLS certificates (acme.sh / certbot / self-signed).
#
# Certificates are always installed to /root/cert/<name>/{fullchain,privkey}.pem
# so every panel can point at the same stable paths, and renewals overwrite
# them in place.

CERT_BASE=${CERT_BASE:-/root/cert}
ACME_HOME=${ACME_HOME:-/root/.acme.sh}

# ssl_questions — asks how to get a certificate. Sets SSL_METHOD, DOMAIN,
# SSL_EMAIL, CF_TOKEN.
ssl_questions() {
  local panel=$1
  SSL_METHOD=none
  if [[ ${P_SSL[$panel]} == builtin ]]; then
    ui_info "${P_NAME[$panel]} obtains and renews its own certificate — skipping the SSL step."
    ui_input domain "Domain pointing to this server (optional, used in the summary)" "" valid_domain_or_empty
    DOMAIN=$UI_VALUE
    return 0
  fi

  ui_input domain "Domain for the panel (empty = no domain, use the IP)" "" valid_domain_or_empty \
    "Point an A record (e.g. panel.example.com → $(public_ip)) to this server first."
  DOMAIN=$UI_VALUE

  if [[ -z $DOMAIN ]]; then
    if [[ ${P_SSL[$panel]} == proxy ]]; then
      ui_warn "${P_NAME[$panel]} without a domain will only be reachable through an SSH tunnel."
    fi
    ui_select ssl_ip "No domain. What about HTTPS for the panel?" 0 \
      "Skip|use plain HTTP / configure later (simplest)" \
      "Self-signed for IP|encrypted, but the browser shows a warning"
    if [[ $UI_INDEX == 1 ]]; then
      SSL_METHOD=selfsigned
      if ! valid_ipv4 "$(public_ip)"; then
        UI_VALIDATION_MSG="Enter this server's public IPv4"
        ui_input server_ip "Couldn't detect the public IP. What is this server's IPv4?" "" valid_ipv4
        PUBLIC_IP=$UI_VALUE
      fi
    fi
    return 0
  fi

  ssl_check_dns "$DOMAIN"

  ui_select ssl_method "How should we get the SSL certificate for $DOMAIN?" 0 \
    "Let's Encrypt · HTTP (acme.sh)|needs port 80 open, domain must point here (recommended)" \
    "Let's Encrypt · Cloudflare DNS (acme.sh)|works behind CDN, needs a Cloudflare API token" \
    "Let's Encrypt · Certbot|classic certbot standalone, needs port 80" \
    "Self-signed|no CA, browser warning, valid 10 years" \
    "Skip|I already have a certificate / do it later"
  case $UI_INDEX in
    0) SSL_METHOD='acme-http' ;;
    1) SSL_METHOD='acme-cf' ;;
    2) SSL_METHOD=certbot ;;
    3) SSL_METHOD=selfsigned ;;
    4) SSL_METHOD=none ;;
  esac

  if [[ $SSL_METHOD == acme-* || $SSL_METHOD == certbot ]]; then
    ui_input email "E-mail for Let's Encrypt expiry notices (optional)" "" valid_email_or_empty
    SSL_EMAIL=$UI_VALUE
  fi
  if [[ $SSL_METHOD == acme-cf ]]; then
    ui_input cf_token "Cloudflare API token (Zone.DNS:Edit permission)" "" valid_nonempty \
      "Create at dash.cloudflare.com → My Profile → API Tokens → 'Edit zone DNS' template"
    CF_TOKEN=$UI_VALUE
  fi
}

# warn when the domain doesn't resolve to this server
ssl_check_dns() {
  local d=$1 ip resolved
  ip=$(public_ip)
  resolved=$(getent ahostsv4 "$d" 2>/dev/null | awk '{print $1; exit}')
  if ! valid_ipv4 "$ip"; then
    [[ -n $resolved ]] && ui_info "$d → $resolved (couldn't detect this server's IP to compare)"
  elif [[ -z $resolved ]]; then
    ui_warn "$d does not resolve yet. HTTP validation will fail until the A record exists."
  elif [[ $resolved != "$ip" ]]; then
    ui_warn "$d resolves to $resolved, but this server is $ip."
    ui_sub "Behind Cloudflare (orange cloud)? Use the Cloudflare DNS method, or switch to grey cloud."
  else
    ui_ok "$d → $resolved (matches this server)"
  fi
}

# ------------------------------------------------------------------ issue ---
ssl_issue() {
  CERT_DIR="$CERT_BASE/${DOMAIN:-$(public_ip)}"
  CERT_FULLCHAIN="$CERT_DIR/fullchain.pem"
  CERT_KEY="$CERT_DIR/privkey.pem"
  run mkdir -p "$CERT_DIR"
  case $SSL_METHOD in
    acme-http | acme-cf) ssl_acme ;;
    certbot) ssl_certbot ;;
    selfsigned) ui_spin "Creating self-signed certificate" ssl_selfsigned ;;
    *) CERT_FULLCHAIN='' CERT_KEY=''; return 0 ;;
  esac
  local rc=$?
  if (( rc != 0 )); then CERT_FULLCHAIN='' CERT_KEY=''; return $rc; fi
  run chmod 600 "$CERT_KEY"
  ui_sub "Certificate: $CERT_FULLCHAIN"
  ui_sub "Private key: $CERT_KEY"
  state_set CERT_FULLCHAIN "$CERT_FULLCHAIN"; state_set CERT_KEY "$CERT_KEY"; state_set DOMAIN "${DOMAIN:-}"
}

ssl_selfsigned() {
  local cn=${DOMAIN:-$(public_ip)} san
  if valid_ipv4 "$cn"; then san="IP:$cn"; else san="DNS:$cn"; fi
  run openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 3650 \
    -keyout "$CERT_KEY" -out "$CERT_FULLCHAIN" -subj "/CN=$cn" -addext "subjectAltName=$san"
}

# services on port 80 that we temporarily stop during HTTP validation
_port80_hooks() {
  ACME_PRE='' ACME_POST=''
  port_in_use 80 || return 0
  local owner; owner=$(port_owner 80)
  case $owner in
    nginx* | apache2* | httpd* | caddy* | haproxy*)
      local svc=${owner%%:*}
      ACME_PRE="systemctl stop $svc"; ACME_POST="systemctl start $svc"
      ui_info "Port 80 is used by $svc — it will be stopped for a few seconds during validation." ;;
    *) ui_warn "Port 80 is used by '${owner:-unknown}'. HTTP validation may fail." ;;
  esac
}

ssl_acme_install() {
  [[ -x $ACME_HOME/acme.sh ]] && return 0
  local tmpd; tmpd=$(mktemp -d)
  fetch https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh "$tmpd/acme.sh" || return 1
  (cd "$tmpd" && sh ./acme.sh --install --home "$ACME_HOME" ${SSL_EMAIL:+--accountemail "$SSL_EMAIL"}) || return 1
  rm -rf "$tmpd"
}

ssl_acme() {
  ui_spin "Installing acme.sh" ssl_acme_install || return 1
  local acme="$ACME_HOME/acme.sh"
  ui_spin "Using Let's Encrypt as CA" "$acme" --set-default-ca --server letsencrypt || return 1
  if [[ $SSL_METHOD == acme-http ]]; then
    _port80_hooks
    ui_spin "Requesting certificate for $DOMAIN (HTTP-01)" "$acme" --issue -d "$DOMAIN" --standalone --httpport 80 \
      --keylength ec-256 ${ACME_PRE:+--pre-hook "$ACME_PRE"} ${ACME_POST:+--post-hook "$ACME_POST"} || _acme_ok_if_exists || return 1
  else
    ui_spin "Requesting certificate for $DOMAIN (Cloudflare DNS-01)" env CF_Token="$CF_TOKEN" "$acme" --issue -d "$DOMAIN" \
      --dns dns_cf --keylength ec-256 || _acme_ok_if_exists || return 1
  fi
  ui_spin "Installing certificate to $CERT_DIR" "$acme" --install-cert -d "$DOMAIN" --ecc \
    --key-file "$CERT_KEY" --fullchain-file "$CERT_FULLCHAIN" || return 1
}
# acme.sh exits 2 when the cert is still valid ("Skipping. Next renewal...")
_acme_ok_if_exists() { [[ -f "$ACME_HOME/${DOMAIN}_ecc/fullchain.cer" ]] && { ui_info "A valid certificate already exists — reusing it."; return 0; }; return 1; }

ssl_certbot() {
  has certbot || ui_spin "Installing certbot" pkg_install certbot || return 1
  _port80_hooks
  local -a mail=(--register-unsafely-without-email)
  [[ -n ${SSL_EMAIL:-} ]] && mail=(-m "$SSL_EMAIL")
  ui_spin "Requesting certificate for $DOMAIN (certbot)" certbot certonly --standalone --preferred-challenges http \
    --non-interactive --agree-tos "${mail[@]}" \
    --keep-until-expiring -d "$DOMAIN" ${ACME_PRE:+--pre-hook "$ACME_PRE"} ${ACME_POST:+--post-hook "$ACME_POST"} || return 1
  run cp -L "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$CERT_FULLCHAIN"
  run cp -L "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$CERT_KEY"
}

# ssl_set_reload — make renewals copy the cert and restart the panel
ssl_set_reload() {
  local cmd=${CERT_RELOAD_CMD:-}
  case $SSL_METHOD in
    acme-http | acme-cf)
      [[ -z $cmd ]] && return 0
      ui_spin "Auto-renew: reload panel after renewal" "$ACME_HOME/acme.sh" --install-cert -d "$DOMAIN" --ecc \
        --key-file "$CERT_KEY" --fullchain-file "$CERT_FULLCHAIN" --reloadcmd "$cmd" ;;
    certbot)
      write_file /etc/letsencrypt/renewal-hooks/deploy/v2raysetup.sh 755 <<EOF
#!/bin/sh
# generated by V2raySetup — copies renewed cert to $CERT_DIR
cp -L /etc/letsencrypt/live/$DOMAIN/fullchain.pem $CERT_FULLCHAIN
cp -L /etc/letsencrypt/live/$DOMAIN/privkey.pem $CERT_KEY
chmod 600 $CERT_KEY
${cmd}
EOF
      ui_ok "Auto-renew hook written (/etc/letsencrypt/renewal-hooks/deploy/v2raysetup.sh)" ;;
  esac
}

ssl_status() {
  local f
  for f in "$CERT_BASE"/*/fullchain.pem; do
    [[ -f $f ]] || continue
    local end; end=$(openssl x509 -enddate -noout -in "$f" 2>/dev/null | cut -d= -f2)
    ui_kv "$(basename "$(dirname "$f")")" "expires $end"
  done
}
