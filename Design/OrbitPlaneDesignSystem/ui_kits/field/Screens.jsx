/* global React */
const { useState } = React;

const F_AGENTS = [
  { id: 'agt_p4mb', name: 'Codex-tutor',        status: 'errored', mission: 'tool.web.fetch timeout (30s)',   age: '1m',  step: '02/14', priority: 'p1', pager: true  },
  { id: 'agt_kk31', name: 'Patch-orchestrator', status: 'paused',  mission: 'Awaiting operator confirmation', age: '4m',  step: '08/12', priority: 'p2', pager: true  },
  { id: 'agt_8x4z', name: 'Synthesizer-04',     status: 'running', mission: 'Weekly digest · 1,402 inputs',    age: '2m',  step: '14/20', priority: '—' },
  { id: 'agt_zz91', name: 'Sentinel-01',        status: 'running', mission: 'Scanning open PRs for regression', age: '32s', step: '06/20', priority: '—' },
  { id: 'agt_dl08', name: 'Watcher-eu',         status: 'running', mission: 'Tail eu-west-2 incident channel', age: '14m', step: '∞',     priority: '—' },
  { id: 'agt_kk22', name: 'Ledger-pro',         status: 'done',    mission: 'Reconciled Q1 ledger',           age: '8m',  step: '20/20', priority: '—' },
];

const dotColor = {
  running: 'var(--op-lime)',
  paused:  'var(--op-amber)',
  queued:  'var(--op-amber)',
  errored: 'var(--op-magenta)',
  done:    'var(--op-cyan)',
  idle:    'var(--op-fg-3)',
};
const dotGlow = {
  running: 'var(--op-lime-glow)',
  errored: 'var(--op-magenta-glow)',
};

function FieldShell({ children, statusBarRight }) {
  return (
    <div style={{
      width: '100%', height: '100%',
      background: 'var(--op-base)', color: 'var(--op-fg-1)',
      fontFamily: 'var(--op-font-display)',
      display: 'flex', flexDirection: 'column',
      position: 'relative', overflow: 'hidden',
      paddingTop: 54,  /* iOS status bar */
      paddingBottom: 30, /* iOS home indicator */
      boxSizing: 'border-box',
    }}>
      {children}
    </div>
  );
}

function FleetHome() {
  const paged = F_AGENTS.filter(a => a.pager);
  const live  = F_AGENTS.filter(a => !a.pager);

  return (
    <FieldShell>
      {/* status pad below iOS status bar */}
      <div style={{ padding: '8px 18px 12px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <img src="../../assets/logo-mark.svg" width="18" height="18" />
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 11, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-1)', fontWeight: 700 }}>
            field<span style={{ color: 'var(--op-fg-3)' }}> // primary</span>
          </span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontFamily: 'var(--op-font-mono)', fontSize: 10, color: 'var(--op-lime)', letterSpacing: '0.1em' }}>
          <span style={{ width: 5, height: 5, borderRadius: '50%', background: 'var(--op-lime)', boxShadow: '0 0 6px var(--op-lime)' }}></span>UPLINK
        </div>
      </div>

      {/* hero */}
      <div style={{ padding: '4px 18px 14px', display: 'flex', flexDirection: 'column', gap: 6, borderBottom: '1px solid var(--op-line)' }}>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>14:02:11Z · sector 7g</span>
        <h1 style={{ margin: 0, fontFamily: 'var(--op-font-display)', fontSize: 32, fontWeight: 600, letterSpacing: '-0.02em', lineHeight: 1.05 }}>
          2 agents<br/>paging you<span style={{ color: 'var(--op-magenta)' }}>.</span>
        </h1>
      </div>

      {/* paged */}
      <div style={{ padding: '14px 18px 4px' }}>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-magenta)' }}>▲ paged</span>
      </div>
      <div style={{ padding: '0 14px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {paged.map(a => <FieldRow key={a.id} agent={a} accent />)}
      </div>

      <div style={{ padding: '18px 18px 4px' }}>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>live · 4</span>
      </div>
      <div style={{ padding: '0 14px 14px', display: 'flex', flexDirection: 'column', gap: 8, overflow: 'auto', flex: 1 }}>
        {live.map(a => <FieldRow key={a.id} agent={a} />)}
      </div>

      {/* tab bar */}
      <FieldTabBar active="fleet" />
    </FieldShell>
  );
}

