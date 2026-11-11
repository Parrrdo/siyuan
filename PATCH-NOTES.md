# free-sync 分支说明

本分支在官方 [siyuan-note/siyuan](https://github.com/siyuan-note/siyuan) 基础上做了 4 处最小改动，
使 S3 / WebDAV / 本地目录同步在**未登录社区账号**的情况下也可用。

## 改动清单

| 文件 | 改动 |
| --- | --- |
| `kernel/model/conf.go` | `IsPaidUser()` 直接返回 `true`（核心校验，后端 5 处调用点全部走它） |
| `kernel/model/sync.go` | 移除 `checkSync()` 中 `nil == Conf.GetUser()` 的登录拦截 |
| `kernel/model/asset_download.go` | `checkAssetDownloadAccess()` 去掉 `Conf.GetUser() == nil` 条件 |
| `app/src/util/needSubscribe.ts` | 前端 `isPaidUser()` 返回 `true`，设置界面正常显示 S3/WebDAV |

官方云端同步（ProviderSiYuan）仍走 `IsSubscriber()`，未登录时依旧不可用，不影响原有逻辑。

## 与官方源码同步

```bash
git remote add upstream https://github.com/siyuan-note/siyuan.git   # 仅首次
git fetch upstream master
git rebase upstream/master free-sync
```

冲突处理原则：保持 `IsPaidUser()` 返回 `true`，并继续移除新增的 `Conf.GetUser() == nil` 拦截。
改完后重点复查两个已知拦截位置：`checkSync()`（sync.go）与 `checkAssetDownloadAccess()`（asset_download.go）。

## 构建流程

### 1. 前端

```bash
cd app && pnpm install --registry=https://registry.npmmirror.com && pnpm run build
```

产物在 `app/stage`（同时生成 `appearance`、`guide`）。

### 2. 内核（必须在 Alpine/musl 环境编译，glibc 二进制在官方 Alpine 镜像里无法启动）

```bash
docker run --rm -v "$PWD":/src -w /src/kernel -e CGO_ENABLED=1 \
  -e GOPROXY=https://goproxy.cn,direct golang:1.26-alpine \
  sh -c "sed -i 's|dl-cdn.alpinelinux.org|mirrors.aliyun.com|g' /etc/apk/repositories; \
         apk add --no-cache gcc musl-dev && \
         go build -tags 'fts5 sqlcipher' -ldflags '-s -w'"
```

### 3. Docker 镜像

**不要**在仓库根目录直接 `docker build`：根目录 `.dockerignore` 会过滤 `app/stage/build`（前端产物），
导致镜像里混入官方旧 UI。使用本分支提供的脚本，它会先组装干净的独立构建上下文：

```bash
chmod +x scripts/build-docker-thin.sh
./scripts/build-docker-thin.sh 3.8.10        # 版本号与 kernel/util/working.go 的 Ver 保持一致
```

镜像内旧前端/主题会被清除，官方镜像的 `stage/ocr`（OCR 运行时与模型）、entrypoint 全部保留复用。

### 4. 发布与部署

```bash
docker tag siyuan-modified:3.8.10 ghcr.io/parrrdo/siyuan:3.8.10-free
docker login ghcr.io -u Parrrdo            # 使用具有 write:packages 的 Token
docker push ghcr.io/parrrdo/siyuan:3.8.10-free
```

服务器（Netcup 152.53.36.109，/opt/siyuan/docker-compose.yml）：

```bash
cd /opt/siyuan && docker compose pull && docker compose up -d
```

### 5. 验证要点（2026-11-11 部署时已全部通过）

- `/api/system/version` 返回编译版本
- 未登录状态下：设置 → Account & Sync → Cloud storage service provider 切到 S3/WebDAV 无订阅拦截
- S3 的 "Sync service configuration" 子对话框可打开，Endpoint/AK/SK/Bucket 等字段均可编辑
