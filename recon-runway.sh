#!/usr/bin/env bash
# recon-runway (rr) - Reconnaissance environment setup tool
# Platform: macOS/Linux
# Dependencies: bash, curl, stat, date, wc, git, anew

set -euo pipefail

#######################################
# 全局配置变量 - 可在此处直接修改
#######################################
RR_CONFIG_FILE="${HOME}/.rrc"

# 路径配置
BASE="${BASE:-${HOME}/security}"
RESOLVERS_PATH="${RESOLVERS_PATH:-${BASE}/resolvers}"
WORDLISTS_PATH="${WORDLISTS_PATH:-${BASE}/wordlists}"
RESOLVERS_FILE="${RESOLVERS_FILE:-${RESOLVERS_PATH}/resolvers.txt}"
RESOLVERS_TRUSTED_FILE="${RESOLVERS_TRUSTED_FILE:-${RESOLVERS_PATH}/resolvers-trusted.txt}"

# 字典文件配置
# 全量字典文件：合并所有可用源
SUBDOMAINS_FULL="${SUBDOMAINS_FULL:-${WORDLISTS_PATH}/subdomains-full.txt}"
# 快速字典文件：使用 SecLists 5000 条
SUBDOMAINS_FAST="${SUBDOMAINS_FAST:-${WORDLISTS_PATH}/SecLists/Discovery/DNS/subdomains-top1million-5000.txt}"
# 常规字典文件：使用 SecLists 110000 条
SUBDOMAINS="${SUBDOMAINS:-${WORDLISTS_PATH}/SecLists/Discovery/DNS/subdomains-top1million-110000.txt}"

# URL 配置
URL_SECLISTS_REPO="https://github.com/danielmiessler/SecLists.git"
URL_ASSETNOTE_WORDLIST="https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt"
URL_RESOLVERS_PUBLIC="https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt"
URL_RESOLVERS_TRUSTED="https://raw.githubusercontent.com/trickest/resolvers/main/resolvers-trusted.txt"
URL_ANEW_REPO="https://github.com/tomnomnom/anew"

#######################################
# 输出系统
#######################################

# 检测是否支持颜色
supports_color() {
  [ -t 1 ] && [ "${TERM:-}" != "dumb" ]
}

# 颜色定义
if supports_color; then
  COLOR_RESET="\033[0m"
  COLOR_BOLD="\033[1m"
  COLOR_DIM="\033[2m"
  COLOR_GREEN="\033[32m"
  COLOR_RED="\033[31m"
  COLOR_YELLOW="\033[33m"
  COLOR_BLUE="\033[34m"
  COLOR_CYAN="\033[36m"
  COLOR_GRAY="\033[90m"
  COLOR_BG_GREEN="\033[42m"
  COLOR_BG_RED="\033[41m"
  COLOR_BG_YELLOW="\033[43m"
else
  COLOR_RESET=""
  COLOR_BOLD=""
  COLOR_DIM=""
  COLOR_GREEN=""
  COLOR_RED=""
  COLOR_YELLOW=""
  COLOR_BLUE=""
  COLOR_CYAN=""
  COLOR_GRAY=""
  COLOR_BG_GREEN=""
  COLOR_BG_RED=""
  COLOR_BG_YELLOW=""
fi

# 基础输出函数
log() {
  printf "${COLOR_GRAY}[%s]${COLOR_RESET} %s\n" "$(date '+%H:%M:%S')" "$*"
}

info() {
  printf "${COLOR_CYAN}[INFO]${COLOR_RESET} %s\n" "$*"
}

success() {
  printf "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} %s\n" "$*"
}

warn() {
  >&2 printf "${COLOR_YELLOW}[WARNING]${COLOR_RESET} %s\n" "$*"
}

error() {
  >&2 printf "${COLOR_RED}[ERROR]${COLOR_RESET} %s\n" "$*"
}

die() {
  error "$*"
  exit 1
}

