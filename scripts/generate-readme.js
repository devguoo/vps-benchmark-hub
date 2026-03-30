#!/usr/bin/env node
/**
 * generate-readme.js
 * Reads results/*.json, generates a leaderboard Markdown table,
 * and injects it into README.md between <!-- LEADERBOARD_START --> and <!-- LEADERBOARD_END --> markers.
 */

const fs = require('fs');
const path = require('path');

const RESULTS_DIR = path.join(__dirname, '..', 'results');
const README_PATH = path.join(__dirname, '..', 'README.md');

const START_MARKER = '<!-- LEADERBOARD_START -->';
const END_MARKER = '<!-- LEADERBOARD_END -->';

// Provider → review site URL mapping
const PROVIDER_LINKS = {
  'bandwagonhost': 'https://www.bwhhost.com',
  'vultr': 'https://www.vultrinfo.com',
  'digitalocean': 'https://www.digitaloceanpro.com',
  'cloudways': 'https://www.cloudwaysguide.com',
  'kinsta': 'https://www.kinstainfo.com',
};

function getProviderLink(provider) {
  const key = provider.toLowerCase().replace(/\s+/g, '');
  for (const [k, url] of Object.entries(PROVIDER_LINKS)) {
    if (key.includes(k)) return url;
  }
  return null;
}

function formatValue(val, unit = '') {
  if (val === null || val === undefined) return '—';
  return `${val}${unit}`;
}

function scoreBadge(score) {
  if (score === null || score === undefined) return '⏳ Pending';
  if (score >= 80) return `🟢 ${score}`;
  if (score >= 60) return `🟡 ${score}`;
  if (score >= 40) return `🟠 ${score}`;
  return `🔴 ${score}`;
}

// Read all result files
const files = fs.readdirSync(RESULTS_DIR).filter(f => f.endsWith('.json'));
const results = [];

for (const file of files) {
  try {
    const data = JSON.parse(fs.readFileSync(path.join(RESULTS_DIR, file), 'utf-8'));
    data._filename = file;
    results.push(data);
  } catch (err) {
    console.error(`Warning: Failed to parse ${file}: ${err.message}`);
  }
}

// Sort: entries with scores first (descending), then pending entries
results.sort((a, b) => {
  if (a.score === null && b.score === null) return 0;
  if (a.score === null) return 1;
  if (b.score === null) return -1;
  return b.score - a.score;
});

// Generate table
let table = '';
table += '| Rank | Provider | Plan | Location | CPU (ST) | Disk Seq R | 4K IOPS | Download | Score | Review |\n';
table += '|:----:|:---------|:-----|:---------|:--------:|:----------:|:-------:|:--------:|:-----:|:------:|\n';

results.forEach((r, i) => {
  const rank = r.score !== null ? `${i + 1}` : '—';
  const link = getProviderLink(r.provider);
  const providerCell = link ? `**${r.provider}**` : `**${r.provider}**`;
  const reviewCell = link ? `[📖 Review](${link})` : '—';

  table += `| ${rank} `;
  table += `| ${providerCell} `;
  table += `| ${r.plan || '—'} `;
  table += `| ${r.location || '—'} `;
  table += `| ${formatValue(r.cpu?.single_thread)} `;
  table += `| ${formatValue(r.disk?.seq_read_mbps, ' MB/s')} `;
  table += `| ${formatValue(r.disk?.['4k_random_iops'])} `;
  table += `| ${formatValue(r.network?.download_mbps, ' Mbps')} `;
  table += `| ${scoreBadge(r.score)} `;
  table += `| ${reviewCell} `;
  table += '|\n';
});

if (results.length === 0) {
  table += '| — | No data yet | — | — | — | — | — | — | — | — |\n';
}

table += '\n';
table += `> **${results.length}** providers tested · Last updated: ${new Date().toISOString().split('T')[0]} · Score = weighted composite (CPU 30% + Disk 30% + Memory 20% + Network 20%)\n`;
table += '>\n';
table += '> ⏳ **Pending** = waiting for community benchmarks. [Contribute yours!](#-how-to-contribute)\n';

// Inject into README
let readme = fs.readFileSync(README_PATH, 'utf-8');

const startIdx = readme.indexOf(START_MARKER);
const endIdx = readme.indexOf(END_MARKER);

if (startIdx === -1 || endIdx === -1) {
  console.error('ERROR: Could not find leaderboard markers in README.md');
  console.error(`Looking for "${START_MARKER}" and "${END_MARKER}"`);
  process.exit(1);
}

const before = readme.substring(0, startIdx + START_MARKER.length);
const after = readme.substring(endIdx);

readme = before + '\n\n' + table + '\n' + after;

fs.writeFileSync(README_PATH, readme, 'utf-8');
console.log(`✅ Leaderboard updated with ${results.length} entries`);
