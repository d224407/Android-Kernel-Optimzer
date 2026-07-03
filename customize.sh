#!/system/bin/sh

# Biến môi trường Magisk
SKIPUNZIP=0

# Hàm log tùy chỉnh
ui_print() {
    echo "$1"
}

# Cấp quyền cho tất cả file trong module
ui_print "- Setting permissions..."
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/action.sh 0 0 0755
set_perm $MODPATH/kernelenhance.sh 0 0 0755

# Kiểm tra syntax script
ui_print "- Checking script syntax..."
if ! sh -n $MODPATH/kernelenhance.sh 2>/dev/null; then
    ui_print "⚠️ Warning: Syntax error in kernelenhance.sh"
fi

# Chạy thử script một lần để kiểm tra (không bắt buộc)
ui_print "- Testing optimization..."
sh $MODPATH/kernelenhance.sh > /dev/null 2>&1 || true

ui_print "✅ Module installed successfully!"
ui_print "📱 Android Kernel Optimizer v1.0"