# 打印检测项（简化版）
print_check() {
  local status="$1"
  local label="$2"
  shift 2
  local detail="$*"
  
  case "$status" in
    OK|ok)
      printf "${COLOR_GREEN}[OK]${COLOR_RESET} ${COLOR_BOLD}%s${COLOR_RESET}" "$label"
      [ -n "$detail" ] && printf " ${COLOR_DIM}%s${COLOR_RESET}" "$detail"
      printf '\n'
      ;;
    FAIL|fail)
      printf "${COLOR_RED}[FAIL]${COLOR_RESET} ${COLOR_BOLD}%s${COLOR_RESET}" "$label"
      [ -n "$detail" ] && printf " ${COLOR_DIM}%s${COLOR_RESET}" "$detail"
      printf '\n'
      ;;
    MISS|miss)
      printf "${COLOR_YELLOW}[MISS]${COLOR_RESET} ${COLOR_BOLD}%s${COLOR_RESET}" "$label"
      [ -n "$detail" ] && printf " ${COLOR_DIM}%s${COLOR_RESET}" "$detail"
      printf '\n'
      ;;
    STALE|stale)
      printf "${COLOR_YELLOW}[STALE]${COLOR_RESET} ${COLOR_BOLD}%s${COLOR_RESET}" "$label"
      [ -n "$detail" ] && printf " ${COLOR_DIM}%s${COLOR_RESET}" "$detail"
      printf '\n'
      ;;
    UPDATED|updated)
      printf "${COLOR_GREEN}[UPDATED]${COLOR_RESET} ${COLOR_BOLD}%s${COLOR_RESET}" "$label"
      [ -n "$detail" ] && printf " ${COLOR_DIM}%s${COLOR_RESET}" "$detail"
      printf '\n'
      ;;
    *)
      printf "${COLOR_GRAY}[UNKNOWN]${COLOR_RESET} ${COLOR_BOLD}%s${COLOR_RESET}" "$label"
      [ -n "$detail" ] && printf " ${COLOR_DIM}%s${COLOR_RESET}" "$detail"
      printf '\n'
      ;;
  esac
}

# 打印详细信息（缩进）
print_detail() {
  printf "     ${COLOR_DIM}%s${COLOR_RESET}\n" "$*"
}


usage() {
  cat <<'EOF'
用法: rr [选项]

  无参数                          执行网络、资源、代理及配置检测（默认行为）
  -check                         执行网络、资源、代理及配置检测
  -download-wordlists [path]     下载字典文件，可指定路径（文件或目录）
  -download-resolvers [path]     下载解析器文件，可指定目录
  -s, --silent                   静默模式，仅输出 source 命令（便于管道调用）
  -h, --help                     查看帮助

示例:
  rr                              执行检测（默认）
  rr -check                       执行检测
  rr -s                           静默模式，仅输出 source 命令
  rr -download-wordlists /tmp/wordlists
  rr -download-resolvers
EOF
}

ensure_directories() {
  mkdir -p "$RESOLVERS_PATH" "$WORDLISTS_PATH"
}

#######################################
# 配置文件处理
#######################################
write_config() {
  cat >"$RR_CONFIG_FILE" <<EOF
BASE="${BASE}"
export RESOLVERS="${RESOLVERS_FILE}"
export RESOLVERS_TRUSTED="${RESOLVERS_TRUSTED_FILE}"
export SUBDOMAINS_FULL="${SUBDOMAINS_FULL}"
export SUBDOMAINS_FAST="${SUBDOMAINS_FAST}"
export SUBDOMAINS="${SUBDOMAINS}"
EOF
}


#######################################
# 时间与文件工具
#######################################
file_exists_and_not_empty() {
  [ -s "$1" ]
}

file_mtime_epoch() {
  local file="$1"
  if [ ! -f "$file" ]; then
    printf '0'
    return
  fi
  if stat --version >/dev/null 2>&1; then
    stat -c %Y "$file"
  else
    stat -f %m "$file"
  fi
}

