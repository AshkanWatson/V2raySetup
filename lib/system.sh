#!/usr/bin/env bash
# system.sh — OS/hardware detection, package management, ports, firewall.

detect_system() {
  OS_ID=unknown OS_VERSION='' OS_LIKE='' OS_PRETTY='Unknown Linux'
  if [[ -r "${V2S_OS_RELEASE:-/etc/os-release}" ]]; then
    # shellcheck disable=SC1090
    OS_ID=$(. "${V2S_OS_RELEASE:-/etc/os-release}"; echo "${ID:-unknown}")
    OS_VERSION=$(. "${V2S_OS_RELEASE:-/etc/os-release}"; echo "${VERSION_ID:-}")
    OS_LIKE=$(. "${V2S_OS_RELEASE:-/etc/os-release}"; echo "${ID_LIKE:-}")
    OS_PRETTY=$(. "${V2S_OS_RELEASE:-/etc/os-release}"; echo "${PRETTY_NAME:-$OS_ID $OS_VERSION}")
  fi
  OS_ID=${OS_ID,,}
  OS_MAJOR=${OS_VERSION%%.*}

  if has apt-get; then PKG=apt
  elif has dnf; then PKG=dnf
  elif has yum; then PKG=yum
  elif has pacman; then PKG=pacman
  elif has apk; then PKG=apk
  elif has zypper; then PKG=zypper
  else PKG=none; fi

  case "$(uname -m)" in
    x86_64 | amd64) ARCH=amd64 ;;
    aarch64 | arm64 | armv8*) ARCH=arm64 ;;
    armv7*) ARCH=armv7 ;;
    armv6*) ARCH=armv6 ;;
    i386 | i686) ARCH=386 ;;
    s390x) ARCH=s390x ;;
    *) ARCH=$(uname -m) ;;
  esac

  RAM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)
  SWAP_MB=$(awk '/SwapTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)
  CPU_CORES=$(nproc 2>/dev/null || echo 1)
  DISK_FREE_GB=$(df -Pk / 2>/dev/null | awk 'NR==2 {printf "%d", $4/1024/1024}')
  DISK_FREE_GB=${DISK_FREE_GB:-0}
  KERNEL=$(uname -r)
  VIRT=$(systemd-detect-virt 2>/dev/null || echo unknown)
  [[ -d /proc/vz && ! -d /proc/bc ]] && VIRT=openvz
  HAS_SYSTEMD=0; [[ -d /run/systemd/system ]] && HAS_SYSTEMD=1
  SSH_PORT=$(detect_ssh_port)
}

# os_matches "ubuntu debian centos ..." — exact id or ID_LIKE match
os_matches() {
  local w
  for w in $1; do
    [[ "$w" == any ]] && return 0
    [[ "$OS_ID" == "$w" ]] && return 0
    [[ " $OS_LIKE " == *" $w "* ]] && return 0
  done
  return 1
}

# version_ge A B  (numeric dotted compare)
version_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]; }

detect_ssh_port() {
  local p=''
  if has sshd; then p=$(sshd -T 2>/dev/null | awk '/^port / {print $2; exit}'); fi
  [[ -z "$p" && -r /etc/ssh/sshd_config ]] && p=$(awk 'tolower($1)=="port" {print $2; exit}' /etc/ssh/sshd_config)
  [[ -z "$p" ]] && p=$(ss -ltnp 2>/dev/null | awk '/sshd/ {split($4,a,":"); print a[length(a)]; exit}')
  [[ "$p" =~ ^[0-9]+$ ]] || p=22
  echo "$p"
}

public_ip() {
  [[ -n "${PUBLIC_IP:-}" ]] && { echo "$PUBLIC_IP"; return; }
  local u ip=''
  for u in https://api.ipify.org https://ipv4.icanhazip.com https://ifconfig.me/ip https://ip.sb; do
    ip=$(curl -4 -fsS --max-time 6 "$u" 2>/dev/null | tr -d '[:space:]')
    valid_ipv4 "$ip" && break
    ip=''
  done
  [[ -z "$ip" ]] && ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
  PUBLIC_IP=${ip:-unknown}
  echo "$PUBLIC_IP"
}

port_in_use() { # port_in_use PORT [tcp|udp]
  local p="$1" proto="${2:-tcp}" flag=-ltn
  [[ "$proto" == udp ]] && flag=-lun
  if has ss; then ss $flag 2>/dev/null | awk -v p=":$p\$" '$4 ~ p {f=1} END {exit !f}'
  elif has netstat; then netstat ${flag}p 2>/dev/null | awk -v p=":$p\$" '$4 ~ p {f=1} END {exit !f}'
  else return 1; fi
}
port_owner() { ss -ltnp 2>/dev/null | awk -v p=":$1\$" '$4 ~ p {print $NF; exit}' | sed -E 's/.*\(\("([^"]+)".*/\1/'; }

