#!/system/bin/sh
#
# Performance Lock Script for MSM8953
# Lock CPU at 3.15GHz and GPU at 850MHz
# Author: K-Nel Team
#

# Function to log messages
log_msg() {
    echo "[PERF-LOCK] $1"
    echo "[PERF-LOCK] $1" >> /dev/kmsg
}

# Function to set CPU frequency lock
set_cpu_lock() {
    log_msg "Setting CPU frequency lock to 3.15GHz..."
    
    # Set performance governor for all CPUs
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -f "$cpu" ]; then
            echo "performance" > "$cpu" 2>/dev/null
            log_msg "Set performance governor for $(dirname $cpu)"
        fi
    done
    
    # Set minimum and maximum frequency to 3.15GHz
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq; do
        if [ -f "$cpu" ]; then
            echo "3150400" > "$cpu" 2>/dev/null
        fi
    done
    
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
        if [ -f "$cpu" ]; then
            echo "3150400" > "$cpu" 2>/dev/null
        fi
    done
    
    # Disable CPU boost to prevent frequency scaling
    if [ -f /sys/module/cpu_boost/parameters/cpu_boost ]; then
        echo "0" > /sys/module/cpu_boost/parameters/cpu_boost 2>/dev/null
    fi
    
    # Set CPU frequency directly
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_setspeed; do
        if [ -f "$cpu" ]; then
            echo "3150400" > "$cpu" 2>/dev/null
        fi
    done
    
    log_msg "CPU frequency lock applied successfully"
}

# Function to set GPU frequency lock
set_gpu_lock() {
    log_msg "Setting GPU frequency lock to 850MHz..."
    
    # Set GPU to maximum power level (0)
    if [ -f /sys/class/kgsl/kgsl-3d0/default_pwrlevel ]; then
        echo "0" > /sys/class/kgsl/kgsl-3d0/default_pwrlevel 2>/dev/null
    fi
    
    # Set GPU minimum and maximum frequency
    if [ -f /sys/class/kgsl/kgsl-3d0/min_pwrlevel ]; then
        echo "0" > /sys/class/kgsl/kgsl-3d0/min_pwrlevel 2>/dev/null
    fi
    
    if [ -f /sys/class/kgsl/kgsl-3d0/max_pwrlevel ]; then
        echo "0" > /sys/class/kgsl/kgsl-3d0/max_pwrlevel 2>/dev/null
    fi
    
    # Force GPU to stay at maximum frequency
    if [ -f /sys/class/kgsl/kgsl-3d0/force_clk_on ]; then
        echo "1" > /sys/class/kgsl/kgsl-3d0/force_clk_on 2>/dev/null
    fi
    
    # Disable GPU devfreq
    if [ -f /sys/class/kgsl/kgsl-3d0/devfreq/governor ]; then
        echo "performance" > /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null
    fi
    
    # Set GPU frequency directly
    if [ -f /sys/class/kgsl/kgsl-3d0/gpuclk ]; then
        echo "850000000" > /sys/class/kgsl/kgsl-3d0/gpuclk 2>/dev/null
    fi
    
    log_msg "GPU frequency lock applied successfully"
}

# Function to set thermal limits
set_thermal_limits() {
    log_msg "Adjusting thermal limits for performance..."
    
    # Increase CPU thermal limits
    for thermal in /sys/class/thermal/thermal_zone*/trip_point_*_temp; do
        if [ -f "$thermal" ]; then
            current_temp=$(cat "$thermal" 2>/dev/null)
            if [ "$current_temp" -lt "95000" ] && [ "$current_temp" -gt "0" ]; then
                echo "95000" > "$thermal" 2>/dev/null
            fi
        fi
    done
    
    log_msg "Thermal limits adjusted"
}

# Function to disable power saving features
disable_power_saving() {
    log_msg "Disabling power saving features..."
    
    # Disable CPU hotplug
    if [ -f /sys/module/msm_hotplug/parameters/enabled ]; then
        echo "0" > /sys/module/msm_hotplug/parameters/enabled 2>/dev/null
    fi
    
    # Keep all CPUs online
    for cpu in /sys/devices/system/cpu/cpu*/online; do
        if [ -f "$cpu" ]; then
            echo "1" > "$cpu" 2>/dev/null
        fi
    done
    
    # Disable CPU idle
    if [ -f /sys/devices/system/cpu/cpuidle/use_deepest_state ]; then
        echo "1" > /sys/devices/system/cpu/cpuidle/use_deepest_state 2>/dev/null
    fi
    
    log_msg "Power saving features disabled"
}

# Main execution
main() {
    log_msg "Starting performance lock initialization..."
    log_msg "Target: CPU 3.15GHz, GPU 850MHz"
    
    # Wait for system to be ready
    sleep 5
    
    # Apply performance locks
    set_cpu_lock
    set_gpu_lock
    set_thermal_limits
    disable_power_saving
    
    log_msg "Performance lock initialization completed"
    log_msg "System locked at maximum performance"
    
    # Verify settings
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        current_cpu_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
        log_msg "Current CPU frequency: ${current_cpu_freq} KHz"
    fi
    
    if [ -f /sys/class/kgsl/kgsl-3d0/gpuclk ]; then
        current_gpu_freq=$(cat /sys/class/kgsl/kgsl-3d0/gpuclk)
        log_msg "Current GPU frequency: ${current_gpu_freq} Hz"
    fi
}

# Execute main function
main "$@"
