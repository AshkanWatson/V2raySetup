#!/usr/bin/env bash
# ui.sh — terminal UI helpers (colors, boxes, menus, prompts, spinner).
# Style is inspired by Claude Code / OpenCode: rounded boxes, ● bullets,
# ❯ pointer, ⎿ sub-results, arrow-key menus and a calm color palette.

# ---------------------------------------------------------------- colors ---
ui_colors() {
  if [[ -n "${NO_COLOR:-}" || "${V2S_NO_COLOR:-0}" == 1 || ! -t 1 ]]; then
    C_RESET='' C_BOLD='' C_DIM='' C_ITAL='' C_ACCENT='' C_OK='' C_WARN='' C_ERR='' C_INFO='' C_MUTED='' C_INV=''
    return
  fi
  local n; n=$(tput colors 2>/dev/null || echo 8)
  C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m' C_ITAL=$'\033[3m' C_INV=$'\033[7m'
  if (( n >= 256 )); then
    C_ACCENT=$'\033[38;5;173m'  # warm orange (Claude-like)
    C_OK=$'\033[38;5;114m'
    C_WARN=$'\033[38;5;221m'
    C_ERR=$'\033[38;5;203m'
    C_INFO=$'\033[38;5;110m'
    C_MUTED=$'\033[38;5;245m'
  else
    C_ACCENT=$'\033[33m' C_OK=$'\033[32m' C_WARN=$'\033[33m' C_ERR=$'\033[31m' C_INFO=$'\033[36m' C_MUTED=$'\033[90m'
  fi
}

# ------------------------------------------------------------- tty setup ---
# UI_INTERACTIVE=1 when we can draw menus and read keys from a terminal.
# Input is read from /dev/tty so the app also works via `curl ... | bash`.
ui_init() {
  # Box drawing needs character (not byte) lengths → make sure we run in UTF-8.
  if [[ "$(locale charmap 2>/dev/null)" != UTF-8 ]]; then
    local l; l=$(locale -a 2>/dev/null | grep -iE '^(c|en_us)\.utf-?8$' | head -n1)
    [[ -n "$l" ]] && export LC_ALL=$l
  fi
  ui_colors
  UI_INTERACTIVE=0
  UI_IN=/dev/stdin
  if [[ "${V2S_NONINTERACTIVE:-0}" != 1 ]]; then
    if [[ -t 0 && -t 1 ]]; then
      UI_INTERACTIVE=1; UI_IN=/dev/stdin
    elif [[ -t 1 ]] && { : </dev/tty; } 2>/dev/null; then
      UI_INTERACTIVE=1; UI_IN=/dev/tty
    fi
  fi
  UI_COLS=$(tput cols 2>/dev/null || echo 80)
  [[ "$UI_COLS" =~ ^[0-9]+$ ]] || UI_COLS=80
  (( UI_COLS > 100 )) && UI_COLS=100
  (( UI_COLS < 40 )) && UI_COLS=40
  trap 'ui_cursor_show' EXIT
}

ui_cursor_hide() { [[ "$UI_INTERACTIVE" == 1 ]] && printf '\033[?25l'; }
ui_cursor_show() { [[ "${UI_INTERACTIVE:-0}" == 1 ]] && printf '\033[?25h'; return 0; }

# strip ANSI codes to measure visible length
ui_strip() { sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g' <<<"$1"; }
# visible width: count UTF-8 characters by dropping continuation bytes (locale independent)
ui_len() { ui_strip "$1" | LC_ALL=C tr -d '\200-\277\n' | LC_ALL=C wc -c | tr -d ' '; }
ui_repeat() { local i out=''; for ((i = 0; i < $2; i++)); do out+="$1"; done; printf '%s' "$out"; }
# truncate visible text (no ANSI inside) to n chars
ui_trunc() { local s="$1" n="$2"; if (( ${#s} > n )); then printf '%s…' "${s:0:n-1}"; else printf '%s' "$s"; fi; }

# ---------------------------------------------------------------- output ---
ui_line()  { printf '%s\n' "$*"; }
ui_blank() { printf '\n'; }
ui_step()  { printf '%s●%s %s%s%s\n' "$C_ACCENT" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
ui_ok()    { printf '%s✔%s %s\n' "$C_OK" "$C_RESET" "$*"; }
ui_warn()  { printf '%s▲%s %s\n' "$C_WARN" "$C_RESET" "$*"; }
ui_err()   { printf '%s✖%s %s\n' "$C_ERR" "$C_RESET" "$*" >&2; }
ui_info()  { printf '%s›%s %s\n' "$C_INFO" "$C_RESET" "$*"; }
ui_dim()   { printf '%s%s%s\n' "$C_MUTED" "$*" "$C_RESET"; }
ui_sub()   { printf '  %s⎿%s  %s\n' "$C_MUTED" "$C_RESET" "$*"; }
ui_kv()    { printf '  %s%-16s%s %s\n' "$C_MUTED" "$1" "$C_RESET" "$2"; }

# ui_box "Title" line1 line2 ...   — rounded box, Claude Code style
ui_box() {
  local title="$1"; shift
  local w=$((UI_COLS - 2)) line vis pad
  local tl="╭─ ${title} " ; local tlen; tlen=$(ui_len "$tl")
  printf '%s%s%s%s╮%s\n' "$C_ACCENT" "$tl" "$(ui_repeat "─" $((w - tlen + 1)))" "" "$C_RESET"
  for line in "$@"; do
    vis=$(ui_len "$line")
    if (( vis > w - 2 )); then line=$(ui_trunc "$(ui_strip "$line")" $((w - 2))); vis=$((w - 2)); fi
    pad=$((w - 2 - vis))
    printf '%s│%s %s%s %s│%s\n' "$C_ACCENT" "$C_RESET" "$line" "$(ui_repeat ' ' "$pad")" "$C_ACCENT" "$C_RESET"
  done
  printf '%s╰%s╯%s\n' "$C_ACCENT" "$(ui_repeat '─' "$w")" "$C_RESET"
}

ui_rule() { printf '%s%s%s\n' "$C_MUTED" "$(ui_repeat '─' "$UI_COLS")" "$C_RESET"; }

ui_banner() {
  ui_blank
  ui_box "${C_BOLD}✻ V2raySetup${C_RESET}${C_ACCENT} v${V2S_VERSION}" \
    "${C_BOLD}Welcome!${C_RESET} Install a V2Ray/Xray panel on this server in a few steps." \
    "" \
    "${C_MUTED}↑/↓ move · enter select · space toggle · q quit${C_RESET}" \
    "${C_MUTED}Logs: ${V2S_LOG}${C_RESET}"
  [[ "${DRY_RUN:-0}" == 1 ]] && ui_warn "Dry-run mode: nothing will be changed, commands are only printed."
  ui_blank
}

# ------------------------------------------------------------ key reader ---
# prints one of: up down enter space quit esc num:<n> char:<c>
ui_readkey() {
  local k rest
  IFS= read -rsn1 k <"$UI_IN" || { echo quit; return; }
  case "$k" in
    $'\e')
      IFS= read -rsn2 -t 0.05 rest <"$UI_IN" || true
      case "$rest" in
        '[A' | 'OA') echo up ;;
        '[B' | 'OB') echo down ;;
        '') echo esc ;;
        *) echo other ;;
      esac ;;
    '') echo enter ;;
    ' ') echo space ;;
    k | K) echo up ;;
    j | J) echo down ;;
    q | Q) echo quit ;;
    [0-9]) echo "num:$k" ;;
    *) echo "char:$k" ;;
  esac
}