function FieldRow({ agent, accent }) {
  return (
    <div style={{
      background: accent ? 'rgba(255,46,142,0.04)' : 'var(--op-elev-2)',
      border: '1px solid ' + (accent ? 'rgba(255,46,142,0.35)' : 'var(--op-line)'),
      padding: '12px 14px',
      display: 'flex', flexDirection: 'column', gap: 8,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{
            width: 8, height: 8, borderRadius: '50%',
            background: dotColor[agent.status],
            boxShadow: dotGlow[agent.status] ? `0 0 8px ${dotGlow[agent.status]}` : 'none',
            animation: agent.status === 'running' ? 'opPulse 1.4s infinite' : 'none',
          }}></span>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 12, color: 'var(--op-fg-1)' }}>{agent.id}</span>
          {agent.priority !== '—' && (
            <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 9, color: 'var(--op-magenta)', border: '1px solid rgba(255,46,142,0.4)', padding: '0 5px', letterSpacing: '0.1em' }}>{agent.priority}</span>
          )}
        </div>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 9, letterSpacing: '0.12em', color: 'var(--op-fg-3)' }}>{agent.age} ago</span>
      </div>
      <div style={{ fontFamily: 'var(--op-font-display)', fontSize: 14, color: accent ? 'var(--op-fg-1)' : 'var(--op-fg-2)', lineHeight: 1.35 }}>
        {agent.mission}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: dotColor[agent.status] }}>
          {agent.status}
        </span>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, color: 'var(--op-fg-3)' }}>{agent.step}</span>
      </div>
    </div>
  );
}

function FieldTabBar({ active }) {
  const items = [
    { id: 'fleet', label: 'Fleet',   icon: 'layout-grid' },
    { id: 'paged', label: 'Paged',   icon: 'bell-ring', badge: 2 },
    { id: 'comms', label: 'Comms',   icon: 'radio' },
    { id: 'me',    label: 'Me',      icon: 'user' },
  ];
  return (
    <nav style={{
      display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)',
      borderTop: '1px solid var(--op-line)', background: 'var(--op-elev-1)',
    }}>
      {items.map(it => (
        <a key={it.id} href="#" onClick={e => e.preventDefault()} style={{
          textDecoration: 'none',
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
          padding: '12px 0 8px',
          color: it.id === active ? 'var(--op-cyan)' : 'var(--op-fg-3)',
          position: 'relative',
        }}>
          <i data-lucide={it.icon} style={{ width: 18, height: 18 }}></i>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 9, letterSpacing: '0.12em', textTransform: 'uppercase' }}>{it.label}</span>
          {it.badge && (
            <span style={{ position: 'absolute', top: 8, right: 'calc(50% - 18px)', width: 14, height: 14, borderRadius: '50%', background: 'var(--op-magenta)', color: '#05060A', fontFamily: 'var(--op-font-mono)', fontSize: 9, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{it.badge}</span>
          )}
        </a>
      ))}
    </nav>
  );
}

