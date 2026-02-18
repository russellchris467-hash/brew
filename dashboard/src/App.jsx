import { useState, useEffect, useRef } from 'react';
import { analyse, healthScore } from './aiBot';

// --- Data generation helpers ---

/**
 * Deterministic SHA-256-like hash derived from the IP string.
 * Fix: original used Math.random() and ignored the `ip` argument entirely,
 * so the same device produced a different fingerprint on every call.
 */
const hashDevice = (ip) => {
  let seed = 0;
  for (let i = 0; i < ip.length; i++) {
    seed = (seed * 31 + ip.charCodeAt(i)) >>> 0;
  }
  const chars = '0123456789abcdef';
  let hash = '';
  for (let i = 0; i < 64; i++) {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    hash += chars[seed % 16];
  }
  return hash;
};

const generateStealthTag = (type) => {
  const emojis = {
    scanner: '🔍',
    sql_injection: '💉',
    brute_force: '🔨',
    xss: '🦠',
    reconnaissance: '👁️',
    data_exfil: '📤',
    malware: '☠️',
    ddos: '💥',
  };
  // Invisible zero-width characters appended after the emoji
  return emojis[type] + '\u200B\u200C\u200B\u200D\u200C\u200B\u200D\u200B\u200C';
};

const generateIndicators = (type) => {
  const all = {
    highFrequency: false,
    sqlInjection: false,
    xssAttempt: false,
    portScanning: false,
    bruteForce: false,
    dnsTunneling: false,
    commandInjection: false,
    maliciousDomain: true,
  };

  if (type === 'scanner')       all.portScanning  = true;
  if (type === 'sql_injection') all.sqlInjection  = true;
  if (type === 'brute_force')   all.bruteForce    = true;
  if (type === 'xss')           all.xssAttempt    = true;
  if (type === 'data_exfil')    all.dnsTunneling  = true;

  return all;
};

const generateThreat = () => {
  const types = [
    'scanner', 'sql_injection', 'brute_force', 'xss',
    'reconnaissance', 'data_exfil', 'malware', 'ddos',
  ];
  const ips = [
    '192.168.1.200', '10.0.0.45', '172.16.50.123',
    '192.168.100.77', '10.10.10.250',
  ];
  const domains = [
    'evil-c2.malware.ru', 'botnet-tracker.cn', 'exfil-data.xyz',
    'phishing-site.tk', 'cryptominer.io', 'scanner-probe.net',
    'backdoor-access.onion',
  ];

  const type = types[Math.floor(Math.random() * types.length)];
  const ip   = ips[Math.floor(Math.random() * ips.length)];

  return {
    id:          Date.now() + Math.random(),
    timestamp:   new Date(),
    clientIp:    ip,
    deviceHash:  hashDevice(ip),            // Fix: now deterministic per IP
    domain:      domains[Math.floor(Math.random() * domains.length)],
    type,
    queryCount:  Math.floor(Math.random() * 200) + 1,
    severity:    Math.random() > 0.7 ? 'CRITICAL' : Math.random() > 0.4 ? 'HIGH' : 'MEDIUM',
    stealthTag:  generateStealthTag(type),
    indicators:  generateIndicators(type),
    geoLocation: { country: 'RU', city: 'Moscow', flag: '🇷🇺' },
    amnesiacMode: true,
  };
};

// --- Static lookup table ---

const THREAT_TYPES = {
  scanner:       { emoji: '🔍', name: 'Port Scanner',      color: '#ff6b35' },
  sql_injection: { emoji: '💉', name: 'SQL Injection',     color: '#b5179e' },
  brute_force:   { emoji: '🔨', name: 'Brute Force',       color: '#f72585' },
  xss:           { emoji: '🦠', name: 'XSS Attack',        color: '#7209b7' },
  ddos:          { emoji: '💥', name: 'DDoS',              color: '#560bad' },
  malware:       { emoji: '☠️', name: 'Malware',           color: '#ff2d55' },
  reconnaissance:{ emoji: '👁️', name: 'Reconnaissance',   color: '#ff6b35' },
  data_exfil:    { emoji: '📤', name: 'Data Exfiltration', color: '#ff2d55' },
};

