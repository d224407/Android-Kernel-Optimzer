#!/system/bin/sh

# ==============================================
# KernelEnhancer – Android Kernel & Touch Optimizer
# Gộp từ Kernelenhance + Service.sh (Touch/Display)
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

# Hàm ghi giá trị vào file sysfs
write() {
    local file="$1"
    local value="$2"
    [ ! -f "$file" ] && return 1
    if ! echo "$value" > "$file" 2>/dev/null; then
        chmod 644 "$file" 2>/dev/null
        echo "$value" > "$file" 2>/dev/null || return 1
    fi
    return 0
}

# ==============================================
# PHẦN 1: CHỜ HỆ THỐNG KHỞI ĐỘNG
# ==============================================
log "========== KernelEnhancer Started =========="

# Đợi boot_completed
wait_count=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $wait_count -lt 30 ]; do
    sleep 2
    wait_count=$((wait_count + 1))
done

# Đợi boot animation dừng
wait_count=0
while [ "$(getprop init.svc.bootanim)" != "stopped" ] && [ $wait_count -lt 20 ]; do
    sleep 2
    wait_count=$((wait_count + 1))
done

sleep 5
log "System ready, starting optimizations..."

# ==============================================
# PHẦN 2: KERNEL TUNING (từ Kernelenhance)
# ==============================================

# ----- 2.1 Bật CPU -----
online_count=0
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    online="$cpu/online"
    [ -f "$online" ] && write "$online" "1" && online_count=$((online_count + 1))
done
log "CPU Online: $online_count cores activated"

# ----- 2.2 VM Parameters dựa trên RAM -----
if [ -f "/proc/meminfo" ]; then
    mem_kb=$(grep -m1 MemTotal /proc/meminfo | awk '{print $2}')
    if [ -n "$mem_kb" ] && [ "$mem_kb" -gt 0 ]; then
        mem_mb=$((mem_kb / 1024))
        log "Memory detected: ${mem_mb}MB"
        
        if [ "$mem_mb" -lt 4096 ]; then
            swappiness=70; dirty_ratio=18; dirty_bg=5; vfs_pressure=50; watermark=149
        elif [ "$mem_mb" -lt 6144 ]; then
            swappiness=60; dirty_ratio=22; dirty_bg=6; vfs_pressure=60; watermark=177
        elif [ "$mem_mb" -lt 8192 ]; then
            swappiness=35; dirty_ratio=25; dirty_bg=8; vfs_pressure=60; watermark=191
        else
            swappiness=35; dirty_ratio=28; dirty_bg=10; vfs_pressure=55; watermark=209
        fi
        
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

# ----- 2.3 Scheduler -----
write "/proc/sys/kernel/sched_downmigrate" "35 45"
write "/proc/sys/kernel/sched_upmigrate" "50 60"
write "/proc/sys/kernel/sched_util_clamp_min" "384"
write "/proc/sys/kernel/sched_util_clamp_min_rt_default" "512"
log "Scheduler tweaks applied"

# ----- 2.4 STUNE (nếu có) -----
stune_path=""
[ -d "/dev/stune" ] && stune_path="/dev/stune"
[ -z "$stune_path" ] && [ -d "/sys/fs/cgroup/stune" ] && stune_path="/sys/fs/cgroup/stune"
[ -z "$stune_path" ] && [ -d "/sys/fs/cgroup/cpu/stune" ] && stune_path="/sys/fs/cgroup/cpu/stune"

if [ -n "$stune_path" ]; then
    write "$stune_path/top-app/schedtune.boost" "3" 2>/dev/null
    write "$stune_path/top-app/schedtune.prefer_idle" "0" 2>/dev/null
    write "$stune_path/foreground/schedtune.boost" "0" 2>/dev/null
    write "$stune_path/background/schedtune.boost" "-10" 2>/dev/null
    log "STUNE Boost applied"
fi

# ----- 2.5 CPU Boost (input_boost) -----
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
    [ -n "$boost_freq" ] && {
        write "/sys/module/cpu_boost/parameters/input_boost_freq" "$boost_freq"
        write "/sys/module/cpu_boost/parameters/sched_boost_on_input" "1"
        write "/sys/module/cpu_boost/parameters/input_boost_ms" "50"
        write "/sys/module/cpu_boost/parameters/input_boost_duration" "50"
        log "Input Boost applied"
    }
fi

# ----- 2.6 I/O Scheduler và Queue -----
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

# ZRAM
for block in /sys/block/zram*; do
    queue="$block/queue"
    [ -d "$queue" ] && write "$queue/read_ahead_kb" "32" && io_optimized=$((io_optimized + 1))
done
log "IO tweaks applied ($io_optimized devices optimized)"

# ----- 2.7 Filesystem -----
write "/proc/sys/fs/lease-break-time" "10"
write "/proc/sys/fs/dir-notify-enable" "1"
write "/proc/sys/fs/inotify/max_user_watches" "1048576"
write "/proc/sys/fs/aio-max-nr" "1048576"
log "Filesystem tweaks applied"

