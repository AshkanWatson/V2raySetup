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