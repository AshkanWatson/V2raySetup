# HANDOFF — V2raySetup v2

Notes for whoever works on this next (human or AI). Read with `README.md`.

## Goal

One bash app where a user picks **any V2Ray/Xray/sing-box panel** from a friendly terminal UI (Claude Code / OpenCode style), the app checks the server meets that panel's requirements, installs it, then handles **SSL**, **Iran IP bypass** (block server → Iran), **firewall** and **server tuning**.

## Layout

```
install.sh            bootstrap: downloads repo tarball → /opt/v2raysetup, links /usr/local/bin/v2raysetup
v2raysetup.sh         entry point: CLI parsing, main menu, 6-step wizard, plan review, execution, summary
lib/ui.sh             TUI: colors, boxes, ● ✔ ▲ ✖ ⎿ glyphs, arrow-key select / multiselect, input, confirm, spinner
lib/core.sh           run()/run_tty() (dry-run aware), write_file, fetch/fetch_script, state file, validators
lib/system.sh         OS/arch/RAM/disk/virt detection, package manager abstraction, ports, docker, installed panels
lib/panels.sh         PANEL CATALOG (metadata), requirement check, per-panel questions, installers, SSL wiring, notes
lib/ssl.sh            acme.sh (HTTP / Cloudflare DNS), certbot, self-signed, renewal hooks
lib/server.sh         firewall (ufw / firewalld / iptables), BBR + sysctl, swap, nofile limits, fail2ban
lib/iran.sh           Iran questions, installs the guard + systemd/cron persistence, Xray rules, client guide
lib/iran-guard.sh     standalone helper → /usr/local/sbin/v2s-iran-guard (ipset + iptables, update/apply/remove/status)
tests/run.sh          test suite (dry-run based, safe anywhere); --pty also drives the real arrow-key UI
tests/pty_drive.py    pseudo-terminal driver used by the PTY test
installapt.sh, installyum.sh (+ capitalised copies)   legacy v1 scripts, untouched
```

## How it works

- **Wizard order** (`execute_plan`): base packages → update → swap/BBR/limits → firewall → **SSL issue** → **panel install** → wire SSL into panel + renewal hook → Iran block → open ports the panel is actually listening on → summary. SSL is issued *before* the panel so port 80 is still free (Hiddify, which grabs 80/443 and does its own SSL, skips our SSL step).
- **Upstream installers are never re-implemented** (except Remnawave, which has no installer script). `panel_install` downloads the official script and runs it with the terminal attached (`run_tty`) so the user answers its prompts. Marzban/PasarGuard/Marzneshin end by following logs; a `trap ':' INT` lets the user press Ctrl+C there without killing the wizard.
- **x-ui family + GitHub API limits**: their installers query `api.github.com`; if that is unreachable we resolve the latest tag through the `github.com/<repo>/releases/latest` redirect and pass it as the version argument.
- **Remnawave**: downloads the official `docker-compose-prod.yml` + `.env.sample`, generates secrets / DB password, pulls with retries (Docker Hub 429), starts, then `nginx_reverse_proxy` puts Nginx + the certificate in front (Remnawave refuses non-proxied HTTP by design).
- **Certificates** always land in `/root/cert/<domain>/{fullchain,privkey}.pem`.
- **Iran block** (`lib/iran-guard.sh`): ipsets `v2s_ir4/v2s_ir6` (+ allow sets) loaded atomically via `ipset restore … swap`; chain `V2S_IRAN` jumped from `OUTPUT` and `FORWARD`; rejects only `ctstate NEW` so inbound users from Iran keep working. Private/reserved ranges are filtered out (the upstream list contains a few Iran-internal 10.x/172.x/192.168.x entries). Refuses to apply if the server's own IP is in the list. Persisted by `v2s-iran-guard.service` (apply at boot) + `v2s-iran-update.timer` (daily refresh), or cron when there is no systemd.
- **Dry-run** (`-n`): every mutating call goes through `run`, `write_file`, `ui_spin` or `run_tty`, which only print in dry-run. Upstream scripts are still downloaded (read-only) unless `V2S_OFFLINE=1`.
- **Non-interactive**: every prompt has a key; `V2S_ANSWER_<KEY>` answers it. Without a TTY, menus fall back to numbered prompts.

## Answer keys