ui_abort() {
  ui_cursor_show
  printf '\n%s  Cancelled. Nothing else was changed.%s\n' "$C_MUTED" "$C_RESET"
  exit 130
}

# Answer override: V2S_ANSWER_<KEY> lets scripts/tests answer any question.
ui_preset() {
  local key="$1" var="V2S_ANSWER_${1^^}"
  var=${var//[^A-Z0-9_]/_}
  [[ -n "$key" && -n "${!var+x}" ]] && { printf '%s' "${!var}"; return 0; }
  return 1
}

# ---------------------------------------------------------------- select ---
# ui_select KEY "Question" DEFAULT_IDX "label|hint" ...
#   result: UI_INDEX (0-based) and UI_VALUE (label)
# Optional: UI_DETAIL_FN=<function idx> prints a details panel for the
# highlighted item (UI_DETAIL_LINES lines, padded).
ui_select() {
  local key="$1" q="$2" def="${3:-0}"; shift 3
  local -a items=("$@"); local n=${#items[@]} i
  local preset
  if preset=$(ui_preset "$key"); then
    for i in "${!items[@]}"; do
      local lbl=${items[$i]%%|*}
      if [[ "$preset" == "$i" || "${lbl,,}" == "${preset,,}" || "${lbl,,}" == "${preset,,} "* ]]; then
        UI_INDEX=$i; UI_VALUE=$lbl
        printf '%s?%s %s %s%s%s\n' "$C_ACCENT" "$C_RESET" "$q" "$C_OK" "$lbl" "$C_RESET"
        return 0
      fi
    done
  fi
  if [[ "$UI_INTERACTIVE" != 1 ]]; then
    printf '%s?%s %s%s%s\n' "$C_ACCENT" "$C_RESET" "$C_BOLD" "$q" "$C_RESET"
    for i in "${!items[@]}"; do
      printf '  %2d) %s %s%s%s\n' $((i + 1)) "${items[$i]%%|*}" "$C_MUTED" "$( [[ ${items[$i]} == *'|'* ]] && echo "${items[$i]#*|}")" "$C_RESET"
    done
    local ans
    while true; do
      printf '  Choose [1-%d] (default %d): ' "$n" $((def + 1))
      IFS= read -r ans <"$UI_IN" || ans=''
      [[ -z "$ans" ]] && ans=$((def + 1))
      if [[ "$ans" =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= n )); then break; fi
      printf '  %sPlease enter a number between 1 and %d%s\n' "$C_WARN" "$n" "$C_RESET"
    done
    UI_INDEX=$((ans - 1)); UI_VALUE=${items[$UI_INDEX]%%|*}
    return 0
  fi

  local cur=$def drawn=0 action lw=0 lbl hint detail_lines=${UI_DETAIL_LINES:-0}
  for i in "${!items[@]}"; do lbl=${items[$i]%%|*}; (( ${#lbl} > lw )) && lw=${#lbl}; done
  printf '%s?%s %s%s%s\n' "$C_ACCENT" "$C_RESET" "$C_BOLD" "$q" "$C_RESET"
  ui_cursor_hide
  while true; do
    (( drawn > 0 )) && printf '\033[%dA' "$drawn"
    drawn=0
    for i in "${!items[@]}"; do
      lbl=${items[$i]%%|*}; hint=''
      [[ ${items[$i]} == *'|'* ]] && hint=${items[$i]#*|}
      local room=$((UI_COLS - lw - 10)); (( room < 0 )) && room=0
      hint=$(ui_trunc "$hint" "$room")
      if (( i == cur )); then
        printf '\033[2K%s❯ %2d. %-*s%s  %s%s%s\n' "$C_ACCENT" $((i + 1)) "$lw" "$lbl" "$C_RESET" "$C_INFO" "$hint" "$C_RESET"
      else
        printf '\033[2K    %2d. %-*s  %s%s%s\n' $((i + 1)) "$lw" "$lbl" "$C_MUTED" "$hint" "$C_RESET"
      fi
      drawn=$((drawn + 1))
    done
    if [[ -n "${UI_DETAIL_FN:-}" ]] && (( detail_lines > 0 )); then
      local out; out=$("$UI_DETAIL_FN" "$cur" 2>/dev/null)
      local -a dl=(); mapfile -t dl <<<"$out"
      for ((i = 0; i < detail_lines; i++)); do
        printf '\033[2K%s\n' "${dl[$i]:-}"
        drawn=$((drawn + 1))
      done
    fi
    printf '\033[2K%s  ↑/↓ move · enter select · 1-9 jump · q quit%s\n' "$C_MUTED" "$C_RESET"
    drawn=$((drawn + 1))
    action=$(ui_readkey)
    case "$action" in
      up) cur=$(((cur - 1 + n) % n)) ;;
      down) cur=$(((cur + 1) % n)) ;;
      num:*) local d=${action#num:}; (( d >= 1 && d <= n )) && cur=$((d - 1)) ;;
      enter) break ;;
      quit | esc) ui_abort ;;
    esac
  done
  # collapse menu into a one-line answer
  printf '\033[%dA' "$drawn"
  for ((i = 0; i < drawn; i++)); do printf '\033[2K\n'; done
  printf '\033[%dA' "$((drawn + 1))"
  printf '\033[2K%s?%s %s %s%s%s\n' "$C_ACCENT" "$C_RESET" "$q" "$C_OK" "${items[$cur]%%|*}" "$C_RESET"
  ui_cursor_show
  UI_INDEX=$cur; UI_VALUE=${items[$cur]%%|*}
}

# ---------------------------------------------------------- multiselect ---
# ui_multiselect KEY "Question" "label|hint|on" ...
#   result: UI_SELECTED array of 0/1 per item
ui_multiselect() {
  local key="$1" q="$2"; shift 2
  local -a items=("$@") state=(); local n=${#items[@]} i
  for i in "${!items[@]}"; do
    local f3; IFS='|' read -r _ _ f3 <<<"${items[$i]}"
    [[ "$f3" == on ]] && state[i]=1 || state[i]=0
  done
  local preset
  if preset=$(ui_preset "$key"); then
    # preset: comma list of 1-based indexes, "none" or "default"
    if [[ "$preset" != default ]]; then
      for i in "${!items[@]}"; do state[i]=0; done
      local p; IFS=',' read -ra p <<<"$preset"
      for i in "${p[@]}"; do [[ "$i" =~ ^[0-9]+$ ]] && (( i >= 1 && i <= n )) && state[i - 1]=1; done
    fi
    UI_SELECTED=("${state[@]}")
    printf '%s?%s %s\n' "$C_ACCENT" "$C_RESET" "$q"
    for i in "${!items[@]}"; do [[ ${state[i]} == 1 ]] && ui_sub "${items[$i]%%|*}"; done
    return 0
  fi
  if [[ "$UI_INTERACTIVE" != 1 ]]; then
    printf '%s?%s %s%s%s\n' "$C_ACCENT" "$C_RESET" "$C_BOLD" "$q" "$C_RESET"
    for i in "${!items[@]}"; do
      local lbl hint; IFS='|' read -r lbl hint _ <<<"${items[$i]}"
      printf '  %2d) [%s] %s %s%s%s\n' $((i + 1)) "$([[ ${state[i]} == 1 ]] && echo x || echo ' ')" "$lbl" "$C_MUTED" "$hint" "$C_RESET"
    done
    local ans
    printf '  Enter numbers to select, e.g. 1,3 (enter = keep defaults, 0 = none): '
    IFS= read -r ans <"$UI_IN" || ans=''
    if [[ "$ans" == 0 ]]; then
      for i in "${!items[@]}"; do state[i]=0; done
    elif [[ -n "$ans" ]]; then
      for i in "${!items[@]}"; do state[i]=0; done
      local p; IFS=', ' read -ra p <<<"$ans"
      for i in "${p[@]}"; do [[ "$i" =~ ^[0-9]+$ ]] && (( i >= 1 && i <= n )) && state[i - 1]=1; done
    fi
    UI_SELECTED=("${state[@]}")
    return 0
  fi

  local cur=0 drawn=0 action lw=0
  for i in "${!items[@]}"; do local l=${items[$i]%%|*}; (( ${#l} > lw )) && lw=${#l}; done
  printf '%s?%s %s%s%s\n' "$C_ACCENT" "$C_RESET" "$C_BOLD" "$q" "$C_RESET"
  ui_cursor_hide
  while true; do
    (( drawn > 0 )) && printf '\033[%dA' "$drawn"
    drawn=0
    for i in "${!items[@]}"; do
      local lbl hint box ptr col
      IFS='|' read -r lbl hint _ <<<"${items[$i]}"
      local room=$((UI_COLS - lw - 12)); (( room < 0 )) && room=0
      hint=$(ui_trunc "$hint" "$room")
      if [[ ${state[i]} == 1 ]]; then box="${C_OK}◉${C_RESET}"; else box="${C_MUTED}○${C_RESET}"; fi
      if (( i == cur )); then ptr="${C_ACCENT}❯${C_RESET}"; col=$C_ACCENT; else ptr=' '; col=''; fi
      printf '\033[2K%s %s %s%-*s%s  %s%s%s\n' "$ptr" "$box" "$col" "$lw" "$lbl" "$C_RESET" "$C_MUTED" "$hint" "$C_RESET"
      drawn=$((drawn + 1))
    done
    printf '\033[2K%s  ↑/↓ move · space toggle · a all · n none · enter confirm%s\n' "$C_MUTED" "$C_RESET"
    drawn=$((drawn + 1))
    action=$(ui_readkey)
    case "$action" in
      up) cur=$(((cur - 1 + n) % n)) ;;
      down) cur=$(((cur + 1) % n)) ;;
      space) state[cur]=$((1 - state[cur])) ;;
      num:*) local d=${action#num:}; (( d >= 1 && d <= n )) && { cur=$((d - 1)); state[cur]=$((1 - state[cur])); } ;;
      char:a | char:A) for i in "${!items[@]}"; do state[i]=1; done ;;
      char:n | char:N) for i in "${!items[@]}"; do state[i]=0; done ;;
      enter) break ;;
      quit | esc) ui_abort ;;
    esac
  done
  printf '\033[%dA' "$drawn"
  for ((i = 0; i < drawn; i++)); do printf '\033[2K\n'; done
  printf '\033[%dA' "$((drawn + 1))"
  printf '\033[2K%s?%s %s\n' "$C_ACCENT" "$C_RESET" "$q"
  local any=0
  for i in "${!items[@]}"; do [[ ${state[i]} == 1 ]] && { ui_sub "${items[$i]%%|*}"; any=1; }; done
  [[ $any == 0 ]] && ui_sub "${C_MUTED}(none)${C_RESET}"
  ui_cursor_show
  UI_SELECTED=("${state[@]}")
}

