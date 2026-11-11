# free-sync 分支说明

本分支在官方 [siyuan-note/siyuan](https://github.com/siyuan-note/siyuan) 基础上做了 4 处最小改动，
使 S3 / WebDAV / 本地目录同步在**未登录社区账号**的情况下也可用。

## 改动清单

| 文件 | 改动 |
| --- | --- |
| `kernel/model/conf.go` | `IsPaidUser()` 直接返回 `true`（核心校验，5 处调用点全部走它） |
| `kernel/model/sync.go` | 移除 `checkSync()` 中 `nil == Conf.GetUser()` 的登录拦截 |
| `kernel/model/asset_download.go` | `checkAssetDownloadAccess()` 去掉 `Conf.GetUser() == nil` 条件 |
| `app/src/util/needSubscribe.ts` | 前端 `isPaidUser()` 返回 `true`，设置界面正常显示 S3/WebDAV |

官方云端同步（ProviderSiYuan）仍走 `IsSubscriber()`，未登录时依旧不可用，不影响原有逻辑。

## 与官方源码同步

```bash
git remote add upstream https://github.com/siyuan-note/siyuan.git   # 仅首次
git fetch upstream master
git diff master^..master --stat          # 查看官方新提交
git rebase upstream/master free-sync     # 变基，冲突通常出现在上述 4 个文件
```

冲突处理原则：保持 `IsPaidUser()` 返回 `true`，并继续移除新增的 `Conf.GetUser() == nil` 拦截。

## 构建

前端与内核需在 **musl/Alpine** 环境下编译（官方镜像基于 Alpine），否则二进制因 glibc 依赖无法启动：

```bash
# 前端
cd app && pnpm install && pnpm run build

# 内核（在 alpine 容器内，CGO + fts5 + sqlcipher）
docker run --rm -v "$PWD":/src -w /src/kernel -e CGO_ENABLED=1 golang:1.26-alpine \
  sh -c "apk add --no-cache gcc musl-dev && go build -tags 'fts5 sqlcipher' -ldflags '-s -w'"

# 镜像（薄构建：复用官方 OCR 运行时与 entrypoint）
docker build -f Dockerfile.thin -t siyuan-modified:<version> .
```
