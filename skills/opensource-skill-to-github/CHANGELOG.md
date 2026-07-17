# Changelog

All notable changes to this skill are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/); versions follow [SemVer](https://semver.org/).

### v1.0.9 (2026-07-17)
- Docs: move changelog out of SKILL.md into this standalone CHANGELOG.md (open-source convention); README/SKILL.md keep pointers

### v1.0.8
- **新增 `_lib_exclude.sh` 发布前统一排除清理**：`github_push.sh` / `clawhub_publish.sh` / `skillhub_cn_publish.sh` 三个发布脚本在动手前自动物理清理派生缓存——`__pycache__/` `.pytest_cache/` `.mypy_cache/` `.ruff_cache/` `.tox/` `htmlcov/` 目录 + `*.pyc` `*.pyo` `.DS_Store` `Thumbs.db` `.coverage` 文件。解决典型坑：audit 阶段 `py_compile` 复活 `__pycache__` → 部分 hub 平台拒收 `.pyc`（此前每次都要手动 `find -name __pycache__ -exec rm`）。支持 fork 根目录放 `.osg-exclude`（每行一个 find 模式，# 注释）追加自定义排除，内置防呆拒绝 `*` / `*.py` / `SKILL.md` 等危险模式；`skillhub_cn_publish.sh` 文件收集白名单同步补 `tests/` / `*.pyc` / `__pycache__/` / `.osg-exclude` 跳过

### v1.0.7
- **Bug 修复（dogfood 自发时暴露）**：`clawhub_publish.sh` 把 clawhub 的 `Version X already exists` 当失败重试——首轮其实已发布成功（clawhub Latest 已更新），但重试再发时平台报"已存在"，脚本误判为失败打出 `❌ Publish failed after 3 retries`。修复：捕获 publish 输出，命中 `already exists` 时识别为**幂等成功**（跳过重试 + 提示"如需重发先 bump 版本号"），不再假报错

### v1.0.6
- **Bug 修复（skill-to-http 开源时实测暴露）**：`clawhub_publish.sh` 在已登录态分支解析 `clawhub whoami` 输出的那行——`WHO="$(clawhub whoami | grep -v Checking | tr -d '✔ ' | tail -1)"`——在 `set -euo pipefail` 下会**静默杀死整个脚本、零输出退出**（真实 CLI 复现 rc=1）。根因：新版 clawhub CLI 把 spinner（`- Checking token` / `✔ <user>`）打到 stdout，管道下游 `tail` 提前关闭 stdout 使 `clawhub whoami` 因 SIGPIPE 非零退出，`pipefail` 采纳该非零码。修复：解析行加 `|| true` 兜底吸收管道非零 + `WHO="${WHO:-已登录用户}"` 空值兜底（whoami 前置判断已确认登录成功，用户名只是提示文案，解析失败不应阻断发布）。现象反直觉：`clawhub whoami` 单独跑明明成功、脚本却零输出退出——优先怀疑 pipefail + spinner SIGPIPE，而非登录态本身

### v1.0.5
- **Bug 修复①（agent-easy-http 开源时实测暴露）**：`git_init.sh` 传**相对路径**（如 `opensourceskills/<slug>`）时，脚本先 `cd "$FORK"` 后又在二次校验 `EXPECTED_GITDIR="$(cd "$FORK" && pwd -P)/.git"` 里对同一相对路径再 `cd` 一次 → 从新 CWD 解析失败报「没有那个文件或目录」→ git init 成功但 commit 未执行。修复：验证目录存在后**立即把 `$FORK` 解析为绝对路径**（`FORK="$(cd "$FORK" && pwd -P)"`），后续所有 `cd` / 校验均基于绝对路径，相对/绝对入参都稳定
- **Bug 修复②（macOS BSD grep 兼容，用户 Mac 实测暴露）**：`run_all.sh` / `git_init.sh` / `skillhub_cn_publish.sh` / `clawhub_publish.sh` 共 6 处用了 `grep -oP '...\K...'`（`-P` = Perl 正则，仅 GNU grep 支持）。macOS 自带 **BSD grep 不支持 `-P`**，直接报 `invalid option -- P` 退出 → 变量解析为空 → 触发 `[[ -z ... ]]` 提前 exit（`run_all.sh` 卡在 fork 之后 / 版本号取不到）。统一改为 BSD+GNU 通用写法：`grep -o '整行前缀.*'` 抓整行 + `sed` / `grep -o` 剥前缀，效果等价 `\K` 后向剥除，全平台可移植（`-m` / `[[:space:]]` 亦 BSD/GNU 通用）

### v1.0.4
- **Bug 修复**（dogfood 自举开源时实测暴露）：`fork.sh` 的 cp 回退分支只删了 node_modules/.git，未清 rsync 分支同样排除的 `.skill-data/output/__pycache__/*.pyc/opensourceskills`，导致 rsync 不可用环境下嵌套子目录被误复制进副本；rsync 分支也补排 `opensourceskills/`
- **Bug 修复**：`skillhub_cn_publish.sh` 用 `-F "payload=$内联字符串"` 发 multipart，当 displayName/summary 含空格或括号时被 curl 截断成非法 JSON（报 `payload JSON 格式错误`）；改为写临时文件 `-F "payload=<file"` 从文件读

### v1.0.3
- **P0 修复**：`git_init.sh` 不再用 `git rev-parse --git-dir`（会穿透父仓库），改为只认 fork 自己的 `.git` + 二次校验，修复「fork 位于 git repo 内时误提交到父仓库」的坑（跨 agent 环境必现）
- **P0 修复**：`fork.sh` 去除 `~/.openclaw/workspace` 硬编码，支持绝对路径 + 多 agent skills 目录探测 + `OPENSOURCE_OUT_DIR`；fork 时排除 node_modules/.git/output
- **P0 修复**：`clawhub_publish.sh` 优先用已登录态（免 token）+ 自动补 `--version`（从 SKILL.md 提取）
- **P1**：`github_push.sh` 默认 `http.version HTTP/1.1` + `http.postBuffer 524288000`（大文件/弱网兜底）+ push 后内建 sha 验真（GitHub API 优先，ls-remote 回退）
- **P1**：新增 `skillhub_cn_publish.sh`（腾讯 skillhub.cn target，multipart，displayName/summary 自动提取，白名单剔除 LICENSE/.gitignore/archive）
- **P1**：`strip_scan.sh` 关键词表支持 `strip_keywords.txt` 外置文件（换公司内网词）
- **P1**：本 skill 自身署名脱敏为 Evan Song
- **P2**：新增 `run_all.sh` 一键串联前 6 步

### v1.0.1 (2026-07-13)
- Fix `fork.sh` cp-fallback branch to clean all rsync-excluded paths (`.skill-data`/`output`/`__pycache__`/`*.pyc`/`opensourceskills`); rsync branch also excludes `opensourceskills/`
- Fix `skillhub_cn_publish.sh` multipart payload truncation — write payload to a temp file and read via `-F "payload=<file"` instead of an inline string

### v1.0.0 (2026-07-13)
- Initial public release
- Configurable internal-keyword scanning (generic defaults + user-configured company words)
- Bundled vendor-neutral open-source playbook
- 4-tier GitHub token source + push sha verification
- Cross-platform (macOS bash 3.2 compatible)