format_epoch() {
  local epoch="$1"
  if [ "$epoch" -eq 0 ]; then
    printf '未知'
    return
  fi
  if date -r "$epoch" '+%Y-%m-%d %H:%M:%S' >/dev/null 2>&1; then
    date -r "$epoch" '+%Y-%m-%d %H:%M:%S'
  else
    date -d "@$epoch" '+%Y-%m-%d %H:%M:%S'
  fi
}

file_mtime_date() {
  local file="$1"
  local mtime
  mtime=$(file_mtime_epoch "$file")
  if [ "$mtime" -eq 0 ]; then
    printf '未知'
    return
  fi
  if date -r "$mtime" '+%Y-%m-%d' >/dev/null 2>&1; then
    date -r "$mtime" '+%Y-%m-%d'
  else
    date -d "@$mtime" '+%Y-%m-%d'
  fi
}

file_age_days() {
  local file="$1"
  local now
  now=$(date +%s)
  local mtime
  mtime=$(file_mtime_epoch "$file")
  if [ "$mtime" -eq 0 ] || [ "$mtime" -gt "$now" ]; then
    printf '9999'
  else
    printf '%s\n' $(( (now - mtime) / 86400 ))
  fi
}

#######################################
# 网络连通性检测
#######################################
curl_available() {
  command -v curl >/dev/null 2>&1
}

check_connectivity() {
  local hosts=("baidu.com" "google.com")
  local protocol
  local all_ok=true
  local failed_hosts=""
  
  if curl_available; then
    protocol="https"
  else
    protocol=""
  fi

  for host in "${hosts[@]}"; do
    local connected=false
    if [ -n "$protocol" ]; then
      if curl -Is --max-time 5 "${protocol}://${host}" >/dev/null 2>&1; then
        connected=true
      fi
    else
      if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
        connected=true
      fi
    fi
    
    if [ "$connected" = false ]; then
      all_ok=false
      failed_hosts="${failed_hosts}${host} "
    fi
  done
  
  if [ "$all_ok" = true ]; then
    print_check "OK" "网络连通性检测" "正常"
  else
    print_check "FAIL" "网络连通性检测" "异常: ${failed_hosts}连接失败"
  fi
}

#######################################
# 字典与解析器下载
#######################################
git_available() {
  command -v git >/dev/null 2>&1
}

anew_available() {
  command -v anew >/dev/null 2>&1
}

wget_available() {
  command -v wget >/dev/null 2>&1
}

