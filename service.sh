#!/system/bin/sh

MODDIR=${0%/*}

# Chạy script tối ưu (không cần chờ boot vì đã có trong script)
nohup sh $MODDIR/kernelenhance.sh > /dev/null 2>&1 &

echo "KernelEnhancer started at $(date)" > /data/local/tmp/status.log
