#!/system/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Single-device loader for the OnePlus PJF110 (Ace 3V) android14-6.1 kernel.
# MODDIR is supplied by the entry script (or MODPATH during installation).

DS_TARGET_RELEASE="6.1.141-android14-11-o-g16e6ef702577"
DS_TARGET_BTF_SHA256="a86cf0aa22e5607cd8ff7607a5ee1955d2e7ece5223b474d211d34df8708bee4"
DS_PAYLOAD="droidspaces_ns-pjf110.ko"
DS_BTF=/sys/kernel/btf/vmlinux
DS_MODULE_SYS=/sys/module/droidspaces_ns
DS_PROC_NS=/proc/self/ns
DS_KSUD=/data/adb/ksud
[ -x "$DS_KSUD" ] || DS_KSUD=/data/adb/ksu/bin/ksud
export KSU_MODULE=droidspaces_pjf110

ds_status() {
    ds_message=$1
    printf '%s\n' "$ds_message"
    printf '%s\n' "$ds_message" > "$MODDIR/status.txt"
    if [ -x "$DS_KSUD" ] && "$DS_KSUD" module config set --temp override.description "$ds_message"; then
        return 0
    fi
    DS_DESCRIPTION="$ds_message" awk '
        !/^description=/ { print }
        END { print "description=" ENVIRON["DS_DESCRIPTION"] }
    ' "$MODDIR/module.prop" > "$MODDIR/module.prop.tmp" &&
        cat "$MODDIR/module.prop.tmp" > "$MODDIR/module.prop"
    rm -f "$MODDIR/module.prop.tmp"
}

ds_target_supported() {
    DS_REASON='仅支持 ARM64。'
    [ "$(uname -m)" = aarch64 ] || return 1
    DS_REASON="内核版本不匹配：需要 $DS_TARGET_RELEASE，当前 $(uname -r)"
    [ "$(uname -r)" = "$DS_TARGET_RELEASE" ] || return 1
    DS_REASON=''
    return 0
}

ds_active() {
    [ "$(cat "$DS_MODULE_SYS/parameters/activate" 2>/dev/null)" = Y ] &&
    [ -e "$DS_PROC_NS/pid" ] && [ -e "$DS_PROC_NS/pid_for_children" ] &&
    [ -e "$DS_PROC_NS/ipc" ]
}

ds_payload_valid() {
    [ -s "$MODDIR/kernel/$DS_PAYLOAD" ] &&
    (cd "$MODDIR/kernel" && sha256sum -c SHA256SUMS)
}

# Exact-kernel gate: the module was compiled for this precise vendor BTF.
ds_btf_matches() {
    [ -r "$DS_BTF" ] || { printf 'BTF unreadable.\n'; return 1; }
    ds_actual=$(sha256sum "$DS_BTF" | awk '{print $1}')
    if [ "$ds_actual" = "$DS_TARGET_BTF_SHA256" ]; then
        return 0
    fi
    printf 'BTF fingerprint mismatch: got %s\n' "$ds_actual"
    return 1
}

ds_load() {
    if ! ds_target_supported; then
        ds_status "[不支持] ${DS_REASON}；未加载。"
        return 1
    fi
    if ds_active; then
        ds_status "[已加载] PID / IPC / SysV / mqueue namespace 已激活（本次开机）；更换 .ko 需重启。"
        return 0
    fi
    if [ -d "$DS_MODULE_SYS" ]; then
        ds_status '[加载失败] droidspaces_ns 已存在但未激活；请重启后重试。'
        return 1
    fi
    if [ ! -x "$DS_KSUD" ]; then
        ds_status '[加载失败] 找不到可执行的 ksud；请检查 KernelSU。'
        return 1
    fi
    if ! ds_payload_valid; then
        ds_status '[加载失败] .ko 缺失或 SHA-256 校验失败；请重新安装完整 ZIP。'
        return 1
    fi
    if ! ds_btf_matches; then
        ds_status "[不兼容] 内核 BTF 指纹与验证目标不符，未加载；详见 load.log。"
        return 1
    fi
    ds_status '[加载中] 正在激活 PID / IPC / SysV / mqueue namespace。'
    "$DS_KSUD" insmod "$MODDIR/kernel/$DS_PAYLOAD" activate=1
    ds_result=$?
    if [ "$ds_result" -ne 0 ]; then
        ds_status "[加载失败] ksud insmod 返回 ${ds_result}；详见 load.log。"
        return 1
    fi
    if ! ds_active; then
        ds_status '[加载失败] insmod 成功但激活检查未通过；详见 load.log。'
        return 1
    fi
    ds_status '[已加载] PID / IPC / SysV / mqueue namespace 已激活；更换 .ko 需重启。'
}