download_wordlists() {
  local target_path="${1:-}"
  local dest_dir

  if [ -z "$target_path" ]; then
    dest_dir="$WORDLISTS_PATH"
  elif [ -d "$target_path" ]; then
    dest_dir="$target_path"
  elif [[ "$target_path" == *.txt ]]; then
    dest_dir="$(dirname "$target_path")"
  else
    dest_dir="$target_path"
  fi

  mkdir -p "$dest_dir"
  WORDLISTS_PATH="$dest_dir"

  # 检查必需工具
  if ! git_available; then
    error "未检测到 git，请先安装 git"
    return 1
  fi

  if ! anew_available; then
    error "未检测到 anew，请先安装 anew (${URL_ANEW_REPO})"
    return 1
  fi

  # 设置路径
  local SECLISTS_PATH="${WORDLISTS_PATH}/SecLists"
  local ASSETNOTE_BEST="${WORDLISTS_PATH}/best-dns-wordlist.txt"
  
  # 更新字典文件路径
  SUBDOMAINS_FULL="${dest_dir%/}/subdomains-full.txt"
  SUBDOMAINS_FAST="${SECLISTS_PATH}/Discovery/DNS/subdomains-top1million-5000.txt"
  SUBDOMAINS="${SECLISTS_PATH}/Discovery/DNS/subdomains-top1million-110000.txt"

  # 更新/克隆 SecLists
  if [ -d "$SECLISTS_PATH/.git" ]; then
    if ! git -C "$SECLISTS_PATH" pull --ff-only >/dev/null 2>&1; then
      warn "SecLists 更新失败，使用现有版本"
    fi
  else
    if ! git clone --depth 1 "$URL_SECLISTS_REPO" "$SECLISTS_PATH" >/dev/null 2>&1; then
      error "SecLists 克隆失败"
      return 1
    fi
  fi

  # 下载 AssetNote best-dns-wordlist.txt
  if ! wget_available; then
    error "未检测到 wget，请先安装 wget"
    return 1
  fi
  
  if ! wget -q --show-progress -O "$ASSETNOTE_BEST" "$URL_ASSETNOTE_WORDLIST"; then
    error "AssetNote 字典下载失败"
    return 1
  fi

  # 准备字典文件路径
  local SECLISTS_N0KOVO="$SECLISTS_PATH/Discovery/DNS/n0kovo_subdomains.txt"
  local SECLISTS_TOP1M="$SECLISTS_PATH/Discovery/DNS/subdomains-top1million-110000.txt"

  # 生成全量字典文件：合并所有可用源并使用 anew 去重
  info "正在生成全量字典文件..."
  cat "$ASSETNOTE_BEST" "$SECLISTS_N0KOVO" "$SECLISTS_TOP1M" 2>/dev/null | anew "$SUBDOMAINS_FULL" >/dev/null

  if [ ! -s "$SUBDOMAINS_FULL" ]; then
    error "全量字典文件生成失败或结果为空"
    return 1
  fi

  # 验证快速字典文件是否存在
  if [ ! -f "$SUBDOMAINS_FAST" ]; then
    error "快速字典文件不存在: ${SUBDOMAINS_FAST}"
    return 1
  fi

  # 验证常规字典文件是否存在
  if [ ! -f "$SUBDOMAINS" ]; then
    error "常规字典文件不存在: ${SUBDOMAINS}"
    return 1
  fi

  write_config
  return 0
}

download_resolvers() {
  local target_path="${1:-}"
  local dest_dir

  if [ -z "$target_path" ]; then
    dest_dir="$RESOLVERS_PATH"
  elif [ -d "$target_path" ]; then
    dest_dir="$target_path"
  elif [[ "$target_path" == *.txt ]]; then
    dest_dir="$(dirname "$target_path")"
  else
    dest_dir="$target_path"
  fi

  mkdir -p "$dest_dir"
  RESOLVERS_PATH="$dest_dir"
  RESOLVERS_FILE="${dest_dir%/}/resolvers.txt"
  RESOLVERS_TRUSTED_FILE="${dest_dir%/}/resolvers-trusted.txt"

  if ! curl -fsSL "$URL_RESOLVERS_PUBLIC" -o "${RESOLVERS_FILE}.tmp"; then
    rm -f "${RESOLVERS_FILE}.tmp"
    error "公共解析器下载失败"
    return 1
  fi

  if ! curl -fsSL "$URL_RESOLVERS_TRUSTED" -o "${RESOLVERS_TRUSTED_FILE}.tmp"; then
    rm -f "${RESOLVERS_TRUSTED_FILE}.tmp"
    error "可信解析器下载失败"
    return 1
  fi

  mv "${RESOLVERS_FILE}.tmp" "$RESOLVERS_FILE"
  mv "${RESOLVERS_TRUSTED_FILE}.tmp" "$RESOLVERS_TRUSTED_FILE"

  write_config
  return 0
}

