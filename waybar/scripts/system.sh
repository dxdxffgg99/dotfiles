#!/usr/bin/env bash

THEME="$HOME/.config/rofi/system.rasi"

host="$(hostnamectl --static 2>/dev/null || hostname)"
kernel="$(uname -r)"
uptime_pretty="$(uptime -p 2>/dev/null | sed 's/^up //')"
cpu="$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
cpu="${cpu:-Unknown}"
disk="$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"
mem_total="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
mem_avail="$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)"
mem_used="$(( mem_total - mem_avail ))"
ip_dev="$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}')"
if [[ -n "${ip_dev:-}" ]]; then
  ip_addr="$(ip -4 addr show dev "$ip_dev" scope global 2>/dev/null \
    | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)"
fi
ip_addr="${ip_addr:-N/A}"
shell_name="$(basename "$SHELL")"
pkg_count="$(pacman -Qq 2>/dev/null | wc -l || echo 'N/A')"

FG_MAIN="#FFFFFF"
FG_MUTED="#9AA0AA"
HOST_FG="#f5a0a0"
UPTIME_FG="#a8c4f5"
KERNEL_FG="#f5e08a"
CPU_FG="#89d4f5"
DISK_FG="#f5c48a"
NET_FG="#89e0e0"
SHELL_FG="#aab4f5"
PKG_FG="#8ad5c0"

info=$(cat <<EOF
<span foreground="$HOST_FG">󰌢</span>  <span foreground="$FG_MAIN"><b>호스트</b></span>    <span foreground="$FG_MUTED">$host</span>
<span foreground="$UPTIME_FG">󰥔</span>  <span foreground="$FG_MAIN"><b>가동시간</b></span>  <span foreground="$FG_MUTED">$uptime_pretty</span>
<span foreground="$KERNEL_FG">󰌽</span>  <span foreground="$FG_MAIN"><b>커널</b></span>      <span foreground="$FG_MUTED">$kernel</span>
<span foreground="$CPU_FG">󰻠</span>  <span foreground="$FG_MAIN"><b>CPU</b></span>       <span foreground="$FG_MUTED">$cpu</span>
<span foreground="$CPU_FG">󰘚</span>  <span foreground="$FG_MAIN"><b>RAM</b></span>       <span foreground="$FG_MUTED">${mem_used}MiB / ${mem_total}MiB</span>
<span foreground="$DISK_FG">󰋊</span>  <span foreground="$FG_MAIN"><b>디스크</b></span>    <span foreground="$FG_MUTED">$disk</span>
<span foreground="$NET_FG">󰈀</span>  <span foreground="$FG_MAIN"><b>IP</b></span>        <span foreground="$FG_MUTED">$ip_addr</span>
<span foreground="$SHELL_FG">󰆍</span>  <span foreground="$FG_MAIN"><b>셸</b></span>        <span foreground="$FG_MUTED">$shell_name</span>
<span foreground="$PKG_FG">󰏖</span>  <span foreground="$FG_MAIN"><b>패키지</b></span>    <span foreground="$FG_MUTED">$pkg_count</span>

EOF
)
rofi -dmenu \
    -theme "$THEME" \
    -mesg "$info" \
    -markup-rows \
    -p "" \
    -no-fixed-num-lines \
    < /dev/null
