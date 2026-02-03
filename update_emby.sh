#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_DIR="$SCRIPT_DIR/package"
WORK_DIR="/tmp/emby_update_$$"
EMBY_VERSION="${1:-latest}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

get_latest_version() {
    info "获取最新版本信息..."
    
    if [ "$EMBY_VERSION" = "latest" ] || [ "$EMBY_VERSION" = "beta" ]; then
        local html=$(curl -sL "https://github.com/MediaBrowser/Emby.Releases/releases" 2>/dev/null)
        
        if [ "$EMBY_VERSION" = "latest" ]; then
            EMBY_VERSION=$(echo "$html" | grep -oE '(releases/tag/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[^"]*|Latest)' | grep -B1 "^Latest$" | head -1 | sed 's|releases/tag/||')
        else
            EMBY_VERSION=$(echo "$html" | grep -oE 'releases/tag/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 | sed 's|releases/tag/||')
        fi
    fi
    
    [ -z "$EMBY_VERSION" ] && error "无法获取版本信息，请手动指定: $0 4.9.3.0"
    
    EMBY_VERSION_CLEAN="${EMBY_VERSION%-beta}"
    info "目标版本: $EMBY_VERSION"
}

download_deb() {
    local deb_url="https://github.com/MediaBrowser/Emby.Releases/releases/download/${EMBY_VERSION}/emby-server-deb_${EMBY_VERSION_CLEAN}_amd64.deb"
    
    info "下载: $deb_url"
    mkdir -p "$WORK_DIR"
    
    curl -L -f -o "$WORK_DIR/emby-server.deb" "$deb_url" || error "下载失败"
    info "下载完成: $(du -h "$WORK_DIR/emby-server.deb" | cut -f1)"
}

extract_deb() {
    info "解压 deb 包..."
    cd "$WORK_DIR"
    ar -x emby-server.deb
    mkdir -p extracted
    tar -xf data.tar.xz -C extracted
    [ -d "extracted/opt/emby-server" ] || error "deb 包结构异常"
}

build_app_tgz() {
    info "构建 app.tgz..."
    
    local src="$WORK_DIR/extracted/opt/emby-server"
    local dst="$WORK_DIR/app_root"
    mkdir -p "$dst"
    
    cp -r "$src/bin" "$src/etc" "$src/extra" "$src/lib" "$src/licenses" "$src/share" "$src/system" "$dst/"
    mkdir -p "$dst/config" "$dst/ui/images"
    
    tar -xzf "$PKG_DIR/app.tgz" -C "$dst" EmbyServer.sc config 2>/dev/null || {
        cat > "$dst/EmbyServer.sc" << 'EOF'
[EmbyServer]
title="Emby Server"
desc="Emby Web UI"
port_forward="yes"
src.ports="8096,8920/tcp"
dst.ports="8096,8920/tcp"
EOF
        cat > "$dst/config/privilege" << 'EOF'
{
    "defaults": {"run-as": "root"},
    "username": "EmbyServer",
    "groupname": "EmbyServer",
    "join-groups": ["video","render"]
}
EOF
        cat > "$dst/config/resource" << 'EOF'
{
    "port-config": {"protocol-file": "EmbyServer.sc"},
    "data-share": {"shares": [{"name": "EmbyServer", "permission": {"rw": ["EmbyServer"]}}]}
}
EOF
    }
    
    cat > "$dst/bin/emby-server" << 'SCRIPT'
#!/bin/sh
APP_NAME=embyserver
APP_DIR=/var/apps/embyserver/target
APP_DATA_DIR=$1
PID_FILE="$APP_DATA_DIR"/$APP_NAME.pid

export AMDGPU_IDS=$APP_DIR/extra/share/libdrm/amdgpu.ids
[ -z "$EMBY_DATA" ] && export EMBY_DATA=/var/lib/emby
export FONTCONFIG_PATH=$APP_DIR/etc/fonts
export LD_LIBRARY_PATH=$APP_DIR/lib:$APP_DIR/extra/lib
export LIBVA_DRIVERS_PATH=$APP_DIR/extra/lib/dri
export OCL_ICD_VENDORS=$APP_DIR/extra/etc/OpenCL/vendors
export PATH=$APP_DIR/bin:"$PATH"
export PCI_IDS_PATH=$APP_DIR/share/hwdata/pci.ids
export SSL_CERT_FILE=$APP_DIR/etc/ssl/certs/ca-certificates.crt
export XDG_CACHE_HOME=$EMBY_DATA/cache
export NEOReadDebugKeys=1
export OverrideGpuAddressSpace=48

cd $APP_DIR || exit 1
exec $APP_DIR/system/EmbyServer \
  -programdata $APP_DATA_DIR \
  -ffdetect $APP_DIR/bin/ffdetect \
  -ffmpeg $APP_DIR/bin/ffmpeg \
  -ffprobe $APP_DIR/bin/ffprobe \
  -restartexitcode 3 \
  -nolocalportconfig \
  -ignore_vaapi_enabled_flag \
  -pidfile "$PID_FILE" \
  -defaultdirectory /var/apps/$APP_NAME/shares
SCRIPT
    chmod +x "$dst/bin/emby-server"
    
    cd "$dst"
    tar -czf "$WORK_DIR/app.tgz" .
    info "app.tgz: $(du -h "$WORK_DIR/app.tgz" | cut -f1)"
}

update_manifest() {
    info "更新 manifest..."
    local checksum=$(md5 -q "$WORK_DIR/app.tgz" 2>/dev/null || md5sum "$WORK_DIR/app.tgz" | cut -d' ' -f1)
    
    sed -i.tmp "s/^version.*=.*/version         = ${EMBY_VERSION_CLEAN}/" "$PKG_DIR/manifest"
    sed -i.tmp "s/^checksum.*=.*/checksum        = ${checksum}/" "$PKG_DIR/manifest"
    rm -f "$PKG_DIR/manifest.tmp"
}

apply_update() {
    cp "$WORK_DIR/app.tgz" "$PKG_DIR/app.tgz"
}

build_fpk() {
    local fpk_name="embyserver_${EMBY_VERSION_CLEAN}.fpk"
    info "打包 $fpk_name..."
    
    cd "$PKG_DIR"
    tar -czf "$SCRIPT_DIR/$fpk_name" *
    
    info "生成: $SCRIPT_DIR/$fpk_name ($(du -h "$SCRIPT_DIR/$fpk_name" | cut -f1))"
}

show_help() {
    cat << EOF
用法: $0 [版本号|latest|beta]

示例:
  $0              # 最新稳定版
  $0 4.9.3.0      # 指定版本
  $0 beta         # 最新 beta
EOF
}

main() {
    [ "$1" = "-h" ] || [ "$1" = "--help" ] && { show_help; exit 0; }
    
    echo "========================================"
    echo "  Emby Server fnOS Package Builder"
    echo "========================================"
    echo
    
    for cmd in curl ar tar sed; do
        command -v $cmd &>/dev/null || error "缺少依赖: $cmd"
    done
    
    [ -f "$PKG_DIR/app.tgz" ] && [ -f "$PKG_DIR/manifest" ] || error "找不到 package 目录"
    
    local current_version=$(grep "^version" "$PKG_DIR/manifest" | awk -F'=' '{print $2}' | tr -d ' ')
    info "当前版本: $current_version"
    
    get_latest_version
    
    if [ "$current_version" = "$EMBY_VERSION_CLEAN" ]; then
        warn "已是最新版本"
        read -p "强制重新构建? [y/N] " -n 1 -r; echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi
    
    download_deb
    extract_deb
    build_app_tgz
    update_manifest
    apply_update
    build_fpk
    
    echo
    info "完成: $current_version -> $EMBY_VERSION_CLEAN"
}

main "$@"
