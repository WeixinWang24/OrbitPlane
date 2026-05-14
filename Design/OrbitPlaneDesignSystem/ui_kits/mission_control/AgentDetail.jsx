/* global React, Pill, Tag, Label, Button, Icon, Caret, Kbd */
const { useState } = React;

const TRACE = [
  { i: '01', t: '14:01:42Z', kind: 'thought', msg: 'Plan: pull batches 1–20 from queue; summarize each; aggregate.' },
  { i: '02', t: '14:01:43Z', kind: 'tool',    msg: 'tool.db.query(table="inputs", limit=200) → 200 rows' },
  { i: '03', t: '14:01:45Z', kind: 'thought', msg: 'Batch 1 ready (1.2kb avg). Drafting summary...' },
  { i: '04', t: '14:01:47Z', kind: 'tool',    msg: 'tool.llm.summarize(batch=1, model="haiku-4-5") → 412 tokens' },
  { i: '05', t: '14:01:51Z', kind: 'thought', msg: 'Summary OK. Stashing under run_42.batches.01.' },
  { i: '06', t: '14:01:52Z', kind: 'tool',    msg: 'tool.kv.put(run_42.batches.01) → ok' },
  { i: '07', t: '14:01:54Z', kind: 'tool',    msg: 'tool.db.query(table="inputs", offset=200) → 200 rows' },
  { i: '08', t: '14:01:58Z', kind: 'tool',    msg: 'tool.llm.summarize(batch=7) → 380 tokens' },
  { i: '09', t: '14:02:02Z', kind: 'thought', msg: 'Halfway through. ETA ~6m.' },
  { i: '10', t: '14:02:05Z', kind: 'event',   msg: 'operator pinned this run' },
  { i: '11', t: '14:02:09Z', kind: 'tool',    msg: 'tool.web.fetch(url=index.json) → 200 OK · 4.2kb' },
  { i: '12', t: '14:02:11Z', kind: 'thought', msg: 'Cross-referencing index. Tagging duplicates...' },
];

function AgentDetail({ agent, onClose }) {
  const [tab, setTab] = useState('trace');
  const isLive = agent.status === 'running';

  return (
    <div style={{ display: 'grid', gridTemplateRows: 'auto 1fr', height: '100%', overflow: 'hidden' }}>

      {/* HERO */}
      <div className="op-corners" style={{
        background: 'var(--op-elev-1)',
        borderBottom: '1px solid var(--op-line)',
        padding: '18px 24px 20px',
        position: 'relative',
      }}>
        <span className="br"></span>

        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 16 }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, fontFamily: 'var(--op-font-mono)', fontSize: 11, color: 'var(--op-fg-3)', letterSpacing: '0.12em', textTransform: 'uppercase' }}>
              <a href="#" onClick={(e) => { e.preventDefault(); onClose(); }} style={{ color: 'var(--op-fg-3)', textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                <Icon name="arrow-left" size={12} /> deck
              </a>
              <span style={{ color: 'var(--op-fg-4)' }}>/</span>
              <span>agent</span>
              <span style={{ color: 'var(--op-fg-4)' }}>/</span>
              <span style={{ color: 'var(--op-cyan)' }}>{agent.id}</span>
            </div>

            <div style={{ display: 'flex', alignItems: 'baseline', gap: 14 }}>
              <h1 style={{ fontFamily: 'var(--op-font-display)', fontSize: 36, fontWeight: 600, letterSpacing: '-0.02em', margin: 0, color: 'var(--op-fg-1)' }}>
                {agent.name}
              </h1>
              <Pill status={agent.status} />
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: 12, fontFamily: 'var(--op-font-mono)', fontSize: 11, color: 'var(--op-fg-2)', letterSpacing: '0.02em', flexWrap: 'wrap' }}>
              <span>step <span style={{ color: 'var(--op-fg-1)' }}>{agent.step}</span></span>
              <span style={{ color: 'var(--op-fg-4)' }}>·</span>
              <span>{agent.version}</span>
              <span style={{ color: 'var(--op-fg-4)' }}>·</span>
              <span>uptime {agent.age}</span>
              <span style={{ color: 'var(--op-fg-4)' }}>·</span>
              <span>model haiku-4-5</span>
              <span style={{ color: 'var(--op-fg-4)' }}>·</span>
              <span>cost $0.42</span>
            </div>

            <div style={{ marginTop: 4, fontFamily: 'var(--op-font-display)', fontSize: 16, color: 'var(--op-fg-1)', maxWidth: 720 }}>
              {agent.mission}{isLive ? <Caret /> : null}
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, alignItems: 'flex-end' }}>
            <div style={{ display: 'flex', gap: 6 }}>
              <Button variant="primary" size="sm" icon="message-square-quote">Intervene</Button>
              <Button size="sm" icon="pause">Pause</Button>
              <Button variant="danger" size="sm" icon="circle-stop">Halt</Button>
            </div>
            <div style={{ display: 'flex', gap: 6 }}>
              <Button size="sm" icon="git-fork">Fork</Button>
              <Button size="sm" icon="history">Replay</Button>
              <Button size="sm" icon="graduation-cap">Graduate</Button>
            </div>
          </div>
        </div>

        {/* progress strip */}
        <div style={{ marginTop: 18, display: 'flex', alignItems: 'center', gap: 12 }}>
          <span className="op-label">progress</span>
          <div style={{ flex: 1, height: 6, background: 'var(--op-elev-3)', position: 'relative' }}>
            <div style={{ position: 'absolute', inset: 0, width: '70%', background: 'linear-gradient(90deg, var(--op-cyan), var(--op-lime))', boxShadow: '0 0 12px var(--op-cyan-glow)' }}></div>
            {[0, 25, 50, 75, 100].map(p => (
              <div key={p} style={{ position: 'absolute', left: `${p}%`, top: -3, width: 1, height: 12, background: 'var(--op-line-2)' }}></div>
            ))}
          </div>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 11, color: 'var(--op-fg-2)' }}>14/20</span>
        </div>
      </div>

      {/* BODY */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 280px', gap: 0, overflow: 'hidden', minHeight: 0 }}>

        {/* trace */}
        <div style={{ display: 'flex', flexDirection: 'column', borderRight: '1px solid var(--op-line)', overflow: 'hidden' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, padding: '10px 20px', borderBottom: '1px solid var(--op-line)' }}>
            {['trace', 'code', 'tools', 'cost'].map(t => (
              <button key={t} onClick={() => setTab(t)} style={{
                background: 'transparent', border: 'none', cursor: 'pointer',
                fontFamily: 'var(--op-font-mono)', fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase',
                color: tab === t ? 'var(--op-cyan)' : 'var(--op-fg-3)',
                padding: '6px 0',
                borderBottom: tab === t ? '1px solid var(--op-cyan)' : '1px solid transparent',
              }}>{t}</button>
            ))}
            <span style={{ marginLeft: 'auto', display: 'flex', gap: 6, alignItems: 'center' }}>
              <Kbd>J</Kbd><Kbd>K</Kbd>
              <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, color: 'var(--op-fg-3)', letterSpacing: '0.1em', textTransform: 'uppercase' }}>step</span>
            </span>
          </div>

          <div style={{ overflow: 'auto', padding: '4px 0' }}>
            {TRACE.map((step, i) => {
              const tone = step.kind === 'thought' ? 'var(--op-fg-2)' : step.kind === 'tool' ? 'var(--op-lime)' : 'var(--op-cyan)';
              const isLatest = i === TRACE.length - 1;
              return (
                <div key={step.i} style={{
                  display: 'grid', gridTemplateColumns: '40px 80px 70px 1fr', gap: 12,
                  alignItems: 'baseline',
                  padding: '8px 20px',
                  borderBottom: '1px dashed var(--op-line)',
                  fontFamily: 'var(--op-font-mono)', fontSize: 12,
                  background: isLatest ? 'rgba(0,229,255,0.025)' : 'transparent',
                }}>
                  <span style={{ color: 'var(--op-fg-3)', letterSpacing: '0.1em' }}>{step.i}</span>
                  <span style={{ color: 'var(--op-fg-3)' }}>{step.t}</span>
                  <span style={{ color: tone, letterSpacing: '0.1em', textTransform: 'uppercase', fontSize: 10 }}>{step.kind}</span>
                  <span style={{ color: step.kind === 'thought' ? 'var(--op-fg-2)' : 'var(--op-fg-1)', fontStyle: step.kind === 'thought' ? 'italic' : 'normal' }}>
                    {step.msg}{isLatest && isLive ? <Caret /> : null}
                  </span>
                </div>
              );
            })}
          </div>
        </div>

        {/* sidebar — controls / metrics */}
        <aside style={{ background: 'var(--op-elev-1)', display: 'flex', flexDirection: 'column', overflow: 'auto' }}>
          <div style={{ padding: '14px 16px', borderBottom: '1px solid var(--op-line)' }}>
            <Label>tools</Label>
            <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 6, fontFamily: 'var(--op-font-mono)', fontSize: 11 }}>
              {[
                ['web.fetch', 18, 'var(--op-lime)'],
                ['db.query', 12, 'var(--op-lime)'],
                ['kv.put', 8, 'var(--op-lime)'],
                ['llm.summarize', 7, 'var(--op-cyan)'],
              ].map(([n, c, col]) => (
                <div key={n} style={{ display: 'flex', justifyContent: 'space-between', color: 'var(--op-fg-2)' }}>
                  <span>tool.{n}</span><span style={{ color: col }}>{c}</span>
                </div>
              ))}
            </div>
          </div>

          <div style={{ padding: '14px 16px', borderBottom: '1px solid var(--op-line)' }}>
            <Label>cost · last 1h</Label>
            <div style={{ marginTop: 10, fontFamily: 'var(--op-font-mono)', fontSize: 22, color: 'var(--op-fg-1)' }}>$0.42</div>
            <div style={{ display: 'flex', alignItems: 'flex-end', gap: 2, marginTop: 8, height: 32 }}>
              {[0.3, 0.5, 0.4, 0.6, 0.5, 0.8, 0.7, 0.9, 0.6, 0.8, 0.7, 0.9].map((h, i) => (
                <div key={i} style={{ flex: 1, height: `${h * 100}%`, background: 'var(--op-cyan)', opacity: 0.4 + (i / 24) }}></div>
              ))}
            </div>
          </div>

          <div style={{ padding: '14px 16px', borderBottom: '1px solid var(--op-line)' }}>
            <Label>tags</Label>
            <div style={{ marginTop: 10, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              <Tag>[ digest ]</Tag>
              <Tag>[ scheduled ]</Tag>
              <Tag color>[ orbit/main ]</Tag>
            </div>
          </div>

          <div style={{ padding: '14px 16px' }}>
            <Label>graduate to policy</Label>
            <p style={{ fontFamily: 'var(--op-font-display)', fontSize: 12, color: 'var(--op-fg-2)', lineHeight: 1.4, marginTop: 8 }}>
              Promote this run's intervention pattern to a permanent policy on the agent.
            </p>
            <Button variant="primary" size="sm" icon="graduation-cap">Open graduation</Button>
          </div>
        </aside>
      </div>
    </div>
  );
}

Object.assign(window, { AgentDetail });
