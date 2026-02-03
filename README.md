# Emby Server for fnOS

Auto-build Emby Server packages for fnOS - Daily updates from official releases

## Download

从 [Releases](https://github.com/conversun/emby-fnos/releases) 下载最新的 `.fpk` 文件。

## Install

1. 下载 `embyserver_x.x.x.x_amd64.fpk`
2. 在 fnOS 应用管理中选择「手动安装」
3. 上传 fpk 文件完成安装

## Auto Update

GitHub Actions 每天自动检查 [Emby 官方 Releases](https://github.com/MediaBrowser/Emby.Releases/releases)，有新版本时自动构建并发布。

## Architecture

- **Platform**: fnOS (飞牛私有云)
- **Architecture**: x86_64 (amd64)

## Credits

- [Emby](https://emby.media/) - Media Server
- [FnDepot](https://github.com/Hxido-RXM/FnDepot) - Original fnOS package source
