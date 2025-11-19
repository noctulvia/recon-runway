# 需求文档：recon-runway (rr) 脚本

## 项目概述

**recon-runway**（简称 `rr`）是一个用于侦察环境设置和资源管理的自动化工具，帮助安全研究人员快速配置和管理子域名枚举所需的字典文件与 DNS 解析器。该工具提供一体化的环境检测和资源管理功能，满足日常安全资产扫描前的环境检查需求。

## 功能范围

- 提供统一的命令行入口 `rr`，兼容 macOS 与 Linux
- 默认配置文件路径：`$HOME/.rrc`，用于持久化资源路径环境变量
- 默认资源目录：`$HOME/security/`，包含 `resolvers/` 与 `wordlists/` 子目录
- 支持静默模式输出，便于管道调用和脚本集成

## 核心功能需求

### 1. 网络连通性检测

**功能描述**：
- 检测网络连通性，验证系统是否能够访问外部网络
- 依次检测 `baidu.com` 与 `google.com` 的连通性
- 自动降级机制：优先使用 `curl` 进行 HTTPS 请求，若无 `curl` 则降级为 `ping` 命令

**输出格式**：
- 成功：`[OK] 网络连通性检测 正常`
- 失败：`[FAIL] 网络连通性检测 异常: <host> 连接失败`

**实现要求**：
- 超时时间设置为 5 秒（curl）或 2 秒（ping）
- 检测失败不应中断后续流程

### 2. 代理状态检测

**功能描述**：
- 检测系统环境变量中配置的代理设置
- 支持检测以下代理类型：
  - HTTP 代理：`http_proxy` / `HTTP_PROXY`
  - HTTPS 代理：`https_proxy` / `HTTPS_PROXY`
  - SOCKS 代理：`socks_proxy` / `SOCKS_PROXY` / `all_proxy` / `ALL_PROXY`

**输出格式**：
- 有配置：`[OK] 代理检测 <数量> 个 (HTTP HTTPS SOCKS)`
- 无配置：`[FAIL] 代理检测 未配置`

### 3. 字典文件管理

**功能描述**：
- 管理三种类型的子域名字典文件：
  - **快速字典**（`SUBDOMAINS_FAST`）：SecLists 5000 条常用子域名
  - **常规字典**（`SUBDOMAINS`）：SecLists 110000 条子域名
  - **全量字典**（`SUBDOMAINS_FULL`）：合并多个源的完整字典（AssetNote + SecLists）

**字典来源**：
- SecLists 仓库（GitHub）
- AssetNote best-dns-wordlist.txt

**检测逻辑**：
- 检查文件是否存在且非空
- 显示文件行数和最后修改日期
- 文件缺失时自动下载

**输出格式**：
- 存在：`[OK] <类型>字典文件 <变量名>, <行数> 行, <日期>`
- 缺失：`[MISS] <类型>字典文件 <变量名>, 缺失`
- 更新后：`[UPDATED] <类型>字典文件 <变量名>, <行数> 行, <日期>`

**下载功能**：
- 命令：`rr -download-wordlists [path]`
- 支持指定目录或文件路径
- 自动克隆/更新 SecLists 仓库（使用 `git clone --depth 1`）
- 下载 AssetNote 字典文件
- 使用 `anew` 工具合并并去重生成全量字典
- 下载完成后自动更新配置文件

### 4. 解析器文件管理

**功能描述**：
- 管理两类 DNS 解析器文件：
  - **公共解析器**（`RESOLVERS`）：`resolvers.txt`
  - **可信解析器**（`RESOLVERS_TRUSTED`）：`resolvers-trusted.txt`

**数据来源**：
- Trickest resolvers 仓库（GitHub）

**检测逻辑**：
- 检查文件是否存在且非空
- 检查文件时效性（超过 3 天标记为过期）
- 显示文件行数和最后修改日期
- 文件缺失或过期时自动更新

**输出格式**：
- 正常：`[OK] 解析器文件 RESOLVERS, <行数> 行, <日期>`
- 缺失：`[MISS] 解析器文件 RESOLVERS, 缺失`
- 过期：`[STALE] 解析器文件 RESOLVERS, 已过期 <天数> 天`
- 更新后：`[UPDATED] 解析器文件 RESOLVERS, <行数> 行, <日期>`

**下载功能**：
- 命令：`rr -download-resolvers [path]`
- 支持指定自定义目录
- 下载完成后自动更新配置文件

