# Emby Server for fnOS

Auto-build Emby Server packages for fnOS - Daily updates from official releases

## Download

从 [Releases](https://github.com/conversun/emby-fnos/releases) 下载最新的 `.fpk` 文件。

| 架构 | 文件名 | 适用设备 |
|------|--------|----------|
| x86_64 (amd64) | `embyserver_x.x.x.x_amd64.fpk` | Intel/AMD 处理器 |
| aarch64 (arm64) | `embyserver_x.x.x.x_arm64.fpk` | ARM64 处理器 |

## Install

1. 根据你的设备架构下载对应的 `.fpk` 文件
2. 在 fnOS 应用管理中选择「手动安装」
3. 上传 fpk 文件完成安装

## Auto Update

GitHub Actions 每天自动检查 [Emby 官方 Releases](https://github.com/MediaBrowser/Emby.Releases/releases)，有新版本时自动构建并发布。

## Open Source

本项目完全开源，仅从官方渠道下载原版软件并重新打包，**无任何后门或修改**。构建脚本和 CI 流程公开透明，欢迎审查。

## Local Build

```bash
# 自动检测架构，构建最新版本
./update_emby.sh

# 指定架构
./update_emby.sh --arch arm64
./update_emby.sh --arch amd64

# 指定版本
./update_emby.sh --arch arm64 4.9.3.0

# 查看帮助
./update_emby.sh --help
```

## Version Tags

Release 版本号规则：
- `v4.9.3.0` - 首次发布
- `v4.9.3.0-r2` - 同版本的打包修订（上游未更新时重新发布）

## Credits

- [Emby](https://emby.media/) - Media Server
- [FnDepot](https://github.com/Hxido-RXM/FnDepot) - Original fnOS package source
