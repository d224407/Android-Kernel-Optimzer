#!/system/bin/sh

SKIPUNZIP=0

ui_print() { echo "$1"; }

ui_print "- Setting permissions..."
# Cấp quyền mặc định cho module
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/action.sh 0 0 0755

# Cấp quyền thực thi (executable) cho các file nhị phân 32-bit và 64-bit
if [ -f "$MODPATH/KernelEnhancer64" ]; then
    set_perm $MODPATH/KernelEnhancer64 0 0 0755
fi

if [ -f "$MODPATH/KernelEnhancer32" ]; then
    set_perm $MODPATH/KernelEnhancer32 0 0 0755
fi

ui_print "✅ Android Kernel & Touch Optimizer (Binary Mode) installed!"