# ----------------------------------------------------------------- input ---
# ui_input KEY "Question" "default" [validator_fn] [hint]
#   result: UI_VALUE
ui_input() {
  local key="$1" q="$2" def="${3:-}" validator="${4:-}" hint="${5:-}" ans preset
  if preset=$(ui_preset "$key"); then
    UI_VALUE=$preset
    if [[ -n "$validator" ]] && ! "$validator" "$UI_VALUE"; then
      ui_err "Preset answer for '$key' is invalid: $UI_VALUE"; exit 2
    fi
    printf '%s?%s %s %s%s%s\n' "$C_ACCENT" "$C_RESET" "$q" "$C_OK" "${UI_VALUE:-(empty)}" "$C_RESET"
    return 0
  fi
  while true; do
    printf '%s?%s %s%s%s' "$C_ACCENT" "$C_RESET" "$C_BOLD" "$q" "$C_RESET"
    [[ -n "$def" ]] && printf ' %s(%s)%s' "$C_MUTED" "$def" "$C_RESET"
    [[ -n "$hint" ]] && printf '\n  %s%s%s' "$C_MUTED" "$hint" "$C_RESET"
    printf '\n  %s❯%s ' "$C_ACCENT" "$C_RESET"
    IFS= read -r ans <"$UI_IN" || ans=''
    ans=${ans#"${ans%%[![:space:]]*}"}; ans=${ans%"${ans##*[![:space:]]}"}
    [[ -z "$ans" ]] && ans=$def
    if [[ -n "$validator" ]] && ! "$validator" "$ans"; then
      printf '  %s✖ %s%s\n' "$C_ERR" "${UI_VALIDATION_MSG:-Invalid value, try again.}" "$C_RESET"
      [[ "$UI_INTERACTIVE" != 1 && "${V2S_NONINTERACTIVE:-0}" == 1 ]] && exit 2
      continue
    fi
    break
  done
  UI_VALUE=$ans
}

# ui_confirm KEY "Question" y|n   → returns 0 for yes
ui_confirm() {
  local key="$1" q="$2" def="${3:-y}" ans preset
  if preset=$(ui_preset "$key"); then ans=$preset
  elif [[ "${ASSUME_YES:-0}" == 1 ]]; then ans=$def
  elif [[ "$UI_INTERACTIVE" == 1 ]]; then
    printf '%s?%s %s%s%s %s(%s)%s ' "$C_ACCENT" "$C_RESET" "$C_BOLD" "$q" "$C_RESET" "$C_MUTED" "$([[ $def == y ]] && echo 'Y/n' || echo 'y/N')" "$C_RESET"
    local k
    while true; do
      IFS= read -rsn1 k <"$UI_IN" || k=''
      case "$k" in
        y | Y) ans=y; break ;;
        n | N) ans=n; break ;;
        '') ans=$def; break ;;
        q | Q | $'\e') printf '\n'; ui_abort ;;
      esac
    done
    printf '%s%s%s\n' "$C_OK" "$([[ $ans == y ]] && echo Yes || echo No)" "$C_RESET"
    [[ $ans == y ]]; return
  else
    printf '%s?%s %s (%s): ' "$C_ACCENT" "$C_RESET" "$q" "$([[ $def == y ]] && echo 'Y/n' || echo 'y/N')"
    IFS= read -r ans <"$UI_IN" || ans=''
    [[ -z "$ans" ]] && ans=$def
  fi
  ans=${ans,,}
  [[ "$ans" == y* || "$ans" == 1 || "$ans" == true ]] && { [[ -n "$preset" || "${ASSUME_YES:-0}" == 1 ]] && printf '%s?%s %s %sYes%s\n' "$C_ACCENT" "$C_RESET" "$q" "$C_OK" "$C_RESET"; return 0; }
  [[ -n "$preset" || "${ASSUME_YES:-0}" == 1 ]] && printf '%s?%s %s %sNo%s\n' "$C_ACCENT" "$C_RESET" "$q" "$C_OK" "$C_RESET"
  return 1
}

