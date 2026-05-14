/* global React */
const { useState, useEffect, useRef } = React;

/* ====== shared atoms ====== */

function Pill({ status, children }) {
  return (
    <span className={`op-pill ${status}`}>
      <span className="dot"></span>
      {children || status}
    </span>
  );
}

function Tag({ children, color }) {
  const style = color ? { borderColor: `rgba(0,229,255,0.3)`, color: 'var(--op-cyan)' } : {};
  return <span className="op-tag" style={style}>{children}</span>;
}

function Kbd({ children }) {
  return <span className="op-kbd">{children}</span>;
}

function Label({ children, style }) {
  return <span className="op-label" style={style}>{children}</span>;
}

function Button({ children, variant, size, onClick, icon }) {
  return (
    <button className={`op-btn ${variant || ''} ${size || ''}`} onClick={onClick}>
      {icon ? <i data-lucide={icon} style={{ width: 14, height: 14 }}></i> : null}
      {children}
    </button>
  );
}

function Caret() {
  return <span style={{ color: 'var(--op-cyan)', animation: 'opBlink 1s steps(2) infinite' }}>▌</span>;
}

/* Icon helper: drops an inline lucide icon */
function Icon({ name, size = 16, color }) {
  const ref = useRef(null);
  useEffect(() => {
    if (window.lucide && ref.current) {
      ref.current.innerHTML = '';
      const el = document.createElement('i');
      el.setAttribute('data-lucide', name);
      el.style.width = `${size}px`;
      el.style.height = `${size}px`;
      if (color) el.style.color = color;
      ref.current.appendChild(el);
      window.lucide.createIcons({ attrs: { 'stroke-width': 1.5 } });
    }
  }, [name, size, color]);
  return <span ref={ref} style={{ display: 'inline-flex', width: size, height: size, color: color || 'inherit' }}></span>;
}

/* ====== data ====== */
const SEED_AGENTS = [
  { id: 'agt_8x4z', name: 'Synthesizer-04',     status: 'running', mission: 'Weekly digest from 1,402 inputs', step: '14/20', version: 'v1.4', age: '2m' },
  { id: 'agt_kk31', name: 'Patch-orchestrator', status: 'paused',  mission: 'Awaiting operator confirmation', step: '08/12', version: 'v2.0', age: '4m' },
  { id: 'agt_7r2k', name: 'Crawler-prime',      status: 'queued',  mission: 'Indexing release notes',         step: '00/30', version: 'v1.0', age: '12s' },
  { id: 'agt_p4mb', name: 'Codex-tutor',        status: 'errored', mission: 'tool.web.fetch timeout (30s)',    step: '02/14', version: 'v1.1', age: '1m' },
  { id: 'agt_dl08', name: 'Watcher-eu',         status: 'running', mission: 'Tail eu-west-2 incident channel', step: '∞',     version: 'v0.9', age: '14m' },
  { id: 'agt_kk22', name: 'Ledger-pro',         status: 'done',    mission: 'Reconciled Q1 ledger; 3 deltas',  step: '20/20', version: 'v3.2', age: '8m' },
  { id: 'agt_zz91', name: 'Sentinel-01',        status: 'running', mission: 'Scanning open PRs for regression', step: '06/20', version: 'v1.0', age: '32s' },
  { id: 'agt_g03q', name: 'Postman',            status: 'idle',    mission: '—',                              step: '—',     version: 'v1.2', age: '1h' },
];

const SEED_FEED = [
  { t: '14:02:11Z', who: 'agt_8x4z', kind: 'tool',  msg: 'tool.web.fetch → 200 OK · 4.2kb',   tone: 'lime' },
  { t: '14:02:09Z', who: 'agt_kk31', kind: 'wait',  msg: 'paused for operator approval',      tone: 'amber' },
  { t: '14:02:07Z', who: 'agt_p4mb', kind: 'err',   msg: 'tool.web.fetch timeout (30s)',      tone: 'magenta' },
  { t: '14:02:04Z', who: 'agt_zz91', kind: 'thought', msg: '// scanning PR #4012 for regressions in policy.py', tone: 'mute' },
  { t: '14:02:01Z', who: 'agt_kk22', kind: 'done',  msg: 'mission complete · 3 ledger deltas surfaced', tone: 'cyan' },
  { t: '14:01:58Z', who: 'agt_8x4z', kind: 'tool',  msg: 'tool.db.query → 412 rows',          tone: 'lime' },
  { t: '14:01:54Z', who: 'agt_dl08', kind: 'event', msg: 'detected p1: payment-svc 503s',     tone: 'magenta' },
  { t: '14:01:49Z', who: 'agt_7r2k', kind: 'wait',  msg: 'queued · uplink saturated',         tone: 'amber' },
  { t: '14:01:42Z', who: 'agt_8x4z', kind: 'thought', msg: '// summarizing batch 7 of 20',     tone: 'mute' },
  { t: '14:01:38Z', who: 'agt_zz91', kind: 'tool',  msg: 'tool.git.diff → 24 hunks',          tone: 'lime' },
];

Object.assign(window, { Pill, Tag, Kbd, Label, Button, Caret, Icon, SEED_AGENTS, SEED_FEED });
