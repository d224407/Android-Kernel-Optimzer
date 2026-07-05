#!/system/bin/sh

MODDIR=${0%/*}

# Lấy thông tin kiến trúc CPU của thiết bị
ABI=$(getprop ro.product.cpu.abi)
ARCH=$(uname -m)

# Tiến hành kiểm tra và khởi chạy file nhị phân phù hợp
if [ "$ABI" = "arm64-v8a" ] || [[ "$ARCH" == *"64"* ]]; then
    if [ -f "$MODDIR/KernelEnhancer64" ]; then
        nohup "$MODDIR/KernelEnhancer64" > /dev/null 2>&1 &
        echo "KernelEnhancer: Running 64-bit binary" > /data/local/tmp/status.log
    elif [ -f "$MODDIR/KernelEnhancer32" ]; then
        nohup "$MODDIR/KernelEnhancer32" > /dev/null 2>&1 &
        echo "KernelEnhancer: 64-bit binary missing, falling back to 32-bit" > /data/local/tmp/status.log
    fi
else
    if [ -f "$MODDIR/KernelEnhancer32" ]; then
        nohup "$MODDIR/KernelEnhancer32" > /dev/null 2>&1 &
        echo "KernelEnhancer: Running 32-bit binary" > /data/local/tmp/status.log
    else
        echo "KernelEnhancer: Binary not found!" > /data/local/tmp/status.log
    fi
fi

echo "KernelEnhancer core routine triggered at $(date)" >> /data/local/tmp/status.log