/* ============ AGENT DETAIL ============ */
function FieldAgentDetail() {
  const a = F_AGENTS[0]; // errored agent
  return (
    <FieldShell>
      {/* back / title row */}
      <div style={{ padding: '8px 18px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <a href="#" onClick={e => e.preventDefault()} style={{ display: 'flex', alignItems: 'center', gap: 5, fontFamily: 'var(--op-font-mono)', fontSize: 11, color: 'var(--op-cyan)', textDecoration: 'none', letterSpacing: '0.08em' }}>
          ← FLEET
        </a>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>agent</span>
        <i data-lucide="more-horizontal" style={{ width: 18, height: 18, color: 'var(--op-fg-2)' }}></i>
      </div>

      {/* hero */}
      <div style={{ padding: '6px 18px 14px', borderBottom: '1px solid var(--op-line)', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ width: 10, height: 10, borderRadius: '50%', background: 'var(--op-magenta)', boxShadow: '0 0 10px var(--op-magenta-glow)' }}></span>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 12, color: 'var(--op-fg-1)' }}>{a.id}</span>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, color: 'var(--op-magenta)', border: '1px solid rgba(255,46,142,0.4)', padding: '1px 6px', letterSpacing: '0.1em' }}>P1</span>
        </div>
        <h1 style={{ margin: 0, fontFamily: 'var(--op-font-display)', fontSize: 26, fontWeight: 600, letterSpacing: '-0.02em', lineHeight: 1.1 }}>
          {a.name}
        </h1>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--op-magenta)' }}>
          ▲ errored · step {a.step}
        </span>
        <p style={{ margin: '8px 0 0', fontFamily: 'var(--op-font-display)', fontSize: 15, color: 'var(--op-fg-1)', lineHeight: 1.35 }}>
          {a.mission}
        </p>
      </div>

      {/* trace mini */}
      <div style={{ padding: '14px 18px 6px' }}>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>last events</span>
      </div>
      <div style={{ padding: '0 18px', display: 'flex', flexDirection: 'column', gap: 6, fontFamily: 'var(--op-font-mono)', fontSize: 11, flex: 1, overflow: 'auto' }}>
        <div><span style={{ color: 'var(--op-fg-3)' }}>14:02:07Z</span> <span style={{ color: 'var(--op-magenta)' }}>tool.web.fetch timeout</span></div>
        <div><span style={{ color: 'var(--op-fg-3)' }}>14:01:38Z</span> <span style={{ color: 'var(--op-lime)' }}>tool.web.fetch → 200 OK</span></div>
        <div><span style={{ color: 'var(--op-fg-3)' }}>14:01:35Z</span> <span style={{ color: 'var(--op-fg-2)' }}>thought: parsing index</span></div>
        <div><span style={{ color: 'var(--op-fg-3)' }}>14:01:22Z</span> <span style={{ color: 'var(--op-cyan)' }}>plan: 14 fetches across regions</span></div>
        <div><span style={{ color: 'var(--op-fg-3)' }}>14:01:10Z</span> <span style={{ color: 'var(--op-fg-2)' }}>mission accepted</span></div>
      </div>

      {/* action stack */}
      <div style={{ padding: '14px 14px 18px', display: 'flex', flexDirection: 'column', gap: 8, borderTop: '1px solid var(--op-line)', background: 'var(--op-elev-1)' }}>
        <FieldBigButton tone="cyan"    icon="message-square-quote" label="Intervene" sub="Inject a message into the loop" />
        <div style={{ display: 'flex', gap: 8 }}>
          <FieldBigButton tone="amber"   icon="pause"        label="Pause" sub="Hold mid-step" compact />
          <FieldBigButton tone="magenta" icon="circle-stop"  label="Halt"  sub="Kill the run" compact />
        </div>
      </div>
    </FieldShell>
  );
}

