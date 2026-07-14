#!/system/bin/sh

SKIPUNZIP=0

ui_print() { echo "$1"; }

ui_print "- Setting permissions..."
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/system/bin/kernelenhancer_32 0 0 0755
set_perm $MODPATH/system/bin/kernelenhancer_64 0 0 0755
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/action.sh 0 0 0755

ui_print "- Checking binaries..."
[ -f "$MODPATH/system/bin/kernelenhancer_32" ] && ui_print "  ARMv7 binary OK"
[ -f "$MODPATH/system/bin/kernelenhancer_64" ] && ui_print "  ARMv8 binary OK"

ui_print "✅ Done!"