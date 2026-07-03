#!/system/bin/sh

MODDIR=/data/adb/modules/$(basename $(dirname $0))

# Đợi một chút để hệ thống ổn định
sleep 2

# Chạy script tối ưu kernel
sh $MODDIR/kernelenhance.sh

echo "Manual optimize completed at $(date)" >> /data/local/tmp/status.log

# Thông báo trên màn hình (nếu có Magisk Manager UI)
ui_print "✅ Kernel optimized successfully!"