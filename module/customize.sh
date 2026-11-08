#!/system/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
[ "$KSU" = true ] || abort '! 请在 KernelSU 管理器中安装。'
MODDIR=$MODPATH
. "$MODDIR/common.sh"
ds_target_supported || abort "! $DS_REASON"
[ -x "$DS_KSUD" ] || abort '! 未找到 ksud。'
"$DS_KSUD" insmod --help >/dev/null 2>&1 || abort '! 此 ksud 不支持 insmod。'
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
ds_payload_valid || abort '! .ko 缺失或 SHA-256 校验失败。'
ui_print '- 设备：一加 Ace 3V (PJF110) / android14-6.1'
ui_print "- 内核：$DS_TARGET_RELEASE"
ui_print '- 开机时校验 BTF 指纹后加载；不匹配会记录原因并跳过。'
ui_print '- 实验性模块：激活后不能热卸载，禁用/卸载后需重启。'
ui_print '- 首次测试前请保存工作；异常重启可保留 /sys/fs/pstore 日志。'