# --------------------------------------------------------------- spinner ---
# ui_spin "message" cmd args...  — runs a command, logs output, shows spinner.
# On failure prints the tail of the log. Returns the command's exit code.
ui_spin() {
  local msg="$1"; shift
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    ui_ok "$msg"
    printf '  %s⎿  $ %s%s\n' "$C_MUTED" "$*" "$C_RESET"
    return 0
  fi
  local start=$SECONDS rc
  printf '\n==== [%s] %s\n$ %s\n' "$(date '+%F %T')" "$msg" "$*" >>"$V2S_LOG"
  if [[ ! -t 1 ]]; then
    printf '%s…%s %s\n' "$C_MUTED" "$C_RESET" "$msg"
    "$@" >>"$V2S_LOG" 2>&1 </dev/null; rc=$?
  else
    "$@" >>"$V2S_LOG" 2>&1 </dev/null &
    local pid=$! frames=('·' '✢' '✳' '✶' '✻' '✽' '✻' '✶' '✳' '✢') f=0
    ui_cursor_hide
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r\033[2K%s%s%s %s %s(%ds · logs: %s)%s' "$C_ACCENT" "${frames[f]}" "$C_RESET" "$msg" "$C_MUTED" $((SECONDS - start)) "$V2S_LOG" "$C_RESET"
      f=$(((f + 1) % ${#frames[@]}))
      sleep 0.12
    done
    wait "$pid"; rc=$?
    printf '\r\033[2K'
    ui_cursor_show
  fi
  if (( rc == 0 )); then
    printf '%s✔%s %s %s(%ds)%s\n' "$C_OK" "$C_RESET" "$msg" "$C_MUTED" $((SECONDS - start)) "$C_RESET"
  else
    printf '%s✖%s %s %s(exit %d)%s\n' "$C_ERR" "$C_RESET" "$msg" "$C_MUTED" "$rc" "$C_RESET"
    tail -n 12 "$V2S_LOG" | sed "s/^/  ${C_MUTED}│${C_RESET} /"
  fi
  return "$rc"
}
