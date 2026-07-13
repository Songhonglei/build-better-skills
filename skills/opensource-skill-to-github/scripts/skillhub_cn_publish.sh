#!/usr/bin/env bash
# skillhub_cn_publish.sh — Step 10 (optional): 腾讯 skillhub.cn 发布
# Usage: SKILLHUB_CN_TOKEN=skh_xxx ./skillhub_cn_publish.sh <fork-abs-path>
#
# 协议（2026-07-13 实测）：
#   POST https://api.skillhub.cn/api/v1/community/skills/publish
#   Content-Type: multipart/form-data ; Authorization: Bearer skh_xxx
#   field "payload" (JSON): slug / name / displayName(必填) / summary / description / version
#   field "files" (repeated): 每个源码文件（白名单外的文件会被平台拒收）
set -euo pipefail

FORK="${1:-}"

if [[ -z "$FORK" ]]; then
  cat <<EOF >&2
Usage: SKILLHUB_CN_TOKEN=skh_xxx $0 <fork-abs-path>

  example: SKILLHUB_CN_TOKEN=skh_xxx $0 /abs/path/opensourceskills/my-skill

⚠️  必须用绝对路径。
⚠️  SKILLHUB_CN_TOKEN 前缀 skh_，与 GitHub/clawhub token 完全独立。
⚠️  Publish 成功后请立刻去 skillhub.cn 撤销该 token。
EOF
  exit 1
fi

case "$FORK" in /*) ;; *) echo "❌ 必须用绝对路径" >&2; exit 2 ;; esac
[[ -d "$FORK" ]] || { echo "❌ 不是目录: $FORK" >&2; exit 3; }
[[ -f "$FORK/SKILL.md" ]] || { echo "❌ SKILL.md not found in $FORK" >&2; exit 4; }

if [[ -z "${SKILLHUB_CN_TOKEN:-}" ]]; then
  echo "❌ SKILLHUB_CN_TOKEN 环境变量未设置" >&2
  exit 5
fi
command -v curl >/dev/null 2>&1 || { echo "❌ 需要 curl" >&2; exit 6; }
command -v python3 >/dev/null 2>&1 || { echo "❌ 需要 python3（生成 payload/解析响应）" >&2; exit 6; }

API="https://api.skillhub.cn"
AUTH="Authorization: Bearer $SKILLHUB_CN_TOKEN"

# ---- 从 SKILL.md frontmatter 提取字段 ----
SLUG="$(basename "$FORK")"
NAME="$(grep -m1 -oP '^name:\s*\K.+' "$FORK/SKILL.md" 2>/dev/null || echo "$SLUG")"
VERSION="$(grep -m1 -oP '\*\*Version\*\*:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$FORK/SKILL.md" 2>/dev/null || echo '1.0.0')"
# displayName：优先 # 一级标题，回退 name
DISPLAY="$(grep -m1 -oP '^#\s+\K.+' "$FORK/SKILL.md" 2>/dev/null || echo "$NAME")"
# description/summary：取 frontmatter description 首句（折叠多行）
DESC="$(awk '/^description:/{f=1;sub(/^description:[ >|]*/,"");if($0!="")print;next} f&&/^[a-zA-Z_]+:/{exit} f{gsub(/^[ \t]+/,"");print}' "$FORK/SKILL.md" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g;s/ *$//')"
[[ -z "$DESC" ]] && DESC="$DISPLAY"
SUMMARY="$(echo "$DESC" | cut -c1-40)"

echo "ℹ️  slug=$SLUG  version=$VERSION"
echo "ℹ️  displayName=$DISPLAY"

# ---- 校验 token + slug 可用性 ----
echo "🔎 校验 token 与 slug..."
me_code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -H "$AUTH" "$API/api/v1/auth/me" 2>/dev/null || echo 000)"
if [[ "$me_code" == "401" ]]; then echo "❌ token 无效（401）" >&2; exit 7; fi

# ---- 组装 payload JSON（python 安全转义）----
PAYLOAD="$(python3 - "$SLUG" "$NAME" "$DISPLAY" "$SUMMARY" "$DESC" "$VERSION" <<'PY'
import json,sys
slug,name,display,summary,desc,version=sys.argv[1:7]
print(json.dumps({
  "slug":slug,"name":name,"displayName":display,
  "summary":summary,"description":desc,"version":version,
  "claimSlug":True,"joinContest":False
},ensure_ascii=False))
PY
)"

# ---- 收集要发的文件（白名单：只发源码；剔除无后缀文件/dotfile/archive/签名/依赖）----
cd "$FORK"
FILES=()
while IFS= read -r f; do
  f="${f#./}"
  case "$f" in
    .git/*|node_modules/*|output/*|tmp/*|assets/*.png) continue ;;   # 目录/大二进制
    LICENSE|NOTICE|COPYING|.gitignore|.gitattributes|sign.key) continue ;;  # 平台白名单拒收
    *.tar.gz|*.tgz|*.zip|*.bin|*.dat|*.DS_Store) continue ;;
    *) FILES+=("$f") ;;
  esac
done < <(find . -type f 2>/dev/null | sort)

if [[ ${#FILES[@]} -eq 0 ]]; then echo "❌ 无可发布文件" >&2; exit 8; fi
echo "ℹ️  待发 ${#FILES[@]} 个文件: ${FILES[*]}"

# ---- multipart publish ----
CURL_ARGS=(-s --max-time 180 -X POST "$API/api/v1/community/skills/publish"
           -H "$AUTH" -F "payload=$PAYLOAD;type=application/json")
for f in "${FILES[@]}"; do CURL_ARGS+=(-F "files=@$f;type=application/octet-stream"); done

echo "🚀 Publishing to skillhub.cn ..."
RESP="$(curl "${CURL_ARGS[@]}" 2>&1)"
echo "$RESP"

# ---- 解析结果 ----
if echo "$RESP" | grep -q '"ok":true'; then
  echo ""
  echo "✅ Published to skillhub.cn ($VERSION)"
  # 验真：detail 接口回查
  echo "🔎 验真..."
  D="$(curl -s --max-time 20 -H "$AUTH" "$API/api/v1/skills/$SLUG" 2>/dev/null)"
  echo "$D" | grep -q "\"slug\":\"$SLUG\"" && echo "✅ detail 验真通过" || echo "⚠️  detail 未查到，稍后手动确认"
else
  echo "" >&2
  echo "❌ Publish 失败，原始响应见上。常见原因：" >&2
  echo "   - displayName 不能为空（本脚本已自动提取，若仍报请检查 SKILL.md 一级标题）" >&2
  echo "   - slug 格式（须 ^[a-z0-9][a-z0-9-]*[a-z0-9]$）" >&2
  echo "   - token 失效 / 实名认证未完成" >&2
  exit 9
fi

echo ""
echo "🔐 立刻去 skillhub.cn 撤销刚才用的 token"