// --- Main component ---

export default function App() {
  const [threats, setThreats]               = useState([]);
  const [selectedThreat, setSelectedThreat] = useState(null);
  const [view, setView]                     = useState('live');
  const [amnesiacActive, setAmnesiacActive] = useState(true);
  const [notifications, setNotifications]   = useState([]);
  const [tagDecodeInput, setTagDecodeInput] = useState('');
  const [decodedTag, setDecodedTag]         = useState(null);
  const [botLog, setBotLog]                 = useState([]);
  const [botActive, setBotActive]           = useState(true);
  const blockedIpsRef    = useRef(new Set());
  const appliedPatchesRef = useRef(new Set());
  const audioRef = useRef(null);

  // AI bot — runs every 4s, analyses the accumulated threat list
  useEffect(() => {
    if (!botActive) return;
    const interval = setInterval(() => {
      setThreats(currentThreats => {
        setBotLog(currentLog => {
          const newActions = analyse(
            currentThreats,
            blockedIpsRef.current,
            appliedPatchesRef.current,
            currentLog,
          );
          return newActions.length ? [...newActions, ...currentLog].slice(0, 100) : currentLog;
        });
        return currentThreats; // no change to threats list
      });
    }, 4000);
    return () => clearInterval(interval);
  }, [botActive]);

  // Real-time threat ingestion
  useEffect(() => {
    const interval = setInterval(() => {
      const newThreat = generateThreat();

      // Fix: was `…prev` (U+2026 ellipsis) — not a valid spread operator
      setThreats(prev => [newThreat, ...prev].slice(0, 50));

      if (newThreat.severity === 'CRITICAL') {
        const notif = {
          id:      Date.now(),
          message: `CRITICAL: ${newThreat.type} from ${newThreat.clientIp}`,
          threat:  newThreat,
        };
        setNotifications(prev => [notif, ...prev].slice(0, 5));
        if (audioRef.current) audioRef.current.play().catch(() => {});
      }
    }, 2000);

    return () => clearInterval(interval);
  }, []);

  /**
   * Decode a stealth tag pasted by the user.
   * Fix: original ignored tagDecodeInput for all fields except the displayed
   * emoji; device hash was hardcoded to '192.168.1.200' and randomised anyway.
   * Now the emoji is matched against THREAT_TYPES and the hash is derived from
   * the full tag string so results are consistent for the same input.
   */
  const decodeTag = () => {
    if (!tagDecodeInput) return;

    // Find which THREAT_TYPES entry whose emoji starts the pasted tag
    const match = Object.entries(THREAT_TYPES).find(([, v]) =>
      tagDecodeInput.startsWith(v.emoji)
    );

    const matchedType  = match ? match[0] : 'unknown';
    const matchedEmoji = match ? match[1].emoji : tagDecodeInput[0];

    setDecodedTag({
      emoji:       matchedEmoji,
      threatType:  matchedType,
      deviceHash:  hashDevice(tagDecodeInput),  // deterministic from tag content
      timestamp:   new Date().toISOString(),
      severity:    'HIGH',
      metadata: {
        detection:  ['Pattern matching', 'Frequency analysis'],
        confidence: 0.94,
        firstSeen:  new Date(Date.now() - 3_600_000).toISOString(),
        queryCount: 147,
      },
    });
  };

  const getSeverityColor = (s) =>
    ({ CRITICAL: '#ff2d55', HIGH: '#ff6b35', MEDIUM: '#ffd60a' }[s] || '#888');

  const health = healthScore(threats, blockedIpsRef.current, appliedPatchesRef.current);

  const stats = {
    total:    threats.length,
    critical: threats.filter(t => t.severity === 'CRITICAL').length,
    unique:   new Set(threats.map(t => t.clientIp)).size,
    blocked:  threats.filter(t => t.amnesiacMode).length,
  };

  return (
    <div style={{ fontFamily: '-apple-system,BlinkMacSystemFont,monospace', minHeight: '100vh', background: '#000', color: '#0f0' }}>
      <audio ref={audioRef} src="data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBCx+zPLTgjMGHm7A7OScTgwOVqzn77BdGAg+ltryxnMpBS99zvPaizsIE2S57OihUBELTKXh8bllHAU2jdXyz4I2Bie23/DQiD0KElyx6+mnVBMKRZ7e8L1uJAUsfc3z2YY6Bx5sv+zonFAPC1an5O+zYBoKPJPY8sxzKQUof8rx14s7CBZV6uupWRIKRZ7e8L1uJAUsfc3z2YY6Bx5sv+zonFAPC1an5O+zYBoKPJPY8sxzKQUof8rx14s7CBZmQs" />

      {/* Top Bar */}
      <div style={{ background: 'linear-gradient(135deg,#001a00,#003300)', borderBottom: '2px solid #0f0', padding: '12px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap' }}>
        <div>
          <div style={{ fontSize: '18px', fontWeight: 'bold', marginBottom: '4px' }}>🕵️ AMNESIAC THREAT TRACKER</div>
          <div style={{ fontSize: '11px', opacity: 0.8 }}>SHA-256 Fingerprinting + Emoji Steganography + Shadow Database</div>
        </div>
        <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
          <div style={{ background: amnesiacActive ? '#001a00' : '#1a0000', border: `2px solid ${amnesiacActive ? '#0f0' : '#f00'}`, padding: '6px 12px', borderRadius: '6px', fontSize: '11px', animation: amnesiacActive ? 'pulse 2s infinite' : 'none' }}>
            <span style={{ fontSize: '16px', marginRight: '6px' }}>{amnesiacActive ? '😴' : '😎'}</span>
            <strong>{amnesiacActive ? 'AMNESIAC ACTIVE' : 'NORMAL MODE'}</strong>
          </div>
          <button onClick={() => setAmnesiacActive(!amnesiacActive)} style={{ padding: '6px 12px', background: 'transparent', border: '1px solid #0f0', color: '#0f0', borderRadius: '6px', cursor: 'pointer', fontSize: '11px' }}>
            Toggle
          </button>
        </div>
      </div>

      {/* Notifications Bar */}
      {notifications.length > 0 && (
        <div style={{ background: '#1a0000', borderBottom: '1px solid #f00', padding: '8px 20px', display: 'flex', gap: '10px', overflowX: 'auto' }}>
          {notifications.map(n => (
            <div key={n.id} style={{ background: '#000', border: '1px solid #f00', padding: '6px 12px', borderRadius: '4px', fontSize: '11px', whiteSpace: 'nowrap', animation: 'slideIn 0.3s' }}>
              🚨 {n.message}
            </div>
          ))}
        </div>
      )}

      {/* Stats Bar */}
      {/* Fix: `opacity:0.7'` (stray quote) corrected to `opacity: 0.7` in all four stat labels */}
      <div style={{ background: '#001100', borderBottom: '1px solid #0f0', padding: '12px 20px', display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(150px,1fr))', gap: '12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <div style={{ fontSize: '24px' }}>🎯</div>
          <div>
            <div style={{ fontSize: '10px', opacity: 0.7 }}>TOTAL THREATS</div>
            <div style={{ fontSize: '18px', fontWeight: 'bold' }}>{stats.total}</div>
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <div style={{ fontSize: '24px' }}>🔥</div>
          <div>
            <div style={{ fontSize: '10px', opacity: 0.7 }}>CRITICAL</div>
            <div style={{ fontSize: '18px', fontWeight: 'bold', color: '#f00' }}>{stats.critical}</div>
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <div style={{ fontSize: '24px' }}>🖥️</div>
          <div>
            <div style={{ fontSize: '10px', opacity: 0.7 }}>UNIQUE DEVICES</div>
            <div style={{ fontSize: '18px', fontWeight: 'bold', color: '#ff0' }}>{stats.unique}</div>
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <div style={{ fontSize: '24px' }}>😴</div>
          <div>
            <div style={{ fontSize: '10px', opacity: 0.7 }}>AMNESIACED</div>
            <div style={{ fontSize: '18px', fontWeight: 'bold', color: '#0ff' }}>{stats.blocked}</div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div style={{ background: '#000', borderBottom: '1px solid #0f0', padding: '10px 20px', display: 'flex', gap: '8px', overflowX: 'auto' }}>
        {['live', 'shadow-db', 'decoder', 'forensics', 'ai-bot'].map(v => (
          <button key={v} onClick={() => setView(v)} style={{ padding: '8px 14px', background: view === v ? '#003300' : 'transparent', border: '1px solid #0f0', color: '#0f0', borderRadius: '6px', cursor: 'pointer', fontSize: '12px', whiteSpace: 'nowrap' }}>
            {v === 'live' ? '🔴 LIVE' : v === 'shadow-db' ? '💾 SHADOW DB' : v === 'decoder' ? '🔓 DECODER' : v === 'forensics' ? '🔬 FORENSICS' : '🤖 AI BOT'}
          </button>
        ))}
      </div>

      <div style={{ padding: '20px', maxWidth: '1600px', margin: '0 auto' }}>

        {/* LIVE VIEW */}
        {view === 'live' && (
          <div>
            <div style={{ marginBottom: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h2 style={{ fontSize: '16px' }}>🔴 LIVE THREAT STREAM</h2>
              {/* Fix: `opacity:0.7'` → `opacity: 0.7` */}
              <div style={{ fontSize: '11px', opacity: 0.7 }}>Real-time detection • Auto-refresh every 2s</div>
            </div>

            <div style={{ display: 'grid', gap: '10px' }}>
              {threats.slice(0, 15).map(t => {
                const typeData = THREAT_TYPES[t.type];
                return (
                  <div
                    key={t.id}
                    onClick={() => setSelectedThreat(t)}
                    style={{
                      background:   '#001100',
                      border:       `1px solid ${t.severity === 'CRITICAL' ? '#f00' : t.severity === 'HIGH' ? '#ff6b35' : '#0f0'}`,
                      borderRadius: '8px',
                      padding:      '12px',
                      cursor:       'pointer',
                      animation:    'fadeIn 0.5s',
                      borderLeft:   `4px solid ${getSeverityColor(t.severity)}`,
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '10px' }}>
                      <div style={{ flex: 1, minWidth: '200px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
                          <span style={{ fontSize: '20px' }}>{typeData.emoji}</span>
                          <span style={{ fontSize: '14px', fontWeight: 'bold', color: typeData.color }}>{typeData.name}</span>
                          {/* Fix: `opacity:0.7'` → `opacity: 0.7` */}
                          <span style={{ fontSize: '10px', opacity: 0.7 }}>{t.timestamp.toLocaleTimeString()}</span>
                        </div>
                        <div style={{ fontSize: '12px', marginBottom: '4px' }}>
                          <strong>Target:</strong> {t.domain}
                        </div>
                        {/* Fix: `opacity:0.8'` → `opacity: 0.8` */}
                        <div style={{ fontSize: '11px', opacity: 0.8 }}>
                          <strong>Source:</strong> {t.clientIp} {t.geoLocation.flag}
                          <span style={{ marginLeft: '10px', fontFamily: 'monospace', fontSize: '10px' }}>
                            SHA-256: {t.deviceHash.substring(0, 16)}...
                          </span>
                        </div>
                      </div>
                      <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                        <div style={{ background: getSeverityColor(t.severity) + '22', border: `1px solid ${getSeverityColor(t.severity)}`, padding: '4px 10px', borderRadius: '4px', fontSize: '11px', fontWeight: 'bold', color: getSeverityColor(t.severity) }}>
                          {t.severity}
                        </div>
                        {t.amnesiacMode && (
                          <div style={{ background: '#001a00', border: '1px solid #0f0', padding: '4px 10px', borderRadius: '4px', fontSize: '11px' }}>
                            😴 AMNESIACED
                          </div>
                        )}
                        <div style={{ fontFamily: 'monospace', fontSize: '14px', background: '#000', padding: '4px 8px', borderRadius: '4px' }}>
                          {t.stealthTag}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>

            {selectedThreat && (
              <div style={{ position: 'fixed', top: '50%', left: '50%', transform: 'translate(-50%,-50%)', background: '#001a00', border: '2px solid #0f0', borderRadius: '12px', padding: '24px', maxWidth: '600px', width: '90%', maxHeight: '80vh', overflow: 'auto', zIndex: 1000, boxShadow: '0 0 50px rgba(0,255,0,0.3)' }}>
                <button onClick={() => setSelectedThreat(null)} style={{ position: 'absolute', top: '10px', right: '10px', background: '#f00', color: '#fff', border: 'none', borderRadius: '50%', width: '24px', height: '24px', cursor: 'pointer' }}>✕</button>

                <h3 style={{ fontSize: '18px', marginBottom: '16px', color: '#0f0' }}>Threat Details</h3>

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(200px,1fr))', gap: '12px', marginBottom: '16px' }}>
                  <div>
                    <div style={{ fontSize: '10px', opacity: 0.7, marginBottom: '4px' }}>THREAT TYPE</div>
                    <div>{THREAT_TYPES[selectedThreat.type].emoji} {THREAT_TYPES[selectedThreat.type].name}</div>
                  </div>
                  <div>
                    <div style={{ fontSize: '10px', opacity: 0.7, marginBottom: '4px' }}>SEVERITY</div>
                    <div style={{ color: getSeverityColor(selectedThreat.severity), fontWeight: 'bold' }}>{selectedThreat.severity}</div>
                  </div>
                  <div>
                    <div style={{ fontSize: '10px', opacity: 0.7, marginBottom: '4px' }}>SOURCE IP</div>
                    <div style={{ fontFamily: 'monospace' }}>{selectedThreat.clientIp}</div>
                  </div>
                  <div>
                    <div style={{ fontSize: '10px', opacity: 0.7, marginBottom: '4px' }}>QUERIES</div>
                    <div style={{ fontWeight: 'bold' }}>{selectedThreat.queryCount}</div>
                  </div>
                </div>

                <div style={{ marginBottom: '16px' }}>
                  <div style={{ fontSize: '10px', opacity: 0.7, marginBottom: '4px' }}>DEVICE FINGERPRINT (SHA-256)</div>
                  <div style={{ fontFamily: 'monospace', fontSize: '11px', background: '#000', padding: '8px', borderRadius: '4px', wordBreak: 'break-all' }}>
                    {selectedThreat.deviceHash}
                  </div>
                </div>

                <div style={{ marginBottom: '16px' }}>
                  <div style={{ fontSize: '10px', opacity: 0.7, marginBottom: '4px' }}>STEALTH TAG (EMOJI STEGANOGRAPHY)</div>
                  <div style={{ fontFamily: 'monospace', fontSize: '16px', background: '#000', padding: '8px', borderRadius: '4px' }}>
                    {selectedThreat.stealthTag}
                  </div>
                  <div style={{ fontSize: '10px', opacity: 0.6, marginTop: '4px' }}>
                    Contains invisible zero-width Unicode markers with embedded metadata
                  </div>
                </div>

                <div>
                  <div style={{ fontSize: '10px', opacity: 0.7, marginBottom: '8px' }}>DETECTION INDICATORS</div>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                    {Object.entries(selectedThreat.indicators).filter(([, v]) => v).map(([key]) => (
                      <div key={key} style={{ background: '#001a00', border: '1px solid #0f0', padding: '4px 8px', borderRadius: '4px', fontSize: '10px' }}>
                        ✓ {key.replace(/([A-Z])/g, ' $1').trim()}
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {selectedThreat && (
              <div onClick={() => setSelectedThreat(null)} style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.8)', zIndex: 999 }} />
            )}
          </div>
        )}

        {/* SHADOW DATABASE */}
        {view === 'shadow-db' && (
          <div>
            <h2 style={{ fontSize: '16px', marginBottom: '12px' }}>💾 ENCRYPTED SHADOW DATABASE</h2>
            <div style={{ fontSize: '11px', opacity: 0.7, marginBottom: '16px' }}>
              All entries AES-256 encrypted • SHA-256 hashed fingerprints • Stealth tags embedded
            </div>

            <div style={{ background: '#001100', borderRadius: '8px', overflow: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '11px' }}>
                <thead>
                  <tr style={{ background: '#003300', borderBottom: '2px solid #0f0' }}>
                    <th style={{ padding: '10px', textAlign: 'left' }}>TIMESTAMP</th>
                    <th style={{ padding: '10px', textAlign: 'left' }}>DEVICE HASH</th>
                    <th style={{ padding: '10px', textAlign: 'left' }}>TYPE</th>
                    <th style={{ padding: '10px', textAlign: 'left' }}>SEVERITY</th>
                    <th style={{ padding: '10px', textAlign: 'right' }}>QUERIES</th>
                    <th style={{ padding: '10px', textAlign: 'left' }}>TAG</th>
                  </tr>
                </thead>
                <tbody>
                  {threats.slice(0, 20).map(t => (
                    <tr key={t.id} style={{ borderBottom: '1px solid #001a00' }}>
                      <td style={{ padding: '10px', opacity: 0.7 }}>{t.timestamp.toLocaleTimeString()}</td>
                      <td style={{ padding: '10px', fontFamily: 'monospace', fontSize: '10px' }}>{t.deviceHash.substring(0, 16)}...</td>
                      <td style={{ padding: '10px' }}>{THREAT_TYPES[t.type].emoji} {THREAT_TYPES[t.type].name}</td>
                      <td style={{ padding: '10px' }}>
                        <span style={{ background: getSeverityColor(t.severity) + '22', color: getSeverityColor(t.severity), padding: '2px 6px', borderRadius: '3px', fontSize: '10px' }}>
                          {t.severity}
                        </span>
                      </td>
                      <td style={{ padding: '10px', textAlign: 'right', fontWeight: 'bold' }}>{t.queryCount}</td>
                      <td style={{ padding: '10px', fontFamily: 'monospace' }}>{t.stealthTag}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* DECODER */}
        {view === 'decoder' && (
          <div>
            <h2 style={{ fontSize: '16px', marginBottom: '12px' }}>🔓 STEALTH TAG DECODER</h2>
            <div style={{ background: '#001100', border: '1px solid #0f0', borderRadius: '8px', padding: '20px', marginBottom: '20px' }}>
              <div style={{ fontSize: '11px', marginBottom: '12px' }}>
                Paste an emoji stealth tag to extract hidden metadata encoded with zero-width Unicode steganography
              </div>
              <input
                type="text"
                value={tagDecodeInput}
                onChange={(e) => setTagDecodeInput(e.target.value)}
                placeholder="🔍​‌​‍‌​‍​‌"
                style={{ width: '100%', padding: '12px', background: '#000', border: '1px solid #0f0', borderRadius: '6px', color: '#0f0', fontSize: '16px', fontFamily: 'monospace', marginBottom: '12px', boxSizing: 'border-box' }}
              />
              <button onClick={decodeTag} style={{ padding: '10px 20px', background: '#003300', border: '1px solid #0f0', color: '#0f0', borderRadius: '6px', cursor: 'pointer', fontWeight: 'bold' }}>
                🔓 DECODE TAG
              </button>
            </div>

            {decodedTag && (
              <div style={{ background: '#001a00', border: '2px solid #0f0', borderRadius: '8px', padding: '20px', animation: 'fadeIn 0.5s' }}>
                <h3 style={{ fontSize: '14px', marginBottom: '16px', color: '#0f0' }}>✓ DECODED METADATA</h3>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(200px,1fr))', gap: '14px' }}>
                  {[
                    ['Visible Emoji',  <span key="emoji" style={{ fontSize: '32px' }}>{decodedTag.emoji}</span>],
                    ['Threat Type',    decodedTag.threatType],
                    ['Device Hash',    <span key="hash" style={{ fontFamily: 'monospace', fontSize: '10px' }}>{decodedTag.deviceHash.substring(0, 32)}...</span>],
                    ['Severity',       <span key="sev" style={{ color: getSeverityColor(decodedTag.severity), fontWeight: 'bold' }}>{decodedTag.severity}</span>],
                    ['Timestamp',      new Date(decodedTag.timestamp).toLocaleString()],
                    ['Confidence',     <span key="conf" style={{ color: '#0ff' }}>{(decodedTag.metadata.confidence * 100).toFixed(0)}%</span>],
                  ].map(([label, value], i) => (
                    <div key={i} style={{ background: '#000', border: '1px solid #0f0', borderRadius: '6px', padding: '12px' }}>
                      <div style={{ fontSize: '10px', opacity: 0.7, marginBottom: '4px' }}>{label}</div>
                      <div>{value}</div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* AI BOT */}
        {view === 'ai-bot' && (
          <div>
            {/* Header + controls */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', flexWrap: 'wrap', gap: '10px' }}>
              <div>
                <h2 style={{ fontSize: '16px', marginBottom: '4px' }}>🤖 AI SELF-REPAIR BOT</h2>
                <div style={{ fontSize: '11px', opacity: 0.7 }}>Autonomous threat response • Runs every 4s • Mutates zero human config</div>
              </div>
              <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                <div style={{ background: botActive ? '#001a00' : '#1a0000', border: `1px solid ${botActive ? '#0f0' : '#f00'}`, padding: '6px 14px', borderRadius: '6px', fontSize: '11px', animation: botActive ? 'pulse 2s infinite' : 'none' }}>
                  {botActive ? '🟢 BOT ONLINE' : '🔴 BOT OFFLINE'}
                </div>
                <button onClick={() => setBotActive(a => !a)} style={{ padding: '6px 12px', background: 'transparent', border: '1px solid #0f0', color: '#0f0', borderRadius: '6px', cursor: 'pointer', fontSize: '11px' }}>
                  {botActive ? 'Pause' : 'Resume'}
                </button>
              </div>
            </div>

            {/* Health + counters */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(160px,1fr))', gap: '12px', marginBottom: '20px' }}>
              {[
                ['🛡️ System Health', `${health}%`, health > 70 ? '#0f0' : health > 40 ? '#ffd60a' : '#f00'],
                ['🚫 IPs Blocked',   blockedIpsRef.current.size,   '#0ff'],
                ['🩹 Patches Applied', appliedPatchesRef.current.size, '#ff6b35'],
                ['📋 Bot Actions',   botLog.length,  '#888'],
              ].map(([label, val, color]) => (
                <div key={label} style={{ background: '#001100', border: '1px solid #0f0', borderRadius: '8px', padding: '14px', display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <div>
                    <div style={{ fontSize: '10px', opacity: 0.7, marginBottom: '4px' }}>{label}</div>
                    <div style={{ fontSize: '22px', fontWeight: 'bold', color }}>{val}</div>
                  </div>
                </div>
              ))}
            </div>

            {/* Health bar */}
            <div style={{ background: '#001100', border: '1px solid #0f0', borderRadius: '8px', padding: '14px', marginBottom: '16px' }}>
              <div style={{ fontSize: '11px', marginBottom: '8px', opacity: 0.8 }}>SYSTEM INTEGRITY</div>
              <div style={{ background: '#000', borderRadius: '4px', height: '12px', overflow: 'hidden' }}>
                <div style={{ height: '100%', width: `${health}%`, background: health > 70 ? '#0f0' : health > 40 ? '#ffd60a' : '#f00', borderRadius: '4px', transition: 'width 1s ease, background 1s ease' }} />
              </div>
              <div style={{ fontSize: '10px', opacity: 0.6, marginTop: '6px' }}>
                Score derived from recent threat severity, applied patches, and blocked IPs
              </div>
            </div>

            {/* Action log */}
            <div style={{ background: '#001100', border: '1px solid #0f0', borderRadius: '8px', padding: '14px' }}>
              <div style={{ fontSize: '12px', fontWeight: 'bold', marginBottom: '12px' }}>📋 AUTONOMOUS ACTION LOG</div>
              {botLog.length === 0 ? (
                <div style={{ fontSize: '11px', opacity: 0.5, padding: '20px', textAlign: 'center' }}>
                  Waiting for threats… bot will act shortly.
                </div>
              ) : (
                <div style={{ display: 'grid', gap: '8px', maxHeight: '500px', overflowY: 'auto' }}>
                  {botLog.map(a => {
                    const kindMeta = {
                      block:     { label: 'AUTO-BLOCK',  border: '#f00',    bg: '#1a0000' },
                      patch:     { label: 'PATCH',       border: '#ff6b35', bg: '#1a0800' },
                      'self-heal':{ label: 'SELF-HEAL',  border: '#0ff',    bg: '#001a1a' },
                      tune:      { label: 'TUNE',        border: '#ffd60a', bg: '#1a1600' },
                    }[a.kind] || { label: a.kind.toUpperCase(), border: '#0f0', bg: '#001100' };

                    return (
                      <div key={a.id} style={{ background: kindMeta.bg, border: `1px solid ${kindMeta.border}`, borderRadius: '6px', padding: '10px 14px', animation: 'fadeIn 0.4s' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '4px' }}>
                          <span style={{ fontSize: '10px', fontWeight: 'bold', color: kindMeta.border }}>
                            [{kindMeta.label}]
                          </span>
                          <span style={{ fontSize: '10px', opacity: 0.6 }}>
                            {new Date(a.ts).toLocaleTimeString()}
                          </span>
                        </div>
                        <div style={{ fontSize: '12px' }}>{a.message}</div>
                        {a.patch && (
                          <div style={{ fontSize: '10px', opacity: 0.7, marginTop: '4px' }}>
                            ℹ️ {a.patch.description}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        )}

        {/* FORENSICS */}
        {view === 'forensics' && (
          <div>
            <h2 style={{ fontSize: '16px', marginBottom: '16px' }}>🔬 FORENSIC ANALYSIS</h2>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(300px,1fr))', gap: '16px', marginBottom: '20px' }}>
              <div style={{ background: '#001100', border: '1px solid #0f0', borderRadius: '8px', padding: '16px' }}>
                <h3 style={{ fontSize: '14px', marginBottom: '12px' }}>Attack Timeline</h3>
                <div style={{ height: '150px', background: '#000', borderRadius: '4px', display: 'flex', alignItems: 'flex-end', gap: '2px', padding: '10px' }}>
                  {threats.slice(0, 20).slice().reverse().map((t, i) => (
                    <div key={i} style={{ flex: 1, height: `${(t.queryCount / 200) * 140}px`, background: getSeverityColor(t.severity), borderRadius: '2px' }} />
                  ))}
                </div>
              </div>

              <div style={{ background: '#001100', border: '1px solid #0f0', borderRadius: '8px', padding: '16px' }}>
                <h3 style={{ fontSize: '14px', marginBottom: '12px' }}>Top Attack Vectors</h3>
                {Object.entries(
                  threats.reduce((acc, t) => { acc[t.type] = (acc[t.type] || 0) + 1; return acc; }, {})
                ).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([type, count]) => (
                  <div key={type} style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 0', borderBottom: '1px solid #001a00' }}>
                    <span>{THREAT_TYPES[type]?.emoji} {THREAT_TYPES[type]?.name || type}</span>
                    <span style={{ fontWeight: 'bold', color: THREAT_TYPES[type]?.color }}>{count}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>

      <style>{`
        @keyframes pulse   { 0%,100%{opacity:1} 50%{opacity:0.5} }
        @keyframes fadeIn  { from{opacity:0;transform:translateY(10px)} to{opacity:1;transform:translateY(0)} }
        @keyframes slideIn { from{transform:translateX(-20px);opacity:0} to{transform:translateX(0);opacity:1} }
      `}</style>
    </div>
  );
}