# ------------------------------------------------------------ packages ---
pkg_name() { # translate generic package names per distro
  local n="$1"
  case "$PKG:$n" in
    apt:cron) echo cron ;;
    dnf:cron | yum:cron) echo cronie ;;
    pacman:cron) echo cronie ;;
    apk:cron) echo dcron ;;
    *:dnsutils) case $PKG in apt) echo dnsutils ;; apk) echo bind-tools ;; pacman) echo bind ;; *) echo bind-utils ;; esac ;;
    *:iproute2) case $PKG in dnf | yum) echo iproute ;; *) echo iproute2 ;; esac ;;
    *) echo "$n" ;;
  esac
}

pkg_refresh() {
  case $PKG in
    apt) run env DEBIAN_FRONTEND=noninteractive apt-get update -y ;;
    dnf) run dnf makecache -y ;;
    yum) run yum makecache -y ;;
    pacman) run pacman -Sy --noconfirm ;;
    apk) run apk update ;;
    zypper) run zypper --non-interactive refresh ;;
    *) return 1 ;;
  esac
}

pkg_install() { # pkg_install name...
  local -a list=() n
  for n in "$@"; do list+=("$(pkg_name "$n")"); done
  case $PKG in
    apt) run env DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "${list[@]}" ;;
    dnf) run dnf install -y "${list[@]}" ;;
    yum) run yum install -y "${list[@]}" ;;
    pacman) run pacman -S --noconfirm --needed "${list[@]}" ;;
    apk) run apk add --no-cache "${list[@]}" ;;
    zypper) run zypper --non-interactive install "${list[@]}" ;;
    *) ui_err "No supported package manager found"; return 1 ;;
  esac
}

pkg_upgrade() {
  case $PKG in
    apt) run env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold && run apt-get autoremove -y ;;
    dnf) run dnf upgrade -y ;;
    yum) run yum update -y ;;
    pacman) run pacman -Syu --noconfirm ;;
    apk) run apk upgrade ;;
    zypper) run zypper --non-interactive update ;;
  esac
}

ensure_base_packages() {
  local -a need=()
  has curl || need+=(curl)
  has wget || need+=(wget)
  has tar || need+=(tar)
  has openssl || need+=(openssl)
  has ss || need+=(iproute2)
  has socat || need+=(socat)
  has crontab || need+=(cron)
  (( ${#need[@]} == 0 )) && return 0
  pkg_refresh; pkg_install "${need[@]}"
}

ensure_docker() {
  if has docker && docker compose version >/dev/null 2>&1; then return 0; fi
  local s; s=$(fetch_script https://get.docker.com) || return 1
  run sh "$s" && { [[ "$HAS_SYSTEMD" == 1 ]] && run systemctl enable --now docker; true; }
}

svc_restart() { [[ "$HAS_SYSTEMD" == 1 ]] && run systemctl restart "$1"; }

# --------------------------------------------------------------- panels ---
# Detect panels that are already installed on this machine.
detect_installed_panels() {
  INSTALLED_PANELS=()
  [[ -x /usr/local/x-ui/x-ui ]] && INSTALLED_PANELS+=("x-ui family (/usr/local/x-ui)")
  [[ -d /usr/local/s-ui ]] && INSTALLED_PANELS+=("s-ui")
  [[ -d /opt/marzban ]] && INSTALLED_PANELS+=("Marzban")
  [[ -d /opt/pasarguard ]] && INSTALLED_PANELS+=("PasarGuard")
  [[ -d /etc/opt/marzneshin || -d /opt/marzneshin ]] && INSTALLED_PANELS+=("Marzneshin")
  [[ -d /opt/hiddify-manager ]] && INSTALLED_PANELS+=("Hiddify Manager")
  [[ -d /opt/remnawave ]] && INSTALLED_PANELS+=("Remnawave")
  [[ -d /usr/local/h-ui ]] && INSTALLED_PANELS+=("H-UI")
  [[ -d /opt/Npanel ]] && INSTALLED_PANELS+=("Npanel")
  [[ -x /usr/local/bin/xray && ! -d /usr/local/x-ui ]] && INSTALLED_PANELS+=("Xray-core (standalone)")
  return 0
}
