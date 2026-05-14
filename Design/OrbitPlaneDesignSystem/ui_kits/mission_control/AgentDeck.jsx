/* global React, Pill, Tag, Label, Button, Icon, Caret */
const { useState, useEffect } = React;

function AgentCard({ agent, focused, onClick }) {
  const isLive = agent.status === 'running';
  const barColor = {
    running: 'var(--op-lime)',
    paused:  'var(--op-amber)',
    queued:  'var(--op-amber)',
    errored: 'var(--op-magenta)',
    done:    'var(--op-cyan)',
    idle:    'var(--op-fg-3)',
  }[agent.status] || 'var(--op-fg-3)';

  return (
    <div
      onClick={onClick}
      className={focused ? 'op-corners' : ''}
      style={{
        background: focused ? 'var(--op-elev-3)' : 'var(--op-elev-2)',
        border: '1px solid ' + (focused ? 'rgba(0,229,255,0.4)' : 'var(--op-line)'),
        padding: '12px 14px 14px',
        display: 'flex', flexDirection: 'column', gap: 10,
        cursor: 'pointer',
        position: 'relative',
        boxShadow: focused ? '0 0 24px -8px var(--op-cyan-glow)' : 'none',
        transition: 'all 160ms cubic-bezier(.2,.7,.1,1)',
      }}
    >
      {focused && <span className="br"></span>}
      {/* top */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{
            width: 22, height: 22, display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            background: 'var(--op-elev-1)', border: '1px solid var(--op-line-2)',
            fontFamily: 'var(--op-font-mono)', fontSize: 10, color: barColor,
          }}>{agent.id.slice(4, 6)}</span>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 12, color: 'var(--op-fg-1)', letterSpacing: '0.02em' }}>
            {agent.id}
          </span>
        </div>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 9, letterSpacing: '0.12em', color: 'var(--op-fg-3)' }}>{agent.age} ago</span>
      </div>

      {/* name */}
      <div style={{ fontFamily: 'var(--op-font-display)', fontSize: 13, color: 'var(--op-fg-2)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>
        {agent.name}
      </div>

      {/* mission */}
      <div style={{ fontFamily: 'var(--op-font-display)', fontSize: 14, color: 'var(--op-fg-1)', lineHeight: 1.35, minHeight: 38 }}>
        {agent.mission}{isLive ? <Caret /> : null}
      </div>

      {/* meta row */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
        <Pill status={agent.status} />
        <div style={{ display: 'flex', gap: 8, fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.1em', color: 'var(--op-fg-3)', textTransform: 'uppercase' }}>
          <span>{agent.step}</span>
          <span style={{ color: 'var(--op-fg-4)' }}>·</span>
          <span>{agent.version}</span>
        </div>
      </div>
    </div>
  );
}

function AgentGrid({ agents, focusId, onPick }) {
  return (
    <div style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 14, overflow: 'auto', height: '100%' }}>
      {/* page header */}
      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', paddingBottom: 6 }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <Label>agents // 14 active</Label>
          <h1 style={{ fontFamily: 'var(--op-font-display)', fontSize: 32, fontWeight: 600, letterSpacing: '-0.02em', margin: 0, color: 'var(--op-fg-1)' }}>
            The deck<span style={{ color: 'var(--op-cyan)' }}>.</span>
          </h1>
          <span style={{ fontFamily: 'var(--op-font-display)', fontSize: 13, color: 'var(--op-fg-2)' }}>
            5 running · 1 queued · 1 errored. Last tick 14:02:11Z.
          </span>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <Button size="sm" icon="filter">Filter</Button>
          <Button size="sm" icon="layout-grid">Grid</Button>
          <Button size="sm" icon="list">List</Button>
        </div>
      </div>

      {/* grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))', gap: 10 }}>
        {agents.map(a => (
          <AgentCard key={a.id} agent={a} focused={a.id === focusId} onClick={() => onPick(a.id)} />
        ))}
      </div>
    </div>
  );
}

function ActivityFeed({ feed }) {
  const colorOf = (tone) => ({
    lime: 'var(--op-lime)',
    cyan: 'var(--op-cyan)',
    magenta: 'var(--op-magenta)',
    amber: 'var(--op-amber)',
    mute: 'var(--op-fg-3)',
  }[tone] || 'var(--op-fg-2)');

  return (
    <aside style={{
      borderLeft: '1px solid var(--op-line)', background: 'var(--op-elev-1)',
      display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 16px', borderBottom: '1px solid var(--op-line)' }}>
        <Label>activity // live</Label>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontFamily: 'var(--op-font-mono)', fontSize: 10, color: 'var(--op-lime)' }}>
          <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--op-lime)', animation: 'opPulse 1.4s infinite' }}></span>
          streaming
        </div>
      </div>
      <div style={{ flex: 1, overflow: 'auto', padding: '6px 0' }}>
        {feed.map((row, i) => (
          <div key={i} style={{
            display: 'grid',
            gridTemplateColumns: '74px 1fr',
            gap: 10,
            padding: '8px 16px',
            borderBottom: '1px dashed var(--op-line)',
            fontFamily: 'var(--op-font-mono)', fontSize: 11, letterSpacing: '0.02em',
          }}>
            <span style={{ color: 'var(--op-fg-3)' }}>{row.t}</span>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
              <span style={{ color: 'var(--op-fg-2)' }}>
                <span style={{ color: 'var(--op-cyan)' }}>{row.who}</span>
                <span style={{ color: 'var(--op-fg-4)' }}> · </span>
                <span style={{ color: 'var(--op-fg-3)' }}>{row.kind}</span>
              </span>
              <span style={{ color: colorOf(row.tone), fontStyle: row.kind === 'thought' ? 'italic' : 'normal' }}>{row.msg}</span>
            </div>
          </div>
        ))}
      </div>
      <div style={{ padding: 12, borderTop: '1px solid var(--op-line)', display: 'flex', gap: 6, alignItems: 'center' }}>
        <Icon name="filter" size={12} color="var(--op-fg-3)" />
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, color: 'var(--op-fg-3)', letterSpacing: '0.1em', textTransform: 'uppercase' }}>filter: all events</span>
      </div>
    </aside>
  );
}

Object.assign(window, { AgentCard, AgentGrid, ActivityFeed });
