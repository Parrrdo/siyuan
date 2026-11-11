#!/usr/bin/env bash
# 构建修改版思源 Docker 镜像（薄构建：基于官方镜像，替换内核与前端产物）
# 用法：./build-docker-thin.sh [版本号]   版本号取自 kernel/util/working.go 的 Ver
# 注意：仓库根目录的 .dockerignore 会过滤 app/stage/build（前端编译产物），
#       因此必须先把产物拷贝到独立构建上下文，不能直接在仓库根目录 docker build。
set -euo pipefail

VER="${1:-3.8.10}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CTX="$(mktemp -d)"
trap 'rm -rf "$CTX"' EXIT

echo ">> 检查前置产物"
[[ -f "$REPO_ROOT/kernel/kernel" ]] || { echo "缺少 kernel/kernel，请先编译内核（见 PATCH-NOTES.md）"; exit 1; }
[[ -d "$REPO_ROOT/app/stage/build" ]] || { echo "缺少 app/stage/build，请先编译前端（见 PATCH-NOTES.md）"; exit 1; }

echo ">> 组装独立构建上下文 $CTX"
mkdir -p "$CTX/kernel"
cp -r "$REPO_ROOT/app/stage" "$CTX/stage"
cp -r "$REPO_ROOT/app/appearance" "$CTX/appearance"
cp -r "$REPO_ROOT/app/guide" "$CTX/guide"
cp "$REPO_ROOT/kernel/kernel" "$REPO_ROOT/kernel/entrypoint.sh" "$CTX/kernel/"

cat > "$CTX/Dockerfile" <<'EOF'
FROM b3log/siyuan:latest
# 清掉官方旧前端与主题；保留 stage/ocr（OCR 运行时与模型来自官方镜像）
RUN rm -rf /opt/siyuan/stage/build /opt/siyuan/appearance /opt/siyuan/guide
COPY kernel/kernel /opt/siyuan/kernel
COPY kernel/entrypoint.sh /opt/siyuan/entrypoint.sh
COPY stage/ /opt/siyuan/stage/
COPY appearance/ /opt/siyuan/appearance/
COPY guide/ /opt/siyuan/guide/
RUN chmod 755 /opt/siyuan/kernel /opt/siyuan/entrypoint.sh
EOF

echo ">> 构建镜像 siyuan-modified:$VER"
docker build -t "siyuan-modified:$VER" "$CTX"
echo ">> 完成。推送：docker tag siyuan-modified:$VER ghcr.io/parrrdo/siyuan:$VER-free && docker push ghcr.io/parrrdo/siyuan:$VER-free"