# ----- 2.8 Workqueue -----
write "/sys/module/workqueue/parameters/disable_numa" "N"
write "/sys/module/workqueue/parameters/debug_force_rr_cpu" "0"
log "Workqueue tweaks applied"

# ----- 2.9 GED -----
write "/sys/kernel/ged/hal/loading_base_dvfs_step" "1"
log "GED DVFS Step applied"

# ----- 2.10 CPU Governor: schedutil -----
schedutil_applied=0
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$policy" ] || continue
    avail="$policy/scaling_available_governors"
    [ -f "$avail" ] || continue
    
    if grep -q "schedutil" "$avail" 2>/dev/null; then
        gov="$policy/scaling_governor"
        current=$(cat "$gov" 2>/dev/null)
        [ "$current" != "schedutil" ] && write "$gov" "schedutil" && sleep 1
        
        sdir=""
        [ -d "$policy/schedutil" ] && sdir="$policy/schedutil" || sdir="$policy"
        
        write "$sdir/rate_limit_us" "500"
        write "$sdir/up_rate_limit_us" "500"
        write "$sdir/down_rate_limit_us" "500"
        write "$sdir/hispeed_load" "90"
        schedutil_applied=$((schedutil_applied + 1))
    fi
done
[ $schedutil_applied -gt 0 ] && log "CPU tweaks applied (Harmonized Profile) - $schedutil_applied policies"

# ==============================================
# PHẦN 3: TOUCH / DISPLAY OPTIMIZATION (từ service.sh cũ)
# ==============================================

log "========== Touch/Display Optimizations =========="

# Lấy tần số quét màn hình
refresh_rate="$(dumpsys display 2>/dev/null | grep -Eo 'fps=[^.]+' | cut -f2 -d= | sort -n | uniq | tail -n1)"
[ -z "$refresh_rate" ] && refresh_rate=60
log "Refresh rate: ${refresh_rate}Hz"

frame_time=$((1000000000 / refresh_rate))
early_app_duration=$(awk -v ft="$frame_time" 'BEGIN {printf "%d", ft*1.95+1}')
early_sf_duration=$(awk -v ft="$frame_time" 'BEGIN {printf "%d", ft*1.48+1}')
early_gl_app_phase_offset=$(awk -v ft="$frame_time" 'BEGIN {printf "%d", -ft*2.8-1}')
early_phase_offset=$(awk -v ft="$frame_time" 'BEGIN {printf "%d", -ft*2.3-1}')
late_app_offset=$(awk -v ft="$frame_time" 'BEGIN {printf "%d", ft*0.1}')
late_sf_offset=$(awk -v ft="$frame_time" 'BEGIN {printf "%d", ft*0.15}')
total_ram="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
cpu_cores=$(grep -c ^processor /proc/cpuinfo)

# ----- 3.1 Surface Flinger (SF) Tweaks -----
setprop debug.sf.early.app.duration "$early_app_duration"
setprop debug.sf.earlyGl.app.duration "$early_app_duration"
setprop debug.sf.early.sf.duration "$early_sf_duration"
setprop debug.sf.earlyGl.sf.duration "$early_sf_duration"
setprop debug.sf.early_app_phase_offset_ns "$early_gl_app_phase_offset"
setprop debug.sf.high_fps_early_app_phase_offset_ns "$early_gl_app_phase_offset"
setprop debug.sf.early_gl_app_phase_offset_ns "$early_gl_app_phase_offset"
setprop debug.sf.early_gl_phase_offset_ns "$early_gl_app_phase_offset"
setprop debug.sf.early_phase_offset_ns "$early_phase_offset"
setprop debug.sf.high_fps_early_phase_offset_ns "$early_phase_offset"
setprop debug.sf.high_fps_early_sf_phase_offset_ns "$early_phase_offset"
setprop debug.sf.high_fps_late_sf_phase_offset_ns "$late_sf_offset"
setprop debug.sf.high_fps_late_app_phase_offset_ns "$late_app_offset"
setprop debug.sf.late.app.duration "$late_app_offset"
setprop debug.sf.late.sf.duration "$late_sf_offset"
setprop debug.sf.frame_rate_multiple_threshold "$refresh_rate"
setprop debug.sf.use_phase_offsets_as_durations 1
setprop debug.sf.predict_hwc_composition_strategy 1
setprop debug.sf.no_vsyncs_on_screen_off true
setprop debug.sf.multithreaded_present true
setprop debug.sf.luma_sampling 0
log "SurfaceFlinger tweaks applied"

# ----- 3.2 Surface Flinger Properties -----
resetprop -n ro.surface_flinger.game_default_frame_rate_override "$refresh_rate"
resetprop -n ro.surface_flinger.enable_adpf_cpu_hint true
resetprop -n ro.surface_flinger.enable_present_time_offset true
resetprop -n ro.surface_flinger.uclamp.min 256
resetprop -n ro.surface_flinger.set_idle_timer_ms 40
resetprop -n ro.surface_flinger.set_touch_timer_ms 60
resetprop -n ro.surface_flinger.set_display_power_timer_ms 300
log "SurfaceFlinger props applied"

# ----- 3.3 Dalvik / ART Tuning dựa trên RAM -----
if [ "$total_ram" -le 3072 ]; then
    heapstartsize=12m; heapgrowthlimit=128m; heapsize=384m; heaptargetutilization=0.7
