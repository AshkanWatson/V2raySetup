# V2raySetup

A friendly, guided installer for **V2Ray / Xray / sing-box panels**. Pick a panel from a menu, and V2raySetup checks your server, installs the panel with its official installer, gets an SSL certificate, blocks the server from reaching Iranian IPs, configures the firewall and tunes the server — all from one terminal UI in the style of Claude Code / OpenCode.

```
╭─ ✻ V2raySetup v2.0.0 ───────────────────────────────────────────────────────╮
│ Welcome! Install a V2Ray/Xray panel on this server in a few steps.           │
│ ↑/↓ move · enter select · space toggle · q quit                              │
╰──────────────────────────────────────────────────────────────────────────────╯
? Which panel do you want to install?
❯  1. 3x-ui                      ✔ ready Xray · single server
   2. x-ui (alireza0)            ✔ ready Xray · single server
   3. S-UI                       ✔ ready sing-box · single server
   4. Marzban                    ✔ ready Xray · multi-node
   ...
  ╭─ 3x-ui  · Xray · single server · github.com/MHSanaei/3x-ui
  │ Most popular x-ui fork. Web UI, Reality/VLESS/VMess/Trojan/SS, Telegram bot…
  │ Needs: Ubuntu 20+, Debian 11+, CentOS/Alma/Rocky 8+… · RAM 256MB+ · disk 1GB
  │ ✔ This server meets all requirements
  ╰─
```

## Install

