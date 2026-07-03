#!/system/bin/sh

# ==============================================
# KernelEnhancer – Android Kernel Tuning Script
# Dịch từ KernelEnhancer32/64.c, bỏ SHA‑256 check
# ==============================================

LOG_FILE="/data/local/tmp/KernelEnhancer.log"
LOG_SDCARD="/sdcard/KernelEnhancer.log"

# Đảm bảo thư mục log tồn tại
mkdir -p /data/local/tmp 2>/dev/null
touch "$LOG_FILE" "$LOG_SDCARD" 2>/dev/null

# Hàm ghi log
log() {
    local msg="[$(date +'%H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null
    echo "$msg" >> "$LOG_SDCARD" 2>/dev/null
    echo "$msg"
}

# Hàm ghi giá trị vào file sysfs (tự động thử quyền)
write() {
    local file="$1"
    local value="$2"
    if [ ! -f "$file" ]; then
        return 1
    fi
    # Thử ghi trực tiếp, nếu không được thì thử chmod
    if ! echo "$value" > "$file" 2>/dev/null; then
        chmod 644 "$file" 2>/dev/null
        echo "$value" > "$file" 2>/dev/null || return 1
    fi
    return 0
}

# ----- 1. Chờ hệ thống boot hoàn tất -----
log "========== KernelEnhancer Started =========="

# Đợi boot_completed = 1
wait_count=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $wait_count -lt 30 ]; do
    sleep 2
    wait_count=$((wait_count + 1))
done

# Đợi boot animation dừng (tối đa 20 lần)
wait_count=0
while [ "$(getprop init.svc.bootanim)" != "stopped" ] && [ $wait_count -lt 20 ]; do
    sleep 2
    wait_count=$((wait_count + 1))
done

sleep 5
log "System ready, starting optimizations..."

# ----- 2. Bật tất cả các nhân CPU (online) -----
online_count=0
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    online="$cpu/online"
    if [ -f "$online" ]; then
        if write "$online" "1"; then
            online_count=$((online_count + 1))
        fi
    fi
done
log "CPU Online: $online_count cores activated"

# ----- 3. Đọc MemTotal và tính toán tham số VM -----
if [ -f "/proc/meminfo" ]; then
    mem_kb=$(grep -m1 MemTotal /proc/meminfo | awk '{print $2}')
    if [ -n "$mem_kb" ] && [ "$mem_kb" -gt 0 ]; then
        mem_mb=$((mem_kb / 1024))
        log "Memory detected: ${mem_mb}MB"
        
        # Đặt giá trị dựa trên dung lượng RAM
        if [ "$mem_mb" -lt 4096 ]; then
            swappiness=70; dirty_ratio=18; dirty_bg=5; vfs_pressure=50; watermark=149
        elif [ "$mem_mb" -lt 6144 ]; then
            swappiness=60; dirty_ratio=22; dirty_bg=6; vfs_pressure=60; watermark=177
        elif [ "$mem_mb" -lt 8192 ]; then
            swappiness=35; dirty_ratio=25; dirty_bg=8; vfs_pressure=60; watermark=191
        else
            swappiness=35; dirty_ratio=28; dirty_bg=10; vfs_pressure=55; watermark=209
        fi
        
        # Ghi các tham số VM
        write "/proc/sys/vm/swappiness" "$swappiness"
        write "/proc/sys/vm/dirty_ratio" "$dirty_ratio"
        write "/proc/sys/vm/dirty_background_ratio" "$dirty_bg"
        write "/proc/sys/vm/dirty_expire_centisecs" "1250"
        write "/proc/sys/vm/dirty_writeback_centisecs" "850"
        write "/proc/sys/vm/page-cluster" "0"
        write "/proc/sys/vm/vfs_cache_pressure" "$vfs_pressure"
        write "/proc/sys/vm/stat_interval" "21"
        write "/proc/sys/vm/watermark_scale_factor" "$watermark"
        write "/proc/sys/vm/zone_reclaim_mode" "0"
        log "VM tweaks applied (swappiness=$swappiness, watermark=$watermark)"
    fi
fi

# ----- 4. Scheduler -----
if [ -d "/proc/sys/kernel" ]; then
    write "/proc/sys/kernel/sched_downmigrate" "35 45"
    write "/proc/sys/kernel/sched_upmigrate" "50 60"
    write "/proc/sys/kernel/sched_util_clamp_min" "384"
    write "/proc/sys/kernel/sched_util_clamp_min_rt_default" "512"
    log "Scheduler tweaks applied"
fi

# ----- 5. STUNE (nếu có) -----
stune_path=""
if [ -d "/dev/stune" ]; then
    stune_path="/dev/stune"
elif [ -d "/sys/fs/cgroup/stune" ]; then
    stune_path="/sys/fs/cgroup/stune"
elif [ -d "/sys/fs/cgroup/cpu/stune" ]; then
    stune_path="/sys/fs/cgroup/cpu/stune"
fi

if [ -n "$stune_path" ]; then
    write "$stune_path/top-app/schedtune.boost" "3" 2>/dev/null
    write "$stune_path/top-app/schedtune.prefer_idle" "0" 2>/dev/null
    write "$stune_path/foreground/schedtune.boost" "0" 2>/dev/null
    write "$stune_path/background/schedtune.boost" "-10" 2>/dev/null
    log "STUNE Boost applied (path: $stune_path)"
fi