| Key | Question | Value |
|---|---|---|
| `MENU` | main menu | index or label |
| `PANEL` | panel | panel id (`3x-ui`, `x-ui`, `s-ui`, `marzban`, `pasarguard`, `marzneshin`, `hiddify`, `remnawave`, `h-ui`, `xray-core`, `npanel`, `x-ui-franz`, `x-ui-vaxilu`) |
| `FORCE` | continue although requirements fail | y/n |
| `DB` | database (Marzban/Marzneshin/PasarGuard) | index or name |
| `CHANNEL` | Hiddify release/beta | index or name |
| `VERSION` | x-ui family version | tag or empty |
| `DOMAIN` | domain | domain or empty |
| `SSL_IP` | no-domain HTTPS (0 skip, 1 self-signed) | index |
| `SERVER_IP` | public IP when it can't be detected | IPv4 |
| `SSL_METHOD` | 0 acme HTTP, 1 acme Cloudflare, 2 certbot, 3 self-signed, 4 skip | index |
| `EMAIL` | Let's Encrypt e-mail | e-mail or empty |
| `CF_TOKEN` | Cloudflare API token | string |
| `IRAN` | Iran options (1 block, 2 auto-update, 3 Xray rules, 4 client guide) | `1,2,4` / `none` / `default` |
| `IRAN_ALLOW` | Iranian IPs to keep reachable | IPs/CIDRs or empty |
| `EXTRAS` | 1 update, 2 firewall, 3 BBR, 4 swap, 5 limits, 6 fail2ban | `1,2,3` / `none` / `default` |
| `PORTS` | extra firewall ports | `443 8443` or empty |
| `GO` | start installation | y/n |
| `OPEN_DETECTED` | open ports the panel listens on | y/n |
| `CONTINUE_AFTER_FAIL` | continue after a failed panel install | y/n |
| `APPLY_SSL` | (`ssl` command) apply cert to installed panel | y/n |

## Adding a panel

1. Add the id to `PANEL_IDS` and a `_panel …` line in `lib/panels.sh` (name, repo, core, kind, min/rec RAM, disk, docker, ssl mode `certfile|builtin|proxy`, status, default ports, arch list, OS ids, OS note, description).
2. Add its installer URL to the `url` map in `panel_install` (and a `case` branch if it needs special arguments).
3. Optional: questions in `panel_questions`, SSL wiring in `panel_apply_ssl`, tips in `panel_post_notes`, detection in `detect_installed_panels`.
4. Run `bash tests/run.sh` — the dry-run loop covers every id automatically.

## Testing done (sandbox: Ubuntu 24.04 container, root, no systemd)

`bash tests/run.sh --pty` → **69 passed, 0 failed** (syntax, shellcheck, validators, UI width math, Iran helpers, catalog, dry-run of all 13 panels, variants, CLI, real arrow-key session through a PTY).

Real (non-dry-run) checks:

| Area | Result |
|---|---|
| Iran list download (Chocolate4U) | ✔ ~2,090 IPv4 + 713 IPv6 ranges, invalid/private entries filtered |
| Iran block apply / re-apply / remove | ✔ rules + ipsets created, idempotent, cleanly removed; connection to an Iranian IP rejected instantly, allow-listed IP passes |
| `v2raysetup iran` / `iran-remove` | ✔ including cron persistence (cron auto-installed when missing) |
| Self-signed SSL via `v2raysetup ssl` | ✔ correct SAN, key mode 600 |
| acme.sh install | ✔ (issuing a real certificate needs a public domain — not possible in the sandbox) |
| Nginx reverse proxy | ✔ HTTPS 200 over HTTP/2, HTTP → 301 redirect |
| Remnawave full install | ✔ containers healthy, dashboard + `/api/auth/status` via Nginx HTTPS (sandbox needed a test-only lower `nofile` ulimit) |
| Marzban-style "Ctrl+C on logs" | ✔ wizard continues (simulated installer through a PTY) |
| 3x-ui real install | ✖ sandbox blocks `api.github.com`/`github.com` → led to the GitHub-API fallback and correct failure handling |

Bugs found and fixed during testing: box border width off by one; UTF-8 width wrong under non-UTF-8 locale; private IPs in the upstream Iran list; false "cron entries added" without cron; nginx `http2 on` on old nginx; nginx default site breaking on IPv6-less servers; exit code 0 after a failed install; certbot e-mail argument bug; self-signed cert named "unknown" when the public IP can't be detected; Ctrl+C on upstream log viewers killing the wizard.

## Not tested / known limitations

- Real installs of panels whose files come from `github.com` releases (3x-ui, x-ui, s-ui, h-ui, Hiddify, Xray-core) and Docker panels via their own scripts (Marzban, PasarGuard, Marzneshin) — the sandbox can't reach github.com. The scripts are called exactly as their READMEs document (checked on 2026-10-21).
- No systemd in the sandbox: the systemd unit/timer files are generated but were not started here.
- `ufw`/`firewalld` changes were only dry-run tested (container networking).
- Requirement numbers (RAM/disk) are practical guidance from upstream docs/community, not hard limits.
- Upstream installers change often; if one changes its CLI (e.g. Marzban's `install --database`), update `panel_install`.
- Docker-based panels publish ports via Docker, which bypasses ufw rules.

## Ideas for next steps

- Iran ↔ foreign **tunnels** (Backhaul, Rathole, GOST, WireGuard) for users who need an Iranian relay server.
- Node installers (Marzban-node, PasarGuard node, Remnawave node, Marzneshin node) for multi-server setups.
- WARP outbound (Cloudflare) for panels.
- Backup/restore of panel databases.
- Persian (fa) UI translation — strings are centralised enough in `v2raysetup.sh`/`lib/*.sh` to add a simple `t()` helper.