#######################################
# 资源健康检查
#######################################
ensure_wordlist_fresh() {
  local needs_update=false
  
  # 检查快速字典文件
  if ! file_exists_and_not_empty "$SUBDOMAINS_FAST"; then
    print_check "MISS" "快速字典文件" "SUBDOMAINS_FAST, 缺失"
    needs_update=true
  else
    local lines
    lines=$(wc -l <"$SUBDOMAINS_FAST" 2>/dev/null | tr -d ' ' || printf '0')
    local formatted_lines
    formatted_lines=$(printf "%'d" "$lines" 2>/dev/null || printf "%d" "$lines")
    local file_date
    file_date=$(file_mtime_date "$SUBDOMAINS_FAST")
    print_check "OK" "快速字典文件" "SUBDOMAINS_FAST, ${formatted_lines} 行, ${file_date}"
  fi

  # 检查常规字典文件
  if ! file_exists_and_not_empty "$SUBDOMAINS"; then
    print_check "MISS" "常规字典文件" "SUBDOMAINS, 缺失"
    needs_update=true
  else
    local lines
    lines=$(wc -l <"$SUBDOMAINS" 2>/dev/null | tr -d ' ' || printf '0')
    local formatted_lines
    formatted_lines=$(printf "%'d" "$lines" 2>/dev/null || printf "%d" "$lines")
    local file_date
    file_date=$(file_mtime_date "$SUBDOMAINS")
    print_check "OK" "常规字典文件" "SUBDOMAINS, ${formatted_lines} 行, ${file_date}"
  fi

  # 检查全量字典文件
  if ! file_exists_and_not_empty "$SUBDOMAINS_FULL"; then
    print_check "MISS" "全量字典文件" "SUBDOMAINS_FULL, 缺失"
    needs_update=true
  else
    local lines
    lines=$(wc -l <"$SUBDOMAINS_FULL" 2>/dev/null | tr -d ' ' || printf '0')
    local formatted_lines
    formatted_lines=$(printf "%'d" "$lines" 2>/dev/null || printf "%d" "$lines")
    local file_date
    file_date=$(file_mtime_date "$SUBDOMAINS_FULL")
    print_check "OK" "全量字典文件" "SUBDOMAINS_FULL, ${formatted_lines} 行, ${file_date}"
  fi

  if [ "$needs_update" = true ]; then
    info "正在自动更新..."
    if download_wordlists ""; then
      # 更新后重新检查
      if file_exists_and_not_empty "$SUBDOMAINS_FAST"; then
        local lines
        lines=$(wc -l <"$SUBDOMAINS_FAST" 2>/dev/null | tr -d ' ' || printf '0')
        local formatted_lines
        formatted_lines=$(printf "%'d" "$lines" 2>/dev/null || printf "%d" "$lines")
        local file_date
        file_date=$(file_mtime_date "$SUBDOMAINS_FAST")
        print_check "UPDATED" "快速字典文件" "SUBDOMAINS_FAST, ${formatted_lines} 行, ${file_date}"
      fi
      if file_exists_and_not_empty "$SUBDOMAINS"; then
        local lines
        lines=$(wc -l <"$SUBDOMAINS" 2>/dev/null | tr -d ' ' || printf '0')
        local formatted_lines
        formatted_lines=$(printf "%'d" "$lines" 2>/dev/null || printf "%d" "$lines")
        local file_date
        file_date=$(file_mtime_date "$SUBDOMAINS")
        print_check "UPDATED" "常规字典文件" "SUBDOMAINS, ${formatted_lines} 行, ${file_date}"
      fi
      if file_exists_and_not_empty "$SUBDOMAINS_FULL"; then
        local lines
        lines=$(wc -l <"$SUBDOMAINS_FULL" 2>/dev/null | tr -d ' ' || printf '0')
        local formatted_lines
        formatted_lines=$(printf "%'d" "$lines" 2>/dev/null || printf "%d" "$lines")
        local file_date
        file_date=$(file_mtime_date "$SUBDOMAINS_FULL")
        print_check "UPDATED" "全量字典文件" "SUBDOMAINS_FULL, ${formatted_lines} 行, ${file_date}"
      fi
    else
      warn "自动更新失败，请手动执行: rr -download-wordlists"
    fi
  fi
}