# ----- 6. CPU Boost (input_boost) -----
if [ -d "/sys/module/cpu_boost/parameters" ]; then
    boost_freq=""
    for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        freq_file="$cpu/cpufreq/cpuinfo_max_freq"
        if [ -f "$freq_file" ]; then
            max_freq=$(cat "$freq_file" 2>/dev/null)
            if [ -n "$max_freq" ] && [ "$max_freq" -gt 0 ]; then
                half=$((max_freq / 2))
                cpu_id=${cpu##*/cpu}
                boost_freq="$boost_freq cpu$cpu_id:$half"
            fi
        fi
    done
    boost_freq=${boost_freq# }
    
    if [ -n "$boost_freq" ]; then
        write "/sys/module/cpu_boost/parameters/input_boost_freq" "$boost_freq"
        write "/sys/module/cpu_boost/parameters/sched_boost_on_input" "1"
        write "/sys/module/cpu_boost/parameters/input_boost_ms" "50"
        write "/sys/module/cpu_boost/parameters/input_boost_duration" "50"
        log "Input Boost applied: $boost_freq"
    fi
fi

# ----- 7. I/O Scheduler và Queue -----
io_optimized=0
for block in /sys/block/*; do
    [ -d "$block" ] || continue
    queue="$block/queue"
    [ -d "$queue" ] || continue
    
    scheduler="$queue/scheduler"
    if [ -f "$scheduler" ]; then
        if grep -q "mq-deadline" "$scheduler" 2>/dev/null; then
            write "$scheduler" "mq-deadline"
            iosched="$queue/iosched"
            if [ -d "$iosched" ]; then
                write "$iosched/read_expire" "50"
                write "$iosched/write_expire" "150"
                write "$iosched/writes_starved" "1"
                write "$iosched/front_merges" "0"
                io_optimized=$((io_optimized + 1))
            fi
        elif grep -q "cfq" "$scheduler" 2>/dev/null; then
            write "$scheduler" "cfq"
            iosched="$queue/iosched"
            if [ -d "$iosched" ]; then
                write "$iosched/slice_idle" "0"
                write "$iosched/low_latency" "1"
                write "$iosched/quantum" "8"
                write "$iosched/group_idle" "0"
                write "$iosched/back_seek_penalty" "1"
                write "$iosched/back_seek_max" "1000000000"
                write "$iosched/slice_sync" "85"
                write "$iosched/slice_async" "85"
                write "$iosched/slice_async_rq" "2"
                write "$iosched/slice_async_us" "75000"
                write "$iosched/target_latency_us" "20000"
                write "$iosched/fifo_expire_sync" "100"
                write "$iosched/fifo_expire_async" "250"
                io_optimized=$((io_optimized + 1))
            fi
        fi
    fi
    
    write "$queue/read_ahead_kb" "256"
    write "$queue/nr_requests" "64"
    write "$queue/rq_affinity" "2"
    write "$queue/iostats" "0"
    write "$queue/add_random" "0"
done

# ZRAM riêng biệt
for block in /sys/block/zram*; do
    queue="$block/queue"
    if [ -d "$queue" ]; then
        write "$queue/read_ahead_kb" "32"
        io_optimized=$((io_optimized + 1))
    fi
done
log "IO tweaks applied ($io_optimized devices optimized)"

# ----- 8. Filesystem -----
if [ -d "/proc/sys/fs" ]; then
    write "/proc/sys/fs/lease-break-time" "10"
    write "/proc/sys/fs/dir-notify-enable" "1"
    write "/proc/sys/fs/inotify/max_user_watches" "1048576"
    write "/proc/sys/fs/aio-max-nr" "1048576"
    log "Filesystem tweaks applied"
fi

# ----- 9. Workqueue -----
if [ -d "/sys/module/workqueue/parameters" ]; then
    write "/sys/module/workqueue/parameters/disable_numa" "N"
    write "/sys/module/workqueue/parameters/debug_force_rr_cpu" "0"
    log "Workqueue tweaks applied"
fi

# ----- 10. GED (nếu có) -----
if [ -f "/sys/kernel/ged/hal/loading_base_dvfs_step" ]; then
    write "/sys/kernel/ged/hal/loading_base_dvfs_step" "1"
    log "GED DVFS Step applied"
fi

# ----- 11. CPU Governor: chuyển sang schedutil và tinh chỉnh -----
cpu_policies=0
schedutil_applied=0

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$policy" ] || continue
    cpu_policies=$((cpu_policies + 1))
    
    avail="$policy/scaling_available_governors"
    gov="$policy/scaling_governor"
    [ -f "$avail" ] || continue
    
    if grep -q "schedutil" "$avail" 2>/dev/null; then
        current=$(cat "$gov" 2>/dev/null)
        if [ "$current" != "schedutil" ]; then
            write "$gov" "schedutil"
            sleep 1
        fi
        
        sdir=""
        if [ -d "$policy/schedutil" ]; then
            sdir="$policy/schedutil"
        else
            sdir="$policy"
        fi
        
        write "$sdir/rate_limit_us" "500"
        write "$sdir/up_rate_limit_us" "500"
        write "$sdir/down_rate_limit_us" "500"
        write "$sdir/hispeed_load" "90"
        
        schedutil_applied=$((schedutil_applied + 1))
        log "CPU $cpu_policies: schedutil governor applied"
    fi
done

if [ $schedutil_applied -gt 0 ]; then
    log "CPU tweaks applied (Harmonized Profile) - $schedutil_applied policies"
fi

# ----- Kết thúc -----
log "========== KernelEnhancer Completed =========="

# Ghi file trạng thái
echo "KernelEnhancer completed at $(date)" > /data/local/tmp/kernel_optimized