Run as **root** on a fresh server:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/AshkanWatson/V2raySetup/main/install.sh)
```

This downloads the app to `/opt/v2raysetup` and adds the `v2raysetup` command. Run `v2raysetup` again any time for the menu.

Want to look first? Preview everything without changing anything:

```sh
v2raysetup install --dry-run
```

## What the wizard does

| Step | What happens |
|---|---|
| 1. Server | Detects OS, CPU arch, RAM, disk, virtualization, public IP, SSH port, firewall, installed panels |
| 2. Panel | Menu of 13 panels with a live requirement check (✔ ready / ▲ check / ✖ unsupported) + panel questions (database, version, channel) |
| 3. Domain & SSL | Domain (optional) → Let's Encrypt (acme.sh HTTP, acme.sh Cloudflare DNS, certbot), self-signed, or skip. Checks the domain's DNS points to this server |
| 4. Iran bypass | Block server → Iran IPs, daily list updates, Xray routing rules, client "Iran direct" guide |
| 5. Firewall & tuning | System update, firewall (ufw/firewalld/iptables), BBR, swap, file limits, fail2ban, extra ports |
| 6. Review | Shows the full plan in a box, asks for confirmation, then runs it with live progress |

At the end you get a summary box (panel URL, certificate paths, next steps), also saved to `/root/v2raysetup-summary.txt`.

## Supported panels

| Panel | Core | Type | Min / rec. RAM | OS | Notes |
|---|---|---|---|---|---|
| [3x-ui](https://github.com/MHSanaei/3x-ui) | Xray | single server | 256MB / 1GB | Ubuntu 20+, Debian 11+, RHEL-family 8+, Fedora, Arch, Alpine | Most popular. Reality, VLESS, VMess, Trojan, SS, Telegram bot |
| [x-ui (alireza0)](https://github.com/alireza0/x-ui) | Xray | single server | 256MB / 1GB | same as 3x-ui | Stable multi-user fork |
| [S-UI](https://github.com/alireza0/s-ui) | sing-box | single server | 256MB / 1GB | same as 3x-ui | Hysteria2, TUIC, Reality, ShadowTLS, Naive. Panel :2095, sub :2096 |
| [Marzban](https://github.com/Gozargah/Marzban) | Xray | multi-node | 1GB / 2GB | Ubuntu/Debian/RHEL-family (Docker) | API, subscriptions. sqlite / mysql / mariadb |
| [PasarGuard](https://github.com/PasarGuard/panel) | Xray | multi-node | 1GB / 2GB | Ubuntu/Debian/RHEL-family (Docker) | Active Marzban successor. sqlite / timescaledb / postgresql / mysql / mariadb |
| [Marzneshin](https://github.com/marzneshin/Marzneshin) | Xray, sing-box, Hysteria2 | multi-node | 1GB / 2GB | Ubuntu/Debian (Docker) | Marzban fork with separate nodes |
| [Hiddify Manager](https://github.com/hiddify/Hiddify-Manager) | Xray + sing-box | single server | 1GB / 2GB | **Ubuntu 22.04 / 24.04 only** | 20+ protocols, manages its own SSL & firewall, uses 80/443 |
| [Remnawave](https://github.com/remnawave/panel) | Xray | multi-node | 2GB / 4GB | Ubuntu 22+/Debian 12+ (Docker) | Needs a domain; V2raySetup sets up Nginx + SSL in front |
| [H-UI](https://github.com/jonssonyan/h-ui) | Hysteria2 | single server | 256MB / 512MB | Ubuntu 20+, Debian 11+, CentOS 8+ | UDP-based, good on lossy networks. Panel :8081 |
| [Xray-core](https://github.com/XTLS/Xray-core) (no panel) | Xray | single server | 128MB | any systemd distro | Official XTLS installer, edit `config.json` yourself |
| [Npanel](https://github.com/Leiren/Npanel) | Trojan-go/Gost | single server | 256MB | Ubuntu/Debian, amd64 | **Legacy** — kept for old users of this repo |
| [x-ui (FranzKafkaYu)](https://github.com/FranzKafkaYu/x-ui) | Xray | single server | 256MB | Ubuntu 16+, Debian 8+, CentOS 7+ | **Legacy** |
| [x-ui (vaxilu)](https://github.com/vaxilu/x-ui) | Xray | single server | 256MB | Ubuntu 16+, Debian 8+, CentOS 7+ | **Legacy**, original x-ui, unmaintained |

**Which one should I pick?**
- One server, easiest: **3x-ui**.
- Hysteria2 / TUIC / sing-box protocols: **S-UI** (or **H-UI** for Hysteria2 only).
- Many servers / reselling with an API: **PasarGuard** or **Remnawave** (Marzban still works but is less active).
- "Install and forget" with lots of protocols on a fresh Ubuntu: **Hiddify Manager**.

Every panel is installed with **its own official installer** (downloaded fresh from the project's GitHub). V2raySetup hands the terminal over to it, so you answer its questions directly, then takes over again for SSL, Iran rules and the summary.

## SSL certificates

Certificates are always installed to the same place, so any panel can use them:

```
/root/cert/<domain>/fullchain.pem
/root/cert/<domain>/privkey.pem
```

| Method | When to use |
|---|---|
| Let's Encrypt · HTTP (acme.sh) | Default. Domain's A record points to the server, port 80 reachable. Web servers on port 80 are paused for a few seconds automatically |
| Let's Encrypt · Cloudflare DNS (acme.sh) | Domain is behind Cloudflare (orange cloud) or port 80 is blocked. Needs an API token with Zone.DNS:Edit |
| Let's Encrypt · Certbot | If you prefer certbot |
| Self-signed | No domain — encrypts the panel on its IP (browser shows a warning) |

Renewal is automatic (acme.sh cron / certbot timer). After renewal the panel is reloaded: x-ui family via `x-ui setting -webCert`, Marzban/PasarGuard/Marzneshin via `UVICORN_SSL_*` in their `.env`, Remnawave via Nginx.

## Iran bypass

Iranian websites and apps (banks, Digikala, Snapp, Divar, …) see your foreign server's IP when users browse them through the proxy. That gets the IP flagged and often blocked. V2raySetup can:

1. **Block server → Iran IPs** — an `ipset` with every Iranian IP range ([Chocolate4U/Iran-v2ray-rules](https://github.com/Chocolate4U/Iran-v2ray-rules), fallback [ipverse](https://github.com/ipverse/rir-ip)) plus resolved IPs of popular Iranian services. Only **new outgoing** connections are rejected, so **users in Iran can still connect to your server**. Private ranges are never blocked. If the server itself is in Iran, it refuses to block.
2. **Auto-update daily** (systemd timer, or cron).
3. **Xray routing rules** — `geoip:ir` and `.ir` domains → `blocked`, written to `/etc/v2raysetup/xray-iran-routing.json` to paste into your panel.
4. **Client "Iran direct" guide** — how to make v2rayNG / Hiddify / v2rayN / iOS clients open Iranian sites without the proxy (`/etc/v2raysetup/client-iran-direct.md`).

Manage it with the helper:

```sh
v2s-iran-guard status        # active? how many ranges?
v2s-iran-guard check 2.144.0.1
v2s-iran-guard refresh       # download the newest list and apply
v2s-iran-guard remove        # remove all rules (or: v2raysetup iran-remove)
```

Lists you can edit: `/etc/v2raysetup/iran-domains.txt` (domains to block), `iran-extra.txt` (extra IPs/CIDRs), `iran-allow.txt` (Iranian IPs the server must still reach, e.g. an Iran relay server for a tunnel).

## Commands

```
v2raysetup                 interactive menu
v2raysetup install         guided setup
v2raysetup panels          list panels and whether this server can run them
v2raysetup ssl             get / renew a certificate only
v2raysetup iran            Iran bypass options only
v2raysetup iran-remove     remove the Iran block
v2raysetup optimize        BBR, swap, file limits, fail2ban
v2raysetup firewall        open ports
v2raysetup status          panels, certificates, Iran block, BBR