function FieldBigButton({ tone, icon, label, sub, compact }) {
  const map = {
    cyan:    { border: 'rgba(0,229,255,0.4)',  color: 'var(--op-cyan)',    glow: 'var(--op-cyan-glow)' },
    amber:   { border: 'rgba(255,182,39,0.4)', color: 'var(--op-amber)',   glow: 'var(--op-amber-glow)' },
    magenta: { border: 'rgba(255,46,142,0.4)', color: 'var(--op-magenta)', glow: 'var(--op-magenta-glow)' },
  };
  const c = map[tone];
  return (
    <button style={{
      flex: 1,
      background: 'var(--op-elev-2)',
      border: '1px solid ' + c.border,
      boxShadow: '0 0 18px -8px ' + c.glow,
      padding: compact ? '10px 12px' : '14px 16px',
      display: 'flex', alignItems: 'center', gap: 12,
      color: c.color,
      cursor: 'pointer',
      textAlign: 'left',
    }}>
      <i data-lucide={icon} style={{ width: 20, height: 20 }}></i>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 13, fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase' }}>{label}</span>
        {!compact && <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, color: 'var(--op-fg-3)', letterSpacing: '0.08em' }}>{sub}</span>}
      </div>
    </button>
  );
}

/* ============ INTERVENE / COMPOSE ============ */
function FieldIntervene() {
  return (
    <FieldShell>
      <div style={{ padding: '8px 18px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <a href="#" onClick={e => e.preventDefault()} style={{ fontFamily: 'var(--op-font-mono)', fontSize: 11, color: 'var(--op-cyan)', textDecoration: 'none', letterSpacing: '0.08em' }}>← AGENT</a>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>intervene</span>
        <span style={{ width: 18 }}></span>
      </div>

      <div style={{ padding: '4px 18px 12px', borderBottom: '1px solid var(--op-line)' }}>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>agt_p4mb · paused for you</span>
        <h1 style={{ margin: '6px 0 0', fontFamily: 'var(--op-font-display)', fontSize: 24, fontWeight: 600, letterSpacing: '-0.02em', lineHeight: 1.1 }}>
          Tell the agent<br/>what to do next.
        </h1>
      </div>

      {/* prior messages */}
      <div style={{ padding: '14px 18px 6px', display: 'flex', flexDirection: 'column', gap: 12, flex: 1, overflow: 'auto' }}>
        <div style={{ background: 'var(--op-elev-1)', border: '1px solid var(--op-line)', padding: '10px 12px' }}>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>agent · 14:02:07Z</span>
          <p style={{ margin: '6px 0 0', fontFamily: 'var(--op-font-display)', fontSize: 13, color: 'var(--op-fg-1)' }}>
            tool.web.fetch failed (30s timeout). Retry from cache, or abort?
          </p>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>quick replies</span>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {['Retry from cache','Skip this fetch','Switch region','Halt mission'].map(t => (
              <span key={t} style={{ fontFamily: 'var(--op-font-mono)', fontSize: 11, color: 'var(--op-cyan)', border: '1px solid rgba(0,229,255,0.4)', padding: '5px 10px', borderRadius: 999 }}>{t}</span>
            ))}
          </div>
        </div>
      </div>

      {/* composer */}
      <div style={{ padding: '12px 14px 16px', borderTop: '1px solid var(--op-line)', background: 'var(--op-elev-1)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 12px', background: 'var(--op-base)', border: '1px solid var(--op-cyan)', boxShadow: '0 0 18px -8px var(--op-cyan-glow)' }}>
          <span style={{ color: 'var(--op-cyan)', fontFamily: 'var(--op-font-mono)', fontSize: 12 }}>$</span>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 12, color: 'var(--op-fg-1)' }}>retry from cache</span>
          <span style={{ color: 'var(--op-cyan)', animation: 'opBlink 1s steps(2) infinite' }}>▌</span>
          <span style={{ marginLeft: 'auto', fontFamily: 'var(--op-font-mono)', fontSize: 10, color: 'var(--op-cyan)', letterSpacing: '0.1em' }}>SEND</span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10 }}>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, color: 'var(--op-fg-3)', letterSpacing: '0.1em' }}>graduate to policy?</span>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, color: 'var(--op-fg-2)', letterSpacing: '0.1em' }}>OFF</span>
        </div>
      </div>
    </FieldShell>
  );
}

Object.assign(window, { FleetHome, FieldAgentDetail, FieldIntervene });
