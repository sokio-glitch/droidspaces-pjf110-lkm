#!/system/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
MODDIR=${0%/*}
. "$MODDIR/common.sh"
ds_status '[待加载] 本次开机尚未加载；等待 service 阶段激活 namespace。'