elif [ "$total_ram" -le 4096 ]; then
    heapstartsize=16m; heapgrowthlimit=192m; heapsize=512m; heaptargetutilization=0.75
elif [ "$total_ram" -le 6144 ]; then
    heapstartsize=24m; heapgrowthlimit=256m; heapsize=768m; heaptargetutilization=0.8
elif [ "$total_ram" -le 8192 ]; then
    heapstartsize=32m; heapgrowthlimit=384m; heapsize=1024m; heaptargetutilization=0.85
elif [ "$total_ram" -le 12288 ]; then
    heapstartsize=48m; heapgrowthlimit=512m; heapsize=1536m; heaptargetutilization=0.88
else
    heapstartsize=64m; heapgrowthlimit=768m; heapsize=2048m; heaptargetutilization=0.9
fi

setprop dalvik.vm.heapstartsize "$heapstartsize"
setprop dalvik.vm.heapgrowthlimit "$heapgrowthlimit"
setprop dalvik.vm.heapsize "$heapsize"
setprop dalvik.vm.heaptargetutilization "$heaptargetutilization"
setprop dalvik.vm.usejit true
setprop dalvik.vm.usejitprofiles true
setprop dalvik.vm.appimageformat lz4
setprop dalvik.vm.dexopt-flags "m=y,o=y,u=n"
setprop dalvik.vm.dex2oat-filter everything
setprop dalvik.vm.systemuicompilerfilter everything
setprop dalvik.vm.systemservercompilerfilter everything
setprop pm.dexopt.bg-dexopt everything
setprop pm.dexopt.install everything
setprop pm.dexopt.shared everything

if [ "$cpu_cores" -ge 8 ]; then
    setprop dalvik.vm.dex2oat-threads 8
    setprop dalvik.vm.image-dex2oat-threads 8
    setprop dalvik.vm.dex2oat-cpu-set 0-7
elif [ "$cpu_cores" -ge 6 ]; then
    setprop dalvik.vm.dex2oat-threads 6
    setprop dalvik.vm.image-dex2oat-threads 6
    setprop dalvik.vm.dex2oat-cpu-set 0-5
else
    setprop dalvik.vm.dex2oat-threads 4
    setprop dalvik.vm.image-dex2oat-threads 4
    setprop dalvik.vm.dex2oat-cpu-set 0-3
fi
log "Dalvik/ART tweaks applied (RAM: ${total_ram}MB, Cores: $cpu_cores)"

# ----- 3.4 STUNE (bổ sung từ service.sh) -----
write /dev/stune/schedtune.boost 0
write /dev/stune/schedtune.prefer_idle 0
write /dev/stune/top-app/schedtune.boost 90
write /dev/stune/top-app/schedtune.prefer_idle 1
write /dev/stune/foreground/schedtune.boost 70
write /dev/stune/foreground/schedtune.prefer_idle 1
write /dev/stune/background/schedtune.boost 15
write /dev/stune/background/schedtune.prefer_idle 0
log "STUNE additional tweaks applied"

# ----- 3.5 GED (bổ sung) -----
write /sys/module/ged/parameters/gx_dfps "$refresh_rate"
write /sys/module/ged/parameters/boost_gpu_enable 1
write /sys/module/ged/parameters/gpu_dvfs_enable 1
write /sys/module/ged/parameters/enable_cpu_boost 1
write /sys/module/ged/parameters/enable_gpu_boost 1
write /sys/module/ged/parameters/boost_extra 1
write /sys/module/ged/parameters/gx_game_mode 1
write /sys/module/ged/parameters/gx_force_cpu_boost 1
write /sys/module/ged/parameters/gx_frc_mode 1
log "GED additional tweaks applied"

# ----- 3.6 I/O Queue bổ sung -----
for e in mmcblk0 sda sdb sdc; do
    f="/sys/block/$e/queue"
    write "$f/scheduler" noop
    write "$f/add_random" 0
    write "$f/iostats" 0
    write "$f/nomerges" 2
    write "$f/rotational" 0
    write "$f/rq_affinity" 2
    write "$f/nr_requests" 128
    write "$f/read_ahead_kb" 128
done
log "Additional I/O queue tweaks applied"

# ----- 3.7 UI và Touch Settings -----
setprop persist.sys.ui.hw true
setprop debug.composition.type gpu
setprop touch.pressure.calibration amplitude
setprop touch.pressure.scale 0.015
setprop touch.size.scale 0.009
setprop touch.size.calibration diameter
setprop touch.size.isSummed 0
setprop touch.size.bias -0.4

settings put global window_animation_scale 0.2
settings put global transition_animation_scale 0.2
settings put global animator_duration_scale 0.2
settings put global block_untrusted_touches 0
settings put secure multi_press_timeout 170
settings put secure long_press_timeout 170
log "UI/Touch settings applied"

# ==============================================
# KẾT THÚC
# ==============================================
log "========== KernelEnhancer Completed =========="
echo "KernelEnhancer completed at $(date)" > /data/local/tmp/kernel_optimized
