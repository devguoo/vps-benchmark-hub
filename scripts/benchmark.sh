#!/usr/bin/env bash
# =============================================================================
# VPS Benchmark Script — vps-benchmark-hub
# Runs CPU, memory, disk I/O, and network tests on a target VPS.
# Outputs JSON to stdout. Designed to run in 3-5 minutes.
#
# Usage:
#   bash benchmark.sh --provider vultr --plan "Cloud Compute 1GB" --location "Tokyo"
#
# Requirements: Linux (Debian/Ubuntu or RHEL/CentOS). Root or sudo recommended.
# Dependencies (auto-installed if missing): sysbench, fio, curl, bc
# =============================================================================

set -euo pipefail

# ─── Argument Parsing ────────────────────────────────────────────────────────
PROVIDER="Unknown"
PLAN="Unknown"
LOCATION="Unknown"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="$2"; shift 2 ;;
    --plan)     PLAN="$2";     shift 2 ;;
    --location) LOCATION="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --provider <name> --plan <plan> --location <loc>"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

DATE=$(date -u +"%Y-%m-%d")

# ─── Helpers ─────────────────────────────────────────────────────────────────
log() { echo "[bench] $*" >&2; }

command_exists() { command -v "$1" &>/dev/null; }

install_deps() {
  log "Installing missing dependencies..."
  if command_exists apt-get; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update -qq >/dev/null 2>&1
    sudo apt-get install -y -qq sysbench fio curl bc >/dev/null 2>&1
  elif command_exists yum; then
    sudo yum install -y -q epel-release >/dev/null 2>&1 || true
    sudo yum install -y -q sysbench fio curl bc >/dev/null 2>&1
  elif command_exists dnf; then
    sudo dnf install -y -q epel-release >/dev/null 2>&1 || true
    sudo dnf install -y -q sysbench fio curl bc >/dev/null 2>&1
  else
    log "ERROR: Unsupported package manager. Please install sysbench, fio, curl, bc manually."
    exit 1
  fi
}

# Check / install deps
for cmd in sysbench fio curl bc; do
  if ! command_exists "$cmd"; then
    install_deps
    break
  fi
done

NUM_CPUS=$(nproc 2>/dev/null || echo 1)

# ─── CPU Benchmark ───────────────────────────────────────────────────────────
log "Running CPU benchmark..."

# Single-thread
CPU_SINGLE=$(sysbench cpu --cpu-max-prime=20000 --threads=1 --time=15 run 2>/dev/null \
  | grep "events per second" | awk '{print $NF}' | xargs printf "%.0f")

# Multi-thread
CPU_MULTI=$(sysbench cpu --cpu-max-prime=20000 --threads="$NUM_CPUS" --time=15 run 2>/dev/null \
  | grep "events per second" | awk '{print $NF}' | xargs printf "%.0f")

log "CPU: single=$CPU_SINGLE multi=$CPU_MULTI"

# ─── Memory Benchmark ───────────────────────────────────────────────────────
log "Running memory benchmark..."

MEM_READ=$(sysbench memory --memory-block-size=1M --memory-total-size=10G --memory-oper=read --threads=1 --time=10 run 2>/dev/null \
  | grep "transferred" | grep -oP '[\d.]+\s+MiB/sec' | awk '{print $1}' | xargs printf "%.0f")

MEM_WRITE=$(sysbench memory --memory-block-size=1M --memory-total-size=10G --memory-oper=write --threads=1 --time=10 run 2>/dev/null \
  | grep "transferred" | grep -oP '[\d.]+\s+MiB/sec' | awk '{print $1}' | xargs printf "%.0f")

log "Memory: read=${MEM_READ}MB/s write=${MEM_WRITE}MB/s"

# ─── Disk I/O Benchmark ─────────────────────────────────────────────────────
log "Running disk I/O benchmark..."

BENCH_DIR="/tmp/vps-bench-fio"
mkdir -p "$BENCH_DIR"

# Sequential read
SEQ_READ=$(fio --name=seq_read --directory="$BENCH_DIR" --rw=read --bs=1M --size=512M \
  --numjobs=1 --time_based --runtime=15 --group_reporting --output-format=json 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['jobs'][0]['read']['bw']/1024))" 2>/dev/null || echo 0)

# Sequential write
SEQ_WRITE=$(fio --name=seq_write --directory="$BENCH_DIR" --rw=write --bs=1M --size=512M \
  --numjobs=1 --time_based --runtime=15 --group_reporting --output-format=json 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['jobs'][0]['write']['bw']/1024))" 2>/dev/null || echo 0)

# 4K random IOPS
RANDOM_IOPS=$(fio --name=rand_rw --directory="$BENCH_DIR" --rw=randrw --bs=4k --size=256M \
  --numjobs=1 --time_based --runtime=15 --group_reporting --output-format=json 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); j=d['jobs'][0]; print(int(j['read']['iops']+j['write']['iops']))" 2>/dev/null || echo 0)