### 5. 配置文件管理

**功能描述**：
- 自动生成配置文件 `$HOME/.rrc`
- 配置文件包含以下环境变量：
  - `BASE`：基础目录路径
  - `RESOLVERS`：公共 DNS 解析器文件路径
  - `RESOLVERS_TRUSTED`：可信 DNS 解析器文件路径
  - `SUBDOMAINS_FULL`：全量字典文件路径
  - `SUBDOMAINS_FAST`：快速字典文件路径
  - `SUBDOMAINS`：常规字典文件路径

**使用方式**：
- 执行检测后自动生成/更新配置文件
- 用户可通过 `source ~/.rrc` 应用环境变量
- 静默模式可直接输出 `source` 命令

### 6. 命令接口

**默认行为**：
- 无参数时默认执行 `-check` 操作

**支持的命令**：
- `rr` 或 `rr -check`：执行完整的系统检测
- `rr -download-wordlists [path]`：下载字典文件
- `rr -download-resolvers [path]`：下载解析器文件
- `rr -s, --silent`：静默模式，执行所有检查但不显示详细输出，最后输出 `source ${HOME}/.rrc` 命令
- `rr -h, --help`：显示帮助信息

**错误处理**：
- 未知参数时输出 usage 信息并退出
- 失败操作给出明确错误提示，不中断后续检测流程

## 非功能性要求

### 代码质量
- 代码需通过 `bash -n` 语法检查
- 使用 `set -euo pipefail` 确保错误处理
- 避免依赖 GNU 专属特性，保证 macOS / Linux 兼容性

### 用户体验
- 支持彩色输出（自动检测终端支持）
- 输出信息简洁清晰，使用统一的格式标记（`[OK]`、`[FAIL]`、`[MISS]`、`[STALE]`、`[UPDATED]`）
- 提供时间戳和详细信息（文件行数、修改日期等）
- 静默模式便于脚本集成和管道调用

### 依赖管理
- 必需依赖：`bash`、`curl`、`git`、`wget`、`anew`、`stat`、`date`、`wc`
- 自动检测依赖工具是否存在
- 提供清晰的错误提示和安装建议

### 路径配置
- 默认基础目录：`$HOME/security/`
- 支持通过环境变量 `BASE` 自定义基础目录
- 所有路径配置可通过环境变量覆盖

### 网络与资源
- 需要访问 GitHub（下载 SecLists 和解析器）
- 需要访问 AssetNote CDN（下载字典文件）
- 自动处理网络错误，提供降级方案

## 实现细节

### 输出系统
- 支持颜色输出（自动检测终端能力）
- 统一的日志函数：`log()`、`info()`、`success()`、`warn()`、`error()`
- 统一的检测结果输出：`print_check()` 函数

### 文件操作
- 跨平台的文件时间戳获取（支持 Linux `stat -c` 和 macOS `stat -f`）
- 文件存在性和非空检查
- 文件年龄计算（天数）

### 资源更新策略
- **字典文件**：检测到缺失时自动下载
- **解析器文件**：超过 3 天自动更新
- **SecLists**：如果已存在，尝试 `git pull` 更新；否则克隆最新版本

### 静默模式
- 静默模式下执行所有检查逻辑（网络检测、代理检测、字典检查、解析器检查）
- 不显示详细的检测输出和状态信息
- 最后输出 `source ${HOME}/.rrc` 命令
- 适用于管道调用：`rr -s | pbcopy`
- 适用于脚本集成：`eval "$(rr -s)"`

## 后续扩展建议

1. **目标管理功能**：
   - `rr -t <target>` 设置单个目标
   - `rr -ts <file>` 设置目标列表文件
   - 将目标信息保存到配置文件

2. **输出格式扩展**：
   - 为 `-check` 增加 JSON 输出选项，便于其他工具集成
   - 支持自定义输出格式

3. **缓存与统计**：
   - 集成缓存命中统计
   - 提示资源更新时间差异
   - 显示资源使用情况

4. **更多检测项**：
   - 检测常用安全工具是否安装（subfinder、httpx、nuclei 等）
   - 检测工具版本和更新状态
   - 自定义网络可达性目标列表

5. **性能优化**：
   - 并行下载资源
   - 增量更新机制
   - 本地缓存验证

## 版本信息

- **项目名称**：recon-runway
- **命令别名**：rr
- **平台支持**：macOS、Linux
- **脚本文件**：`recon-runway.sh`
