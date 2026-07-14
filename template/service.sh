#!/system/bin/sh

MODDIR=${0%/*}

# Detect architecture
ARCH=$(getprop ro.product.cpu.abi)
case "$ARCH" in
    arm64-v8a|arm64)
        BIN="$MODDIR/system/bin/kernelenhancer_64"
        ;;
    armeabi-v7a|armeabi)
        BIN="$MODDIR/system/bin/kernelenhancer_32"
        ;;
    *)
        # Fallback: try both
        if [ -f "$MODDIR/system/bin/kernelenhancer_64" ]; then
            BIN="$MODDIR/system/bin/kernelenhancer_64"
        else
            BIN="$MODDIR/system/bin/kernelenhancer_32"
        fi
        ;;
esac

# Run in background
nohup "$BIN" > /dev/null 2>&1 &

echo "KernelEnhancer started at $(date)" > /data/local/tmp/status.log