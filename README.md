<div align="center">

# 📊 VPS Benchmark Hub

**Open-source VPS performance database — transparent, automated, community-driven.**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/devguoo/vps-benchmark-hub?style=social)](https://github.com/devguoo/vps-benchmark-hub)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/devguoo/vps-benchmark-hub/pulls)
[![Benchmark: Automated](https://img.shields.io/badge/Benchmark-Automated-blue.svg)](#-benchmark-script)
[![Data: Open](https://img.shields.io/badge/Data-Open%20%26%20Verifiable-orange.svg)](#-data-transparency)

<br>

🔍 **Every number is verifiable.** Run our benchmark script on any VPS and compare results yourself.

No sponsored rankings. No affiliate bias in data. Just raw performance numbers from the community.

</div>

---

## 🏆 Leaderboard

<!-- LEADERBOARD_START -->

| Rank | Provider | Plan | Location | CPU (ST) | Disk Seq R | 4K IOPS | Download | Score | Review |
|:----:|:---------|:-----|:---------|:--------:|:----------:|:-------:|:--------:|:-----:|:------:|
| — | **BandwagonHost** | 20G CN2 GIA-E | Los Angeles DC6 | — | — | — | — | ⏳ Pending | [📖 Review](https://www.bwhhost.com) |
| — | **Cloudways** | Vultr High Frequency — 1GB RAM | Multiple (Vultr infrastructure) | — | — | — | — | ⏳ Pending | [📖 Review](https://www.cloudwaysguide.com) |
| — | **DigitalOcean** | Basic Droplet — 1 vCPU / 1GB RAM | Singapore (SGP1) | — | — | — | — | ⏳ Pending | [📖 Review](https://www.digitaloceanpro.com) |
| — | **Kinsta** | Starter — WordPress Hosting | Multiple (Google Cloud C2 machines) | — | — | — | — | ⏳ Pending | [📖 Review](https://www.kinstainfo.com) |
| — | **Vultr** | Cloud Compute — 1 vCPU / 1GB RAM | Tokyo | — | — | — | — | ⏳ Pending | [📖 Review](https://www.vultrinfo.com) |

> **5** providers tested · Last updated: 2026-03-30 · Score = weighted composite (CPU 30% + Disk 30% + Memory 20% + Network 20%)
>
> ⏳ **Pending** = waiting for community benchmarks. [Contribute yours!](#-how-to-contribute)

<!-- LEADERBOARD_END -->

---

## 🚀 Benchmark Script

One command to benchmark your VPS:

```bash
curl -sL https://raw.githubusercontent.com/devguoo/vps-benchmark-hub/main/scripts/benchmark.sh | \
  bash -s -- --provider "YourProvider" --plan "YourPlan" --location "YourLocation"
```

Or clone and run locally:

```bash
git clone https://github.com/devguoo/vps-benchmark-hub.git
cd vps-benchmark-hub
bash scripts/benchmark.sh --provider "Vultr" --plan "Cloud Compute 1GB" --location "Tokyo"
```

### What it tests

| Test | Tool | Duration | Metric |
|------|------|----------|--------|
| **CPU** (single & multi-thread) | sysbench | ~30s | events/sec |
| **Memory** (read & write) | sysbench | ~20s | MB/s |
| **Disk** (sequential R/W + 4K random) | fio | ~45s | MB/s, IOPS |
| **Network** (download + upload) | curl | ~30s | Mbps |
| **Ping** (5 global nodes) | ping | ~15s | ms |

**Total runtime: ~3 minutes** · Auto-installs dependencies (sysbench, fio) · Outputs JSON to stdout

---

## 🤝 How to Contribute

We need your benchmarks! Here's how:

### Option 1: Quick Submit (Issue)

1. Run the benchmark script on your VPS (see above)
2. Copy the JSON output
3. [Open an issue](https://github.com/devguoo/vps-benchmark-hub/issues/new?template=benchmark-submission.md) and paste the JSON

### Option 2: Pull Request

1. Run the benchmark script
2. Save output: `bash scripts/benchmark.sh --provider "..." --plan "..." --location "..." > results/provider-location-plan.json`
3. Fork → commit → open a PR

### Option 3: GitHub Actions (Maintainers)

Use the `Update Benchmark Results` workflow with `workflow_dispatch` to add new results and auto-update the leaderboard.

### Contribution Guidelines

- ✅ Run on a **fresh** VPS (no other heavy processes)
- ✅ Use the **default OS** image (Ubuntu 22.04+ recommended)
- ✅ Include **accurate** provider/plan/location info
- ❌ Don't modify benchmark parameters
- ❌ Don't submit results from overloaded or customized instances

---

## 📐 Methodology

### Scoring Formula

```
Score = CPU(30%) + Disk(30%) + Memory(20%) + Network(20%)

CPU:     (single_thread / 2000) × 30     (capped at 30)
Disk:    (seq_read / 1000) × 15 + (4k_iops / 100000) × 15  (capped at 30)
Memory:  (read_mbps / 20000) × 20        (capped at 20)
Network: (download_mbps / 5000) × 20     (capped at 20)
```

### Why these weights?

- **CPU & Disk** (30% each): Most workloads are CPU or I/O bound
- **Memory** (20%): Important for databases and caching
- **Network** (20%): Critical for web servers and API endpoints

### Test conditions

- Each test runs for 10-15 seconds with warm-up
- fio uses `--direct=1` for raw disk performance (no OS cache)
- Network test uses multiple CDN endpoints for accuracy
- Ping targets: Tokyo, Hong Kong, Singapore, Los Angeles, Frankfurt

---

## 🔍 Data Transparency

**Every piece of data in this repository is:**

- 📂 **Open** — raw JSON files in `results/`, anyone can inspect
- 🔁 **Reproducible** — run `benchmark.sh` yourself and verify
- 📝 **Sourced** — every entry has a `source` field documenting its origin
- 🤖 **Automated** — leaderboard generated by script, no manual editing
- 🔀 **Version-controlled** — full git history of every change

We do not accept paid placements or modify scores for sponsors.

---

## 📁 Repository Structure

```
vps-benchmark-hub/
├── scripts/
│   ├── benchmark.sh          # Run this on your VPS
│   └── generate-readme.js    # Auto-generates leaderboard table
├── results/
│   ├── bandwagonhost-dc6-cn2-gia.json
│   ├── vultr-tokyo-cloud-compute.json
│   ├── digitalocean-sgp1-basic.json
│   ├── cloudways-vultr-1gb.json
│   └── kinsta-starter.json
├── .github/workflows/
│   └── update-results.yml    # Auto-update on new data
├── README.md
└── LICENSE
```

---

## 📚 Further Reading

Looking for detailed provider reviews and setup guides?

- 🔗 [BandwagonHost / 搬瓦工 Guide](https://www.bwhhost.com) — CN2 GIA plans, configurations, and tutorials
- 🔗 [Vultr Setup Guide](https://www.vultrinfo.com) — Deployment guides, plan comparisons
- 🔗 [DigitalOcean Pro Tips](https://www.digitaloceanpro.com) — Droplet optimization, tutorials
- 🔗 [Cloudways Managed Hosting Guide](https://www.cloudwaysguide.com) — Performance tuning, migration guides
- 🔗 [Kinsta WordPress Hosting Info](https://www.kinstainfo.com) — WordPress performance, CDN setup

---

<div align="center">

### ⭐ Find this useful? Star the repo to support open benchmarking!

[![Star History Chart](https://api.star-history.com/svg?repos=devguoo/vps-benchmark-hub&type=Date)](https://star-history.com/#devguoo/vps-benchmark-hub&Date)

**Built with 💻 by the community · [Contribute a benchmark](#-how-to-contribute) · [View all data](results/)**

</div>