rm -rf "$BENCH_DIR"

log "Disk: seq_read=${SEQ_READ}MB/s seq_write=${SEQ_WRITE}MB/s 4k_iops=$RANDOM_IOPS"

# ─── Network Benchmark ──────────────────────────────────────────────────────
log "Running network benchmark..."

# Download speed (100MB test file from multiple CDN endpoints)
DOWNLOAD_SPEED=0
for url in \
  "https://speed.cloudflare.com/__down?bytes=104857600" \
  "http://speedtest.tele2.net/100MB.zip" \
  "http://cachefly.cachefly.net/100mb.test"; do
  
  SPEED=$(curl -o /dev/null -s -w "%{speed_download}" --connect-timeout 5 --max-time 30 "$url" 2>/dev/null || echo 0)
  SPEED_MBPS=$(echo "$SPEED" | awk '{printf "%.0f", $1 * 8 / 1048576}')
  if [ "$SPEED_MBPS" -gt "$DOWNLOAD_SPEED" ] 2>/dev/null; then
    DOWNLOAD_SPEED=$SPEED_MBPS
  fi
  break  # Use first successful result to save time
done

# Upload speed estimate (POST 10MB to Cloudflare)
UPLOAD_SPEED=$(dd if=/dev/urandom bs=1M count=10 2>/dev/null \
  | curl -o /dev/null -s -w "%{speed_upload}" --connect-timeout 5 --max-time 30 \
    -X POST --data-binary @- "https://speed.cloudflare.com/__up" 2>/dev/null || echo 0)
UPLOAD_MBPS=$(echo "$UPLOAD_SPEED" | awk '{printf "%.0f", $1 * 8 / 1048576}')

# Ping to key nodes
ping_ms() {
  local host="$1"
  local ms
  ms=$(ping -c 3 -W 3 "$host" 2>/dev/null | tail -1 | awk -F'/' '{printf "%.1f", $5}' || echo "null")
  [ -z "$ms" ] && ms="null"
  echo "$ms"
}

PING_TOKYO=$(ping_ms "speedtest.tokyo2.linode.com")
PING_HK=$(ping_ms "speedtest.hkg02.softlayer.com")
PING_SG=$(ping_ms "speedtest.singapore.linode.com")
PING_LA=$(ping_ms "speedtest.lax1.linode.com")
PING_FRANKFURT=$(ping_ms "speedtest.frankfurt.linode.com")

log "Network: down=${DOWNLOAD_SPEED}Mbps up=${UPLOAD_MBPS}Mbps"

# ─── Compute Score ───────────────────────────────────────────────────────────
# Weighted score (0-100 scale, approximate)
# CPU 30%, Disk 30%, Memory 20%, Network 20%
SCORE=$(echo "$CPU_SINGLE $SEQ_READ $RANDOM_IOPS $MEM_READ $DOWNLOAD_SPEED" | awk '{
  cpu_score  = ($1 / 2000) * 30;   if (cpu_score > 30)  cpu_score = 30;
  disk_score = ($2 / 1000) * 15 + ($3 / 100000) * 15; if (disk_score > 30) disk_score = 30;
  mem_score  = ($4 / 20000) * 20;  if (mem_score > 20)  mem_score = 20;
  net_score  = ($5 / 5000) * 20;   if (net_score > 20)  net_score = 20;
  total = cpu_score + disk_score + mem_score + net_score;
  printf "%.0f", total;
}')

log "Score: $SCORE/100"

# ─── Output JSON ─────────────────────────────────────────────────────────────
cat <<EOF
{
  "provider": "$PROVIDER",
  "plan": "$PLAN",
  "location": "$LOCATION",
  "date": "$DATE",
  "cpu": {
    "single_thread": $CPU_SINGLE,
    "multi_thread": $CPU_MULTI
  },
  "memory": {
    "read_mbps": $MEM_READ,
    "write_mbps": $MEM_WRITE
  },
  "disk": {
    "seq_read_mbps": $SEQ_READ,
    "seq_write_mbps": $SEQ_WRITE,
    "4k_random_iops": $RANDOM_IOPS
  },
  "network": {
    "download_mbps": $DOWNLOAD_SPEED,
    "upload_mbps": $UPLOAD_MBPS,
    "ping_ms": {
      "tokyo": $PING_TOKYO,
      "hongkong": $PING_HK,
      "singapore": $PING_SG,
      "los_angeles": $PING_LA,
      "frankfurt": $PING_FRANKFURT
    }
  },
  "score": $SCORE,
  "source": "Automated benchmark via vps-benchmark-hub/scripts/benchmark.sh"
}
EOF

log "Benchmark complete!"