Options: --dry-run  --yes  --panel <id>  --non-interactive  --no-color
```

### Unattended install

Every question can be answered with an environment variable `V2S_ANSWER_<KEY>`:

```sh
V2S_ANSWER_PANEL=3x-ui V2S_ANSWER_VERSION= \
V2S_ANSWER_DOMAIN=vpn.example.com V2S_ANSWER_SSL_METHOD=0 V2S_ANSWER_EMAIL= \
V2S_ANSWER_IRAN=1,2 V2S_ANSWER_IRAN_ALLOW= \
V2S_ANSWER_EXTRAS=1,2,3,5 V2S_ANSWER_PORTS="443 8443" V2S_ANSWER_GO=y \
v2raysetup install --non-interactive
```

See [HANDOFF.md](HANDOFF.md#answer-keys) for all keys.

## Requirements

- Root access, `bash` 4+, `curl` (installed automatically if missing)
- A supported Linux: Ubuntu, Debian, CentOS/RHEL/Alma/Rocky/Oracle, Fedora, Arch, Alpine, openSUSE (depends on the panel)
- Internet access to GitHub (and Docker Hub for Docker-based panels)

## Files

| Path | What |
|---|---|
| `/opt/v2raysetup` | the app |
| `/var/log/v2raysetup.log` | full log of every command |
| `/etc/v2raysetup/` | state, Iran lists, generated Xray rules and client guide |
| `/root/cert/<domain>/` | certificates |
| `/root/v2raysetup-summary.txt` | summary of the last install |

## Troubleshooting

- **"Failed to fetch x-ui version" / GitHub API limits** — V2raySetup detects this and passes the latest version from the normal releases page instead. If GitHub is fully blocked, try again later or use a server with better routing.
- **Let's Encrypt HTTP validation fails** — the domain must point to this server (grey cloud in Cloudflare) and port 80 must be open at your provider. Otherwise use the Cloudflare DNS method. Re-run with `v2raysetup ssl`.
- **Docker "429 Too Many Requests"** — Docker Hub limits shared IPs; pulls are retried automatically, otherwise wait a few minutes and run again.
- **Marzban/PasarGuard/Marzneshin installers show live logs at the end** — press **Ctrl+C** once; V2raySetup continues with the remaining steps.

## Legacy scripts

`installapt.sh` / `installyum.sh` (and their capitalised copies) are the original v1 scripts: open ports 22/80/443/2060, block a few Iranian IPs, update the system and get a certbot certificate. They still work but are superseded by `v2raysetup`.

## فارسی (خلاصه)

این ابزار به شما اجازه می‌دهد با یک منوی ساده، یکی از پنل‌های V2Ray/Xray (مثل 3x-ui، مرزبان، پاسارگارد، هیدیفای، رمناوِیو و ...) را روی سرور نصب کنید. قبل از نصب، منابع سرور (سیستم‌عامل، رم، دیسک) را بررسی می‌کند، سپس گواهی SSL می‌گیرد و می‌تواند **اتصال سرور به آی‌پی‌های ایران را مسدود کند** تا آی‌پی سرور توسط سایت‌ها و اپ‌های ایرانی شناسایی و گزارش نشود (کاربرانی که از ایران وصل می‌شوند مشکلی نخواهند داشت). برای نصب، دستور بخش Install را با کاربر root اجرا کنید.

## License

MIT — see [LICENSE](LICENSE).
