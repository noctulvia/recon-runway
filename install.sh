#!/usr/bin/env bash
# recon-runway (rr) 安装脚本
# 支持 macOS 和 Linux

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
REPO_URL="https://github.com/noctulvia/recon-runway"
SCRIPT_URL="${REPO_URL}/raw/main/recon-runway.sh"
INSTALL_DIR="/usr/local/bin"
INSTALL_NAME="rr"
TEMP_DIR=$(mktemp -d)

# 清理函数
cleanup() {
  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

# 检查是否为 root（安装到 /usr/local/bin 需要 sudo）
check_sudo() {
  if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}注意：安装到 ${INSTALL_DIR} 需要 sudo 权限${NC}"
    echo -e "${BLUE}请输入密码以继续...${NC}"
    sudo -v
  fi
}

# 检查依赖
check_dependencies() {
  local missing_deps=()
  
  for cmd in curl bash; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_deps+=("$cmd")
    fi
  done
  
  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo -e "${RED}错误：缺少以下依赖：${missing_deps[*]}${NC}"
    echo -e "${YELLOW}请先安装缺失的依赖后再运行安装脚本${NC}"
    exit 1
  fi
}

# 下载脚本
download_script() {
  echo -e "${BLUE}正在从 GitHub 下载 recon-runway.sh...${NC}"
  
  if ! curl -fsSL "$SCRIPT_URL" -o "${TEMP_DIR}/recon-runway.sh"; then
    echo -e "${RED}错误：下载脚本失败${NC}"
    echo -e "${YELLOW}请检查网络连接或稍后重试${NC}"
    exit 1
  fi
  
  # 设置执行权限
  chmod +x "${TEMP_DIR}/recon-runway.sh"
  
  echo -e "${GREEN}下载完成${NC}"
}

# 安装脚本
install_script() {
  local install_cmd=""
  local target="${INSTALL_DIR}/${INSTALL_NAME}"
  
  if [ "$EUID" -eq 0 ]; then
    install_cmd="install -m 0755"
  else
    install_cmd="sudo install -m 0755"
  fi
  
  echo -e "${BLUE}正在安装到 ${target}...${NC}"
  
  if $install_cmd "${TEMP_DIR}/recon-runway.sh" "$target"; then
    echo -e "${GREEN}安装成功！${NC}"
  else
    echo -e "${RED}错误：安装失败${NC}"
    exit 1
  fi
}

# 验证安装
verify_installation() {
  if command -v "$INSTALL_NAME" >/dev/null 2>&1; then
    echo -e "${GREEN}验证成功：${INSTALL_NAME} 已安装${NC}"
    
    # 显示安装的版本号
    local installed_version
    if installed_version=$("$INSTALL_NAME" --version 2>/dev/null); then
      echo -e "${BLUE}已安装版本：${GREEN}${installed_version}${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}运行以下命令查看帮助：${NC}"
    echo -e "  ${GREEN}${INSTALL_NAME} --help${NC}"
    echo ""
    echo -e "${BLUE}运行以下命令查看版本：${NC}"
    echo -e "  ${GREEN}${INSTALL_NAME} --version${NC}"
    echo ""
    echo -e "${BLUE}运行以下命令开始使用：${NC}"
    echo -e "  ${GREEN}${INSTALL_NAME}${NC}"
    return 0
  else
    echo -e "${YELLOW}警告：安装可能未成功，请检查 PATH 设置${NC}"
    echo -e "${YELLOW}确保 ${INSTALL_DIR} 在您的 PATH 中${NC}"
    return 1
  fi
}

# 主函数
main() {
  echo -e "${BLUE}════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  recon-runway (rr) 安装程序${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════${NC}"
  echo ""
  
  check_dependencies
  check_sudo
  download_script
  install_script
  verify_installation
  
  echo ""
  echo -e "${GREEN}安装完成！${NC}"
}

main "$@"