ensure_resolvers_fresh() {
  local needs_update=false
  local resolver_age=0
  local trusted_age=0
  
  # 检测公共解析器文件
  if ! file_exists_and_not_empty "$RESOLVERS_FILE"; then
    print_check "MISS" "解析器文件" "RESOLVERS, 缺失"
    needs_update=true
  else
    resolver_age=$(file_age_days "$RESOLVERS_FILE")
    if [ "$resolver_age" -ge 3 ]; then
      print_check "STALE" "解析器文件" "RESOLVERS, 已过期 ${resolver_age} 天"
      needs_update=true
    else
      local public_lines
      public_lines=$(wc -l <"$RESOLVERS_FILE" 2>/dev/null | tr -d ' ' || printf '0')
      local file_date
      file_date=$(file_mtime_date "$RESOLVERS_FILE")
      print_check "OK" "解析器文件" "RESOLVERS, ${public_lines} 行, ${file_date}"
    fi
  fi
  
  # 检测可信解析器文件
  if ! file_exists_and_not_empty "$RESOLVERS_TRUSTED_FILE"; then
    print_check "MISS" "信任解析器文件" "RESOLVERS_TRUSTED, 缺失"
    needs_update=true
  else
    trusted_age=$(file_age_days "$RESOLVERS_TRUSTED_FILE")
    if [ "$trusted_age" -ge 3 ]; then
      print_check "STALE" "信任解析器文件" "RESOLVERS_TRUSTED, 已过期 ${trusted_age} 天"
      needs_update=true
    else
      local trusted_lines
      trusted_lines=$(wc -l <"$RESOLVERS_TRUSTED_FILE" 2>/dev/null | tr -d ' ' || printf '0')
      local file_date
      file_date=$(file_mtime_date "$RESOLVERS_TRUSTED_FILE")
      print_check "OK" "信任解析器文件" "RESOLVERS_TRUSTED, ${trusted_lines} 行, ${file_date}"
    fi
  fi

  if [ "$needs_update" = true ]; then
    info "正在自动更新..."
    if download_resolvers ""; then
      local public_lines trusted_lines
      public_lines=$(wc -l <"$RESOLVERS_FILE" 2>/dev/null | tr -d ' ' || printf '0')
      trusted_lines=$(wc -l <"$RESOLVERS_TRUSTED_FILE" 2>/dev/null | tr -d ' ' || printf '0')
      local public_date trusted_date
      public_date=$(file_mtime_date "$RESOLVERS_FILE")
      trusted_date=$(file_mtime_date "$RESOLVERS_TRUSTED_FILE")
      print_check "UPDATED" "解析器文件" "RESOLVERS, ${public_lines} 行, ${public_date}"
      print_check "UPDATED" "信任解析器文件" "RESOLVERS_TRUSTED, ${trusted_lines} 行, ${trusted_date}"
    else
      warn "自动更新失败，请手动执行: rr -download-resolvers"
    fi
  fi
}

#######################################
# 代理检测
#######################################
check_proxy_status() {
  local http_proxy_var="${http_proxy:-${HTTP_PROXY:-}}"
  local https_proxy_var="${https_proxy:-${HTTPS_PROXY:-}}"
  local socks_proxy_var="${socks_proxy:-${SOCKS_PROXY:-${all_proxy:-${ALL_PROXY:-}}}}"
  local proxy_count=0
  local proxy_types=""

  if [ -n "$http_proxy_var" ]; then
    proxy_count=$((proxy_count + 1))
    proxy_types="${proxy_types}HTTP "
  fi

  if [ -n "$https_proxy_var" ]; then
    proxy_count=$((proxy_count + 1))
    proxy_types="${proxy_types}HTTPS "
  fi

  if [ -n "$socks_proxy_var" ]; then
    proxy_count=$((proxy_count + 1))
    proxy_types="${proxy_types}SOCKS "
  fi

  if [ "$proxy_count" -eq 0 ]; then
    print_check "FAIL" "代理检测" "未配置"
  else
    print_check "OK" "代理检测" "${proxy_count} 个 (${proxy_types})"
  fi
}

