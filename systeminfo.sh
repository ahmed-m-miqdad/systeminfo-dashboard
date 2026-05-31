#!/usr/bin/env bash
# ============================================
#   System Info Dashboard
#   Author: Ahmed M Miqdad
#   Description: Displays a clean and beautiful summary of
#   system information in your terminal.
# ============================================

set -euo pipefail

# ── Colors ─────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Helper: section header ────────────────────
header() {
  echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════╗${RESET}"
  printf  "${CYAN}${BOLD}║  %-36s║${RESET}\n" "$1"
  echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${RESET}"
}

# ── Helper: labeled row ───────────────────────
row() {
  printf "  ${YELLOW}%-18s${RESET} %s\n" "$1" "$2"
}

# ── Helper: progress bar ──────────────────────
progress_bar() {
  local used=$1 total=$2 width=20
  local filled=$(( used * width / total ))
  local empty=$(( width - filled ))
  local bar=""
  for (( i=0; i<filled; i++ )); do bar+="█"; done
  for (( i=0; i<empty;  i++ )); do bar+="░"; done
  local pct=$(( used * 100 / total ))
  if (( pct >= 80 )); then
    echo -e "${RED}[${bar}] ${pct}%${RESET}"
  elif (( pct >= 50 )); then
    echo -e "${YELLOW}[${bar}] ${pct}%${RESET}"
  else
    echo -e "${GREEN}[${bar}] ${pct}%${RESET}"
  fi
}

# ════════════════════════════════════════════
#  1. SYSTEM Information
# ════════════════════════════════════════════
header "🖥️  SYSTEM"

HOSTNAME=$(hostname)
OS=$(uname -o 2>/dev/null || uname -s)
KERNEL=$(uname -r)
ARCH=$(uname -m)
UPTIME=$(uptime -p 2>/dev/null || uptime | sed 's/.*up /up /' | cut -d',' -f1-2)

row "Hostname:"   "$HOSTNAME"
row "OS:"         "$OS"
row "Kernel:"     "$KERNEL"
row "Arch:"       "$ARCH"
row "Uptime:"     "$UPTIME"

# ════════════════════════════════════════════
#  2. CPU Information
# ════════════════════════════════════════════
header "⚙️  CPU"

CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null \
  | cut -d':' -f2 | xargs \
  || sysctl -n machdep.cpu.brand_string 2>/dev/null \
  || echo "N/A")
CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "N/A")

# Load average (1m, 5m, 15m)
read -r LOAD1 LOAD5 LOAD15 _ < /proc/loadavg 2>/dev/null || {
  LOADS=$(uptime | awk -F'load average[s]?:' '{print $2}')
  LOAD1=$(echo "$LOADS" | awk -F',' '{print $1}' | xargs)
  LOAD5=$(echo "$LOADS" | awk -F',' '{print $2}' | xargs)
  LOAD15=$(echo "$LOADS" | awk -F',' '{print $3}' | xargs)
}

row "Model:"      "$CPU_MODEL"
row "Cores:"      "$CPU_CORES"
row "Load (1m):"  "$LOAD1"
row "Load (5m):"  "$LOAD5"
row "Load (15m):" "$LOAD15"

# ════════════════════════════════════════════
#  3. MEMORY Information
# ════════════════════════════════════════════
header "🧠  MEMORY"

if [[ -f /proc/meminfo ]]; then
  MEM_TOTAL_KB=$(awk '/MemTotal/  {print $2}' /proc/meminfo)
  MEM_AVAIL_KB=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
  MEM_USED_KB=$(( MEM_TOTAL_KB - MEM_AVAIL_KB ))
  MEM_TOTAL_MB=$(( MEM_TOTAL_KB / 1024 ))
  MEM_USED_MB=$(( MEM_USED_KB  / 1024 ))
  MEM_AVAIL_MB=$(( MEM_AVAIL_KB / 1024 ))
else
  # macOS fallback
  MEM_TOTAL_MB=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 ))
  MEM_USED_MB=0
  MEM_AVAIL_MB=$MEM_TOTAL_MB
fi

row "Total:"      "${MEM_TOTAL_MB} MB"
row "Used:"       "${MEM_USED_MB} MB"
row "Available:"  "${MEM_AVAIL_MB} MB"
echo -n "  Usage:             "
progress_bar "$MEM_USED_MB" "$MEM_TOTAL_MB"

# ════════════════════════════════════════════
#  4. DISK Information
# ════════════════════════════════════════════
header "💾  DISK ( / )"

DISK_INFO=$(df -BM / | tail -1)
DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}' | tr -d 'M')
DISK_USED=$( echo "$DISK_INFO" | awk '{print $3}' | tr -d 'M')
DISK_AVAIL=$(echo "$DISK_INFO" | awk '{print $4}' | tr -d 'M')

row "Total:"      "${DISK_TOTAL} MB"
row "Used:"       "${DISK_USED} MB"
row "Available:"  "${DISK_AVAIL} MB"
echo -n "  Usage:             "
progress_bar "$DISK_USED" "$DISK_TOTAL"

# ════════════════════════════════════════════
#  5. NETWORK Information
# ════════════════════════════════════════════
header "🌐  NETWORK"

# Local IP
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' \
  || ipconfig getifaddr en0 2>/dev/null \
  || echo "N/A")

# Public IP (requires curl)
if command -v curl &>/dev/null; then
  PUBLIC_IP=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "unavailable")
else
  PUBLIC_IP="curl not found"
fi

# Default gateway
GATEWAY=$(ip route 2>/dev/null | awk '/default/ {print $3; exit}' \
  || netstat -nr 2>/dev/null | awk '/default/ {print $2; exit}' \
  || echo "N/A")

# DNS server
DNS=$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf 2>/dev/null || echo "N/A")

row "Local IP:"   "$LOCAL_IP"
row "Public IP:"  "$PUBLIC_IP"
row "Gateway:"    "$GATEWAY"
row "DNS:"        "$DNS"

# ════════════════════════════════════════════
#  6. TOP PROCESSES (by CPU)
# ════════════════════════════════════════════
header "📊  TOP 5 PROCESSES (CPU)"

printf "  ${YELLOW}%-6s %-12s %s${RESET}\n" "PID" "CPU%" "COMMAND"
echo "  ──────────────────────────────────"
ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=6 {printf "  %-6s %-12s %s\n", $2, $3, $11}' \
  || ps aux | sort -rk3 | awk 'NR<=5 {printf "  %-6s %-12s %s\n", $2, $3, $11}'

echo -e "\n${CYAN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${CYAN}${BOLD}════════════════════════════════════════${RESET}\n"