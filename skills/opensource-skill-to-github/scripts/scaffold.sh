#!/usr/bin/env bash
# scaffold.sh — Step 6: 生成 README.md 模板 + 通用安全 .gitignore
# Usage: ./scaffold.sh <fork-path>
set -euo pipefail

. "$(dirname "$0")/_lib_profile.sh"
osg_resolve_identity   # 加载 profile.env + git config 兜底

FORK="${1:-}"
[[ -d "$FORK" ]] || { echo "Usage: $0 <fork-path>" >&2; exit 1; }

cd "$FORK"
SLUG="$(basename "$FORK")"

# 身份取值优先级：OSG_* env > profile.env > git config > 占位
AUTHOR_NAME="${OSG_AUTHOR_NAME:-<your-name>}"
AUTHOR_HANDLE="${OSG_GITHUB_HANDLE:-<your-github-handle>}"

# ─── README.md ─────────────────────────────────
if [[ -f README.md ]]; then
  echo "ℹ️  README.md already exists"
  if [[ "${OSG_SCAFFOLD_FORCE:-0}" == "1" ]]; then
    echo "   OSG_SCAFFOLD_FORCE=1 → overwrite"
  else
    echo "   set OSG_SCAFFOLD_FORCE=1 to overwrite, or edit manually"
    SKIP_README=1
  fi
fi

if [[ "${SKIP_README:-0}" != "1" ]]; then
  cat > README.md <<EOF
# $SLUG

> One-line description here (从 SKILL.md 抄过来即可)

## Features

- Feature 1
- Feature 2
- Feature 3

## Quick Start

\`\`\`bash
# Install (clawhub)
clawhub install $SLUG

# Or clone directly
git clone https://github.com/$AUTHOR_HANDLE/$SLUG.git
\`\`\`

## Usage

详细使用方法见 [SKILL.md](./SKILL.md)。

## Install in your AI agent

| Agent | Install |
|---|---|
| OpenClaw | \`clawhub install $SLUG\` |
| Claude Code | Manual: copy to \`~/.claude/skills/\` |
| Cursor | Manual: copy to \`.cursor/skills/\` |

## License

MIT (see [LICENSE](./LICENSE))

## Author

$AUTHOR_NAME · [github.com/$AUTHOR_HANDLE](https://github.com/$AUTHOR_HANDLE)

## Changelog

### v1.0.0 ($(date +%Y-%m-%d))

- Initial release
EOF
  echo "✅ Created README.md (author=$AUTHOR_NAME handle=$AUTHOR_HANDLE)"
  if [[ "$AUTHOR_NAME" == "<your-name>" || "$AUTHOR_HANDLE" == "<your-github-handle>" ]]; then
    echo ""
    echo "   ⚠️  README 含占位符，请配置开源身份："
    echo "       一次性配置（推荐）: bash $(dirname "$0")/setup_profile.sh"
    echo "       临时覆盖:           export OSG_AUTHOR_NAME='...' OSG_GITHUB_HANDLE='...'"
    echo "       手工编辑 README.md 也行"
  fi
fi

# ─── .gitignore ─────────────────────────────────
if [[ -f .gitignore ]]; then
  echo "ℹ️  .gitignore already exists, will merge missing rules"
fi

cat > .gitignore.tmp <<'EOF'
# ─── Sensitive credentials (never commit) ─────
*.key
!*.public.key
id_rsa
id_rsa.*
id_ed25519
id_ed25519.*
*.pem
*.p12
*.pfx
*.keystore
**/certs/*.key
**/secrets/
.env
.env.*
!.env.example
*.token
*token*.json
.secrets/

# ─── OS / Editor ─────
.DS_Store
Thumbs.db
*.swp
*~
.idea/
.vscode/

# ─── Language artifacts ─────
__pycache__/
*.pyc
*.pyo
*.pyd
.pytest_cache/
.mypy_cache/
node_modules/
*.log
dist/
build/

# ─── Skill runtime cache ─────
.skill-data/
.cache/
tmp/
output/

# ─── AI agent internal ─────
sign.key
.install-source.json
skill_meta.json
*.json.md
EOF

if [[ -f .gitignore ]]; then
  # 合并：保留已有，追加缺失
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    grep -qxF "$line" .gitignore || echo "$line" >> .gitignore
  done < .gitignore.tmp
  rm .gitignore.tmp
  echo "✅ Merged additional rules into .gitignore"
else
  mv .gitignore.tmp .gitignore
  echo "✅ Created .gitignore"
fi

echo ""
echo "📝 Next steps:"
echo "   1. Edit README.md (Features / one-line description)"
echo "   2. Run git_init.sh to initialize git"