#######################################
# 检测流程
#######################################
run_checks() {
  local silent="${1:-false}"
  
  if [ "$silent" = "true" ]; then
    ensure_directories
    write_config
    printf "source ${HOME}/.rrc\n"
    return 0
  fi
  
  printf '\n'
  printf "${COLOR_BOLD}${COLOR_BLUE}═══════════════════════════════════════════════════════════${COLOR_RESET}\n"
  printf "${COLOR_BOLD}${COLOR_BLUE}  ${COLOR_BOLD}recon-runway (rr)${COLOR_RESET}\n"
  printf "${COLOR_BOLD}${COLOR_BLUE}═══════════════════════════════════════════════════════════${COLOR_RESET}\n"
  printf '\n'
  
  ensure_directories
  
  # 1. 网络连通性检测
  check_connectivity
  
  # 2. 代理检测
  check_proxy_status
  
  # 3. 字典文件检查（全量、快速、常规）
  ensure_wordlist_fresh
  
  # 4. 解析器文件检查
  ensure_resolvers_fresh
  
  # 自动生成配置文件
  write_config
  printf '\n'
  
  info "执行以下命令以应用变量到当前终端:"
  printf "${COLOR_GRAY}source ${HOME}/.rrc${COLOR_RESET}\n"
  printf '\n'

  info "如需设置目标，请执行:"
  printf "${COLOR_GRAY}TARGET=example.com${COLOR_RESET}\n"
  printf "${COLOR_GRAY}TARGETS=domains.txt${COLOR_RESET}\n"
}

#######################################
# 主逻辑
#######################################
main() {
  ensure_directories

  local check_flag=false
  local silent_flag=false
  local download_wordlists_flag=false
  local download_wordlists_path=""
  local download_resolvers_flag=false
  local download_resolvers_path=""

  # 如果没有参数，默认执行 -check
  if [ "$#" -eq 0 ]; then
    check_flag=true
  fi

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -check)
        check_flag=true
        ;;
      -download-wordlists)
        download_wordlists_flag=true
        if [ "$#" -gt 1 ] && [[ "$2" != -* ]]; then
          download_wordlists_path="$2"
          shift
        fi
        ;;
      -download-resolvers)
        download_resolvers_flag=true
        if [ "$#" -gt 1 ] && [[ "$2" != -* ]]; then
          download_resolvers_path="$2"
          shift
        fi
        ;;
      -s|--silent)
        silent_flag=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage
        exit 1
        ;;
    esac
    shift
  done

  # 如果没有指定任何操作（只有 -s 或其他标志），默认执行 -check
  if [ "$check_flag" = false ] && [ "$download_wordlists_flag" = false ] && [ "$download_resolvers_flag" = false ]; then
    check_flag=true
  fi

  if [ "$download_wordlists_flag" = true ]; then
    download_wordlists "$download_wordlists_path" || warn "字典下载失败，稍后可重试"
  fi

  if [ "$download_resolvers_flag" = true ]; then
    download_resolvers "$download_resolvers_path" || warn "解析器下载失败，稍后可重试"
  fi

  if [ "$download_wordlists_flag" = true ] || [ "$download_resolvers_flag" = true ]; then
    write_config
    # 如果未执行检测，则根据 silent 标志显示提示
    if [ "$check_flag" = false ]; then
      if [ "$silent_flag" = true ]; then
        printf "source ${HOME}/.rrc\n"
      else
        printf '\n'
        info "执行以下命令以应用变量到当前终端:"
        printf "${COLOR_GRAY}source ${HOME}/.rrc${COLOR_RESET}\n"
      fi
    fi
  fi

  if [ "$check_flag" = true ]; then
    run_checks "$silent_flag"
  fi
}

main "$@"