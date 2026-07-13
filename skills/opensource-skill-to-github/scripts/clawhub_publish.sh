#!/usr/bin/env bash
# clawhub_publish.sh — Step 10 (optional): clawhub publish
# Usage: CLAWHUB_TOKEN=clh_xxx ./clawhub_publish.sh <fork-abs-path>
set -euo pipefail

FORK="${1:-}"

if [[ -z "$FORK" ]]; then
  cat <<EOF >&2
Usage: CLAWHUB_TOKEN=clh_xxx $0 <fork-abs-path>

  example: CLAWHUB_TOKEN=clh_xxx $0 /path/to/opensourceskills/my-skill

⚠️  必须用绝对路径（相对路径偶发 SKILL.md required 报错）。
⚠️  CLAWHUB_TOKEN 与 GitHub token 完全独立；临时 token 分别撤销，长期配置分别管理。
⚠️  Publish 成功后请立刻去 clawhub.com 撤销该 token。
EOF
  exit 1
fi

# 强制绝对路径
case "$FORK" in
  /*) ;;
  *)  echo "❌ 必须用绝对路径（相对路径偶发 SKILL.md required 报错）" >&2; exit 2 ;;
esac

[[ -d "$FORK" ]] || { echo "❌ fork-path not a directory: $FORK" >&2; exit 3; }
[[ -f "$FORK/SKILL.md" ]] || { echo "❌ SKILL.md not found in $FORK" >&2; exit 4; }

if ! command -v clawhub >/dev/null 2>&1; then
  echo "❌ clawhub CLI 未安装，请先：npm install -g clawhub" >&2
  exit 6
fi

# 鉴权：优先用已登录态（clawhub login 后本地已持久化 token）；
# 仅当未登录时才要求 CLAWHUB_TOKEN 环境变量。
CLAWHUB_ENV=()
if clawhub whoami >/dev/null 2>&1; then
  WHO="$(clawhub whoami 2>/dev/null | grep -v Checking | tr -d '✔ ' | tail -1)"
  echo "ℹ️  clawhub 已登录（$WHO），使用已登录态发布"
elif [[ -n "${CLAWHUB_TOKEN:-}" ]]; then
  echo "ℹ️  clawhub 未登录，使用 CLAWHUB_TOKEN 环境变量"
  CLAWHUB_ENV=(env "CLAWHUB_TOKEN=$CLAWHUB_TOKEN")
else
  echo "❌ clawhub 未登录且未设 CLAWHUB_TOKEN" >&2
  echo "   请任选：① clawhub login  ② CLAWHUB_TOKEN=clh_xxx $0 $FORK" >&2
  exit 5
fi

# 从 SKILL.md 提取版本（clawhub publish 强制 semver --version），缺则默认 1.0.0
VERSION="$(grep -m1 -oP '\*\*Version\*\*:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$FORK/SKILL.md" 2>/dev/null || echo '1.0.0')"
echo "ℹ️  version: $VERSION"

echo "🚀 Publishing to clawhub.com ..."

# 重试（rate limit / 网络抖动 → sleep 30s 重试）
for i in 1 2 3; do
  if "${CLAWHUB_ENV[@]}" clawhub publish "$FORK" --version "$VERSION"; then
    echo ""
    echo "✅ Published to clawhub.com ($VERSION)"
    break
  fi
  rc=$?
  if [[ $i -lt 3 ]]; then
    echo "⚠️  Attempt $i failed (rc=$rc), retrying after 30s..."
    sleep 30
  else
    echo "❌ Publish failed after 3 retries" >&2
    exit $rc
  fi
done

# 提醒 LICENSE 平台特性
echo ""
echo "ℹ️  关于 LICENSE："
echo "   clawhub 强制 LICENSE 为 MIT-0（本地 LICENSE 文件被忽略，三渠道 license 不一致是平台特性，不是 bug）"
echo ""
echo "🔐 Token hygiene reminder:"
echo "   立刻去 clawhub.com 撤销刚才用的 token"
echo ""
echo "📝 Next steps:"
echo "   - skills.sh 通过 GitHub repo 自动同步（24h 后才在 npx skills list 可见）"
echo "   - 沉淀 memory: memory/project_$(basename "$FORK")_opensource_fork.md"
