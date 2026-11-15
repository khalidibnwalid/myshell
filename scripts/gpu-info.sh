#!/bin/sh
# One tab separated line per graphics card, for the System page:
#   gpu NAME DRIVER BUSY% VRAM_USED_BYTES VRAM_TOTAL_BYTES TEMP_C POWER_W CLOCK_MHZ MEMCLOCK_MHZ FAN% PSTATE
# "-" where a value is not known. NVIDIA cards are read with nvidia-smi, others from sysfs.
nv=$(nvidia-smi --query-gpu=pci.bus_id,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,clocks.gr,clocks.mem,fan.speed,pstate --format=csv,noheader,nounits 2>/dev/null)

val() { case "$1" in ""|"[N/A]"|"N/A"|"[Not Supported]") echo "-";; *) echo "$1";; esac; }
read_file() { [ -r "$1" ] && cat "$1" 2>/dev/null || echo ""; }

for card in /sys/class/drm/card[0-9]*; do
    case "$card" in *-*) continue;; esac
    dev="$card/device"
    [ -r "$dev/vendor" ] || continue
    addr=$(basename "$(readlink -f "$dev")")
    driver=$(basename "$(readlink -f "$dev/driver" 2>/dev/null)" 2>/dev/null)
    name=$(lspci -s "$addr" 2>/dev/null | sed 's/^[^ ]* [^:]*: //; s/ (rev [^)]*)$//')
    [ -n "$name" ] || name="$addr"
    busy="-"; used="-"; total="-"; temp="-"; power="-"; clock="-"; mclock="-"; fan="-"; pstate="-"

    if [ "$driver" = "nvidia" ] && [ -n "$nv" ]; then
        line=$(echo "$nv" | grep -i "^0000$addr,")
        if [ -n "$line" ]; then
            IFS=',' read -r _ b mu mt t p c mc f ps <<EOF
$line
EOF
            busy=$(val "$(echo $b)")
            mu=$(echo $mu); mt=$(echo $mt)
            [ -n "$mu" ] && used=$((mu * 1048576))
            [ -n "$mt" ] && total=$((mt * 1048576))
            temp=$(val "$(echo $t)"); power=$(val "$(echo $p)"); clock=$(val "$(echo $c)")
            mclock=$(val "$(echo $mc)"); fan=$(val "$(echo $f)"); pstate=$(val "$(echo $ps)")
        fi
    else
        v=$(read_file "$dev/gpu_busy_percent"); [ -n "$v" ] && busy=$v
        v=$(read_file "$dev/mem_info_vram_used"); [ -n "$v" ] && used=$v
        v=$(read_file "$dev/mem_info_vram_total"); [ -n "$v" ] && total=$v
        for h in "$dev"/hwmon/hwmon*; do
            [ -d "$h" ] || continue
            v=$(read_file "$h/temp1_input"); [ -n "$v" ] && temp=$((v / 1000))
            v=$(read_file "$h/power1_average"); [ -n "$v" ] && power=$((v / 1000000))
            v=$(read_file "$h/freq1_input"); [ -n "$v" ] && clock=$((v / 1000000))
        done
        for f in "$card/gt_cur_freq_mhz" "$card/gt/gt0/rps_cur_freq_mhz" "$dev/pp_dpm_sclk"; do
            v=$(read_file "$f")
            if [ -n "$v" ]; then
                case "$f" in *pp_dpm_sclk) v=$(echo "$v" | sed -n 's/^.*: \([0-9]*\)Mhz \*.*/\1/p');; esac
                [ -n "$v" ] && clock=$v && break
            fi
        done
    fi
    printf 'gpu\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$driver" "$busy" "$used" "$total" "$temp" "$power" "$clock" "$mclock" "$fan" "$pstate"
done
