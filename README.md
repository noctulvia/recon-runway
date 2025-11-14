# recon-runway (rr)

一个用于侦察环境设置和资源管理的自动化工具，帮助安全研究人员快速配置和管理子域名枚举所需的字典文件与 DNS 解析器。

## 项目简介

**recon-runway**（简称 `rr`）是一个专为渗透测试和安全研究设计的命令行工具，旨在简化侦察阶段所需资源的下载、更新和管理流程。

### 功能特点

- **自动化资源管理**：自动下载和更新子域名字典文件与 DNS 解析器列表
- **多源字典整合**：合并 SecLists、AssetNote 等多个来源的字典，生成全量字典文件
- **智能健康检查**：检测资源文件的存在性、完整性和时效性，自动更新过期资源
- **网络环境检测**：检测网络连通性和代理配置状态
- **配置文件生成**：自动生成环境变量配置文件，便于集成到工作流中
- **跨平台支持**：支持 macOS 和 Linux 系统

### 适用场景

- 渗透测试前的环境准备
- 子域名枚举工具的字典管理
- DNS 解析器列表的维护
- 安全研究环境的快速配置

## 安装说明

### 前置依赖

确保系统已安装以下工具：

- `bash`（通常已预装）
- `curl`
- `git`
- `wget`
- `stat`（通常已预装）
- `date`（通常已预装）
- `wc`（通常已预装）
- `anew` - 用于字典去重（[安装指南](https://github.com/tomnomnom/anew)）

#### 安装 anew（如未安装）

```bash
# 使用 Go 安装
go install -v github.com/tomnomnom/anew@latest

# 或使用 Homebrew（macOS）
brew install anew
```

### 安装脚本

#### 方法一：使用 install 命令（推荐，macOS & Linux 通用）

1. **进入脚本所在目录**：
   ```bash
   cd /path/to/recon-runway
   ```

2. **安装脚本到系统 PATH**：
   ```bash
   sudo install -m 0755 recon-runway.sh /usr/local/bin/rr
   ```

   该命令会：
   - 将脚本复制到 `/usr/local/bin/rr`
   - 自动设置执行权限（0755）
   - 适用于 macOS 和大部分 Linux 发行版

3. **验证安装**：
   ```bash
   rr --help
   ```

#### 方法二：创建符号链接

1. **下载脚本**：将 `recon-runway` 脚本保存到本地目录（例如：`~/bin/recon-runway.sh`）

2. **添加执行权限**：
   ```bash
   chmod +x ~/bin/recon-runway.sh
   ```

3. **创建符号链接**：
   ```bash
   sudo ln -s ~/bin/recon-runway.sh /usr/local/bin/rr
   ```

4. **验证安装**：
   ```bash
   rr --help
   ```

#### 方法三：使用别名（临时方案）

如果不想修改系统 PATH，可以在 shell 配置文件中添加别名：

1. **编辑 shell 配置文件**：
   ```bash
   # Bash
   nano ~/.bashrc
   # 或
   nano ~/.bash_profile
   
   # Zsh
   nano ~/.zshrc
   ```

2. **添加别名**（将 `/path/to/recon-runway.sh` 替换为实际脚本路径）：
   ```bash
   alias rr='/path/to/recon-runway.sh'
   ```

3. **重新加载配置**：
   ```bash
   # Bash
   source ~/.bashrc
   # 或
   source ~/.bash_profile
   
   # Zsh
   source ~/.zshrc
   ```

4. **验证安装**：
   ```bash
   rr --help
   ```

## 使用说明

### 基本命令

```bash
rr [选项]
```

**注意**：如果不指定任何参数，脚本将默认执行 `-check` 操作。

### 命令选项

| 选项 | 说明 |
|------|------|
| 无参数 | 执行完整的系统检测（默认行为，等同于 `-check`） |
| `-check` | 执行完整的系统检测，包括网络连通性、代理状态、字典文件和解析器文件的健康检查 |
| `-download-wordlists [path]` | 下载字典文件到指定路径（可选）。如未指定路径，将使用默认路径 `~/security/wordlists` |
| `-download-resolvers [path]` | 下载 DNS 解析器文件到指定路径（可选）。如未指定路径，将使用默认路径 `~/security/resolvers` |
| `-s, --silent` | 静默模式，仅输出 `source ${HOME}/.rrc` 命令，便于管道调用（如 `rr -s \| pbcopy`） |
| `-h, --help` | 显示帮助信息 |

### 使用示例

#### 1. 执行完整检测（默认行为）

```bash
# 直接运行（默认执行检测）
rr

# 或显式指定 -check
rr -check
```

该命令将：
- 检测网络连通性（baidu.com、google.com）
- 检测代理配置状态
- 检查字典文件（快速、常规、全量）的存在性和时效性
- 检查解析器文件的存在性和时效性（超过 3 天自动更新）
- 自动生成配置文件 `~/.rrc`

#### 2. 静默模式（便于管道调用）

```bash
# 静默模式，仅输出 source 命令
rr -s

# 将 source 命令复制到剪贴板（macOS）
rr -s | pbcopy

# 将 source 命令追加到文件
rr -s >> ~/.zshrc
```

静默模式适用于：
- 自动化脚本集成
- 快速获取配置命令
- 管道操作和重定向

#### 3. 下载字典文件

```bash
# 使用默认路径
rr -download-wordlists

# 指定自定义路径
rr -download-wordlists /custom/path/wordlists

# 指定目录路径
rr -download-wordlists /custom/path/
```

该命令将：
- 克隆或更新 SecLists 仓库
- 下载 AssetNote best-dns-wordlist.txt
- 生成全量字典文件（合并多个源并去重）
- 验证快速字典（5000 条）和常规字典（110000 条）文件

#### 4. 下载解析器文件

```bash
# 使用默认路径
rr -download-resolvers

# 指定自定义路径
rr -download-resolvers /custom/path/resolvers
```

该命令将：
- 下载公共 DNS 解析器列表（resolvers.txt）
- 下载可信 DNS 解析器列表（resolvers-trusted.txt）

#### 5. 组合使用

```bash
# 先下载资源，再执行检测
rr -download-wordlists && rr -download-resolvers && rr

# 或使用显式的 -check
rr -download-wordlists && rr -download-resolvers && rr -check
```

### 典型使用流程

1. **首次使用**：
   ```bash
   # 执行检测（默认行为），脚本会自动下载缺失的资源
   rr
   
   # 或显式指定
   rr -check
   
   # 应用环境变量
   source ~/.rrc
   
   # 或使用静默模式直接获取命令
   eval "$(rr -s)"
   ```

2. **定期更新资源**：
   ```bash
   # 更新字典文件
   rr -download-wordlists
   
   # 更新解析器文件
   rr -download-resolvers
   
   # 应用更新的环境变量
   source ~/.rrc
   ```

3. **在脚本中使用**：
   ```bash
   # 在侦察脚本中引用环境变量
   source ~/.rrc
   subfinder -dL "$TARGETS" -w "$SUBDOMAINS_FAST" | httpx
   ```

### 环境变量

脚本会自动生成配置文件 `~/.rrc`，包含以下环境变量：

- `BASE`：基础目录路径（默认：`~/security`）
- `RESOLVERS`：公共 DNS 解析器文件路径
- `RESOLVERS_TRUSTED`：可信 DNS 解析器文件路径
- `SUBDOMAINS_FULL`：全量字典文件路径（合并多个源）
- `SUBDOMAINS_FAST`：快速字典文件路径（5000 条）
- `SUBDOMAINS`：常规字典文件路径（110000 条）

应用环境变量：
```bash
source ~/.rrc
```

## 注意事项

### 权限要求

- 脚本本身无需 root 权限运行
- 创建符号链接或复制到 `/usr/local/bin` 需要 sudo 权限
- 脚本会在用户主目录下创建 `~/security` 目录，需要写入权限

### 依赖工具

确保以下工具已正确安装并在 PATH 中：

- **git**：用于克隆和更新 SecLists 仓库
- **wget**：用于下载 AssetNote 字典文件
- **curl**：用于下载解析器文件和网络检测
- **anew**：用于字典文件去重（必需）

### 网络要求

- 需要能够访问 GitHub（下载 SecLists 和解析器）
- 需要能够访问 AssetNote CDN（下载字典文件）
- 脚本会检测网络连通性，如遇网络问题会给出提示

### 文件路径

- **默认基础目录**：`~/security`
- **字典文件目录**：`~/security/wordlists`
- **解析器文件目录**：`~/security/resolvers`
- **配置文件**：`~/.rrc`

可通过环境变量 `BASE` 自定义基础目录：
```bash
export BASE=/custom/path
rr -check
```

### 系统兼容性

- **macOS**：完全支持（已测试）
- **Linux**：完全支持（已测试）
- **Windows**：不支持（需要 WSL 或 Git Bash）

### 资源更新策略

- **字典文件**：检测到缺失时自动下载
- **解析器文件**：超过 3 天自动更新
- **SecLists**：如果已存在，会尝试 `git pull` 更新

### 常见问题

1. **anew 未找到**：
   ```bash
   # 确保 anew 在 PATH 中
   which anew
   # 如未找到，请参考安装说明安装 anew
   ```

2. **网络连接失败**：
   - 检查网络连接
   - 如使用代理，确保已正确配置 `http_proxy`、`https_proxy` 等环境变量
   - 脚本会自动检测代理配置

3. **权限不足**：
   - 确保对目标目录有写入权限
   - 如使用系统目录，可能需要 sudo 权限

4. **字典文件生成失败**：
   - 检查磁盘空间是否充足
   - 确保所有依赖工具已正确安装
   - 检查网络连接是否正常

### 性能考虑

- 首次下载字典文件可能需要较长时间（取决于网络速度）
- SecLists 仓库较大，建议使用 `git clone --depth 1`（脚本已自动使用）
- 全量字典文件生成过程会进行去重操作，可能需要一些时间

## 许可协议

本项目采用 MIT 许可证。详见 LICENSE 文件（如有）。

---

**注意**：本工具仅用于合法的安全研究和授权测试。使用者需确保遵守当地法律法规和测试目标的相关政策。

