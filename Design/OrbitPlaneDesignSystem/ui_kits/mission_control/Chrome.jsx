/* global React, Icon, Pill, Label, Button, Caret, Kbd */
const { useState } = React;

function TopBar({ route, onRoute }) {
  return (
    <header className="mc-topbar">
      <div style={{ display: 'flex', alignItems: 'center', padding: '0 18px', borderRight: '1px solid var(--op-line)', width: 220 - 1 + 'px', boxSizing: 'border-box', gap: 10 }}>
        <img src="../../assets/logo-mark.svg" width="22" height="22" alt="" />
        <div style={{ fontFamily: 'var(--op-font-mono)', fontSize: 12, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-1)', fontWeight: 700 }}>
          OrbitPlane
        </div>
        <span style={{ marginLeft: 'auto', fontFamily: 'var(--op-font-mono)', fontSize: 9, color: 'var(--op-fg-3)', letterSpacing: '0.12em' }}>v3.2.1</span>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '0 18px', flex: 1 }}>
        <span className="op-label">deck // mission control</span>
        <span style={{ color: 'var(--op-fg-4)' }}>/</span>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 12, color: 'var(--op-fg-1)', letterSpacing: '0.04em' }}>fleet · primary</span>

        <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 10, height: 32, padding: '0 10px', minWidth: 320, background: 'var(--op-base)', border: '1px solid var(--op-line)', borderRadius: 2 }}>
          <Icon name="search" size={13} color="var(--op-fg-3)" />
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 12, color: 'var(--op-fg-3)' }}>search agents, runs, traces</span>
          <span style={{ marginLeft: 'auto', display: 'flex', gap: 4 }}><Kbd>⌘</Kbd><Kbd>K</Kbd></span>
        </div>

        <Button variant="primary" size="sm" icon="rocket">Deploy</Button>

        <div style={{ display: 'flex', alignItems: 'center', gap: 8, paddingLeft: 14, marginLeft: 4, borderLeft: '1px solid var(--op-line)', height: 30 }}>
          <span style={{ width: 24, height: 24, borderRadius: 2, background: 'var(--op-elev-3)', border: '1px solid var(--op-line-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--op-font-mono)', fontSize: 11, color: 'var(--op-cyan)' }}>w</span>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 11, color: 'var(--op-fg-2)' }}>w.wang</span>
        </div>
      </div>
    </header>
  );
}

function Sidebar({ route, onRoute }) {
  const nav = [
    { id: 'deck',     label: 'Deck',        icon: 'layout-grid', count: 14, active: true },
    { id: 'missions', label: 'Missions',    icon: 'flag',        count: 42 },
    { id: 'runs',     label: 'Runs',        icon: 'play',        count: '1.4k' },
    { id: 'replays',  label: 'Replays',     icon: 'history',     count: 8 },
    { id: 'tools',    label: 'Tools',       icon: 'wrench',      count: 23 },
    { id: 'policies', label: 'Policies',    icon: 'shield',      count: 11 },
  ];
  const ops = [
    { id: 'paged',    label: 'Paged me',    icon: 'bell-ring',   pill: 'errored' },
    { id: 'pinned',   label: 'Pinned',      icon: 'bookmark' },
    { id: 'settings', label: 'Settings',    icon: 'settings-2' },
  ];

  const Row = ({ item }) => (
    <a href="#" onClick={(e) => { e.preventDefault(); onRoute && onRoute(item.id); }} style={{
      display: 'flex', alignItems: 'center', gap: 10, padding: '7px 14px',
      borderLeft: '2px solid ' + (item.active ? 'var(--op-cyan)' : 'transparent'),
      background: item.active ? 'var(--op-elev-2)' : 'transparent',
      color: item.active ? 'var(--op-fg-1)' : 'var(--op-fg-2)',
      textDecoration: 'none',
      fontFamily: 'var(--op-font-mono)', fontSize: 12, letterSpacing: '0.02em',
    }}>
      <Icon name={item.icon} size={14} color={item.active ? 'var(--op-cyan)' : 'currentColor'} />
      <span>{item.label}</span>
      {item.count ? <span style={{ marginLeft: 'auto', fontSize: 10, color: 'var(--op-fg-3)' }}>{item.count}</span> : null}
      {item.pill === 'errored' ? <span style={{ marginLeft: 'auto', width: 6, height: 6, borderRadius: '50%', background: 'var(--op-magenta)', boxShadow: '0 0 6px var(--op-magenta)' }}></span> : null}
    </a>
  );

  return (
    <aside className="mc-sidebar">
      <div style={{ padding: '14px 16px 8px' }}>
        <Label>fleet</Label>
      </div>
      <nav style={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
        {nav.map(n => <Row key={n.id} item={n} />)}
      </nav>

      <div style={{ padding: '18px 16px 8px' }}>
        <Label>ops</Label>
      </div>
      <nav style={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
        {ops.map(n => <Row key={n.id} item={n} />)}
      </nav>

      <div style={{ marginTop: 'auto', padding: 14, borderTop: '1px solid var(--op-line)' }}>
        <div style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.12em', color: 'var(--op-fg-3)', marginBottom: 6 }}>UPLINK</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: 'var(--op-font-mono)', fontSize: 11, color: 'var(--op-lime)' }}>
          <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--op-lime)', boxShadow: '0 0 6px var(--op-lime)', animation: 'opPulse 1.4s infinite' }}></span>
          stable · 42ms
        </div>
        <div style={{ display: 'flex', gap: 1, marginTop: 8, height: 14 }}>
          {[0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.4, 0.55, 0.7, 0.5, 0.8, 0.6, 0.7, 0.9, 0.4, 0.6, 0.8, 0.5, 0.7, 0.6].map((h, i) => (
            <div key={i} style={{ flex: 1, height: `${h * 100}%`, alignSelf: 'flex-end', background: i === 19 ? 'var(--op-lime)' : 'var(--op-line-3)' }}></div>
          ))}
        </div>
      </div>
    </aside>
  );
}

function BottomBar({ counts }) {
  return (
    <div className="mc-bottombar">
      <span>● fleet primary</span>
      <span style={{ color: 'var(--op-fg-4)' }}>/</span>
      <span>14 agents</span>
      <span style={{ color: 'var(--op-fg-4)' }}>/</span>
      <span style={{ color: 'var(--op-lime)' }}>{counts.running} running</span>
      <span style={{ color: 'var(--op-amber)' }}>{counts.queued} queued</span>
      <span style={{ color: 'var(--op-magenta)' }}>{counts.errored} errored</span>
      <span style={{ marginLeft: 'auto' }}>tick 14:02:11Z</span>
      <span style={{ color: 'var(--op-fg-4)' }}>/</span>
      <span>uplink 42ms</span>
      <span style={{ color: 'var(--op-fg-4)' }}>/</span>
      <span><span style={{ color: 'var(--op-lime)' }}>◉</span> orbit-eu-west-2</span>
    </div>
  );
}

Object.assign(window, { TopBar, Sidebar, BottomBar });
