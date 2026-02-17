/**
 * AI Self-Repair Bot
 *
 * Runs entirely in-browser. It watches the live threat stream and produces
 * "repair actions" autonomously:
 *   - IP auto-block when a source exceeds an attack threshold
 *   - Sensitivity tuning when false-positive rate drifts
 *   - Patch recommendations keyed to attack type
 *   - Self-healing announcements when critical bursts are detected
 */

// ── Thresholds ────────────────────────────────────────────────────────────────
const IP_BLOCK_THRESHOLD   = 4;   // block after N attacks from the same IP
const BURST_WINDOW_MS      = 10_000; // look-back window for burst detection
const CRITICAL_BURST_LIMIT = 3;   // trigger self-heal after N criticals in window

// ── Patch database (keyed by threat type) ────────────────────────────────────
const PATCHES = {
  sql_injection: {
    id:          'PATCH-SQL-001',
    description: 'Enforce parameterised queries & input sanitisation layer',
    action:      'Applied WAF rule: block SQL meta-characters in DNS query payloads',
  },
  xss: {
    id:          'PATCH-XSS-002',
    description: 'Tighten Content-Security-Policy headers',
    action:      'Deployed CSP nonce rotation + output encoding middleware',
  },
  brute_force: {
    id:          'PATCH-BF-003',
    description: 'Enable adaptive rate-limiting on auth endpoints',
    action:      'Rate-limiter updated: 5 req/s ceiling + exponential back-off',
  },
  scanner: {
    id:          'PATCH-SC-004',
    description: 'Harden port exposure and enable port-knock stealth mode',
    action:      'Firewall ruleset updated: non-essential ports blackholed',
  },
  ddos: {
    id:          'PATCH-DD-005',
    description: 'Activate traffic scrubbing + anycast sink-holing',
    action:      'DDoS mitigation pipeline engaged, upstream null-routing applied',
  },
  malware: {
    id:          'PATCH-MW-006',
    description: 'Quarantine flagged process hashes + update blocklist',
    action:      'Hash blocklist synchronised; DNS sinkhole for C2 domain activated',
  },
  reconnaissance: {
    id:          'PATCH-RC-007',
    description: 'Deploy honeypot decoys on probed endpoints',
    action:      'Honeypot nodes deployed; recon traffic redirected and logged',
  },
  data_exfil: {
    id:          'PATCH-DE-008',
    description: 'Enforce DLP policy + DNS-over-HTTPS inspection',
    action:      'DoH inspection enabled; outbound DNS tunnel payloads blocked',
  },
};

// ── Severity scores used by the health metric ─────────────────────────────────
const SEV_SCORE = { CRITICAL: 10, HIGH: 5, MEDIUM: 2 };

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Analyse the current threat list and return zero or more repair actions.
 *
 * @param {Array}  threats        Full threat list (newest first)
 * @param {Set}    blockedIps     Already-blocked IPs (mutated in place)
 * @param {Set}    appliedPatches Already-applied patch IDs (mutated in place)
 * @param {Array}  botLog         Existing bot log (for burst detection)
 * @returns {Array} New BotAction objects to append to the log
 */
export function analyse(threats, blockedIps, appliedPatches, botLog) {
  const actions = [];
  const now     = Date.now();

  // 1. IP auto-block ──────────────────────────────────────────────────────────
  const ipCounts = {};
  for (const t of threats) {
    if (!blockedIps.has(t.clientIp)) {
      ipCounts[t.clientIp] = (ipCounts[t.clientIp] || 0) + 1;
    }
  }
  for (const [ip, count] of Object.entries(ipCounts)) {
    if (count >= IP_BLOCK_THRESHOLD) {
      blockedIps.add(ip);
      actions.push(makeAction('block', `🚫 Auto-blocked ${ip} (${count} attacks detected)`, 'CRITICAL', ip));
    }
  }

  // 2. Patch deployment ───────────────────────────────────────────────────────
  const recentTypes = new Set(threats.slice(0, 10).map(t => t.type));
  for (const type of recentTypes) {
    const patch = PATCHES[type];
    if (patch && !appliedPatches.has(patch.id)) {
      appliedPatches.add(patch.id);
      actions.push(makeAction('patch', `🩹 ${patch.id}: ${patch.action}`, 'HIGH', null, patch));
    }
  }

  // 3. Critical burst → self-heal ────────────────────────────────────────────
  const recentCriticals = threats.filter(
    t => t.severity === 'CRITICAL' && (now - t.timestamp.getTime()) < BURST_WINDOW_MS
  );
  const alreadyHealing = botLog.some(
    a => a.kind === 'self-heal' && (now - a.ts) < BURST_WINDOW_MS * 2
  );
  if (recentCriticals.length >= CRITICAL_BURST_LIMIT && !alreadyHealing) {
    actions.push(makeAction(
      'self-heal',
      `🔧 SELF-HEAL: ${recentCriticals.length} criticals in ${BURST_WINDOW_MS / 1000}s — ` +
      'triggering adaptive defence recalibration',
      'CRITICAL'
    ));
  }

  // 4. Sensitivity tuning ────────────────────────────────────────────────────
  const lastTune = botLog.filter(a => a.kind === 'tune').at(-1);
  const tuneAge  = lastTune ? now - lastTune.ts : Infinity;
  if (tuneAge > 30_000 && threats.length >= 10) {
    const critPct = threats.filter(t => t.severity === 'CRITICAL').length / threats.length;
    if (critPct > 0.4) {
      actions.push(makeAction('tune', '⚙️ TUNE: Raising detection sensitivity (high critical ratio)', 'HIGH'));
    } else if (critPct < 0.1 && threats.length > 20) {
      actions.push(makeAction('tune', '⚙️ TUNE: Relaxing sensitivity thresholds (low signal ratio)', 'MEDIUM'));
    }
  }

  return actions;
}

/**
 * Compute an overall system health score (0–100).
 * Drops as threat severity accumulates, recovers as blocks and patches are applied.
 */
export function healthScore(threats, blockedIps, appliedPatches) {
  const raw = threats.slice(0, 20).reduce((sum, t) => sum + (SEV_SCORE[t.severity] || 0), 0);
  const max  = 20 * SEV_SCORE.CRITICAL;
  const base = Math.max(0, 100 - Math.round((raw / max) * 70));

  const patchBonus = Math.min(appliedPatches.size * 3, 20);
  const blockBonus = Math.min(blockedIps.size  * 2, 10);

  return Math.min(100, base + patchBonus + blockBonus);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

let _seq = 1;

function makeAction(kind, message, severity, ip = null, patch = null) {
  return {
    id:       _seq++,
    ts:       Date.now(),
    kind,     // 'block' | 'patch' | 'self-heal' | 'tune'
    message,
    severity,
    ip,
    patch,
  };
}
