#!/system/bin/sh

MODDIR=${0%/*}

# Chờ hệ thống boot hoàn tất
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done
sleep 10

# Chạy script tối ưu kernel (chạy ngầm, không chặn tiến trình)
nohup sh $MODDIR/kernelenhance.sh > /dev/null 2>&1 &

echo "KernelEnhancer started at $(date)" > /data/local/tmp/status.log