#!/system/bin/sh

MODDIR=${0%/*}

# Find binary
ARCH=$(getprop ro.product.cpu.abi)
case "$ARCH" in
    arm64-v8a|arm64)
        BIN="$MODDIR/system/bin/kernelenhancer_64"
        ;;
    armeabi-v7a|armeabi)
        BIN="$MODDIR/system/bin/kernelenhancer_32"
        ;;
    *)
        [ -f "$MODDIR/system/bin/kernelenhancer_64" ] && BIN="$MODDIR/system/bin/kernelenhancer_64" || BIN="$MODDIR/system/bin/kernelenhancer_32"
        ;;
esac

# Run
"$BIN"

echo "Manual optimize completed at $(date)" >> /data/local/tmp/status.log
ui_print "✅ Done!"