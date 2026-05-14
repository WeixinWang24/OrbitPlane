/* global React */
const { useState } = React;

const STEPS = [
  { n: 1, title: 'Pick a retry strategy',     done: true,  active: false },
  { n: 2, title: 'Add a cache fallback',       done: true,  active: false },
  { n: 3, title: 'Wire up the policy',         done: false, active: true  },
  { n: 4, title: 'Replay against agt_p4mb',    done: false, active: false },
  { n: 5, title: 'Graduate to production',     done: false, active: false },
];

const DIFF = [
  { kind: 'meta', no: '',    text: 'policy/retry.ts',  comment: '' },
  { kind: 'ctx',  no: 12,    text: 'export const retry = {' },
  { kind: 'ctx',  no: 13,    text: '  maxAttempts: 3,' },
  { kind: 'del',  no: 14,    text: '  backoff: "linear",' },
  { kind: 'add',  no: 14,    text: '  backoff: "exponential",' },
  { kind: 'add',  no: 15,    text: '  fallback: "cache",' },
  { kind: 'add',  no: 16,    text: '  onTimeout: (ctx) => ctx.skip("fetch")' },
  { kind: 'ctx',  no: 17,    text: '} satisfies RetryPolicy;' },
  { kind: 'ctx',  no: 18,    text: '' },
  { kind: 'ctx',  no: 19,    text: 'agent.attach(retry);' },
];

function CodexShell() {
  const [tab, setTab] = useState('diff');

  return (
    <div style={{
      height: '100vh', minHeight: 760, minWidth: 1280,
      display: 'grid', gridTemplateRows: '48px 1fr 28px', gridTemplateColumns: '300px 1fr 380px',
      gridTemplateAreas: '"top top top" "nav main side" "bot bot bot"',
      background: 'var(--op-base)', color: 'var(--op-fg-1)', fontFamily: 'var(--op-font-display)',
    }}>
      {/* topbar */}
      <header style={{ gridArea: 'top', borderBottom: '1px solid var(--op-line)', background: 'var(--op-elev-1)', display: 'flex', alignItems: 'center', padding: '0 18px', gap: 14 }}>
        <img src="../../assets/logo-mark.svg" width="22" height="22" />
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 12, fontWeight: 700, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-1)' }}>OrbitPlane</span>
        <span style={{ color: 'var(--op-fg-4)', fontFamily: 'var(--op-font-mono)' }}>/</span>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 11, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>codex // tutorials</span>
        <span style={{ color: 'var(--op-fg-4)', fontFamily: 'var(--op-font-mono)' }}>/</span>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 12, color: 'var(--op-cyan)' }}>retry-with-cache</span>

        <div style={{ marginLeft: 'auto', display: 'flex', gap: 8, alignItems: 'center' }}>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>step 3 of 5</span>
          <span style={{ width: 140, height: 4, background: 'var(--op-elev-3)', position: 'relative' }}>
            <span style={{ position: 'absolute', inset: 0, width: '40%', background: 'var(--op-cyan)', boxShadow: '0 0 8px var(--op-cyan-glow)' }}></span>
          </span>
        </div>
      </header>

      {/* nav */}
      <aside style={{ gridArea: 'nav', borderRight: '1px solid var(--op-line)', background: 'var(--op-elev-1)', overflow: 'auto' }}>
        <div style={{ padding: '14px 18px 8px' }}>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>tutorial</span>
          <h2 style={{ margin: '4px 0 6px', fontFamily: 'var(--op-font-display)', fontSize: 17, fontWeight: 600, color: 'var(--op-fg-1)' }}>
            Retry with cache fallback
          </h2>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, color: 'var(--op-fg-3)', letterSpacing: '0.08em' }}>~8 min · policy/retry.ts</span>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {STEPS.map(s => (
            <div key={s.n} style={{
              padding: '10px 18px',
              borderLeft: '2px solid ' + (s.active ? 'var(--op-cyan)' : 'transparent'),
              background: s.active ? 'var(--op-elev-2)' : 'transparent',
              display: 'flex', alignItems: 'center', gap: 12,
              fontFamily: 'var(--op-font-mono)', fontSize: 12,
              color: s.active ? 'var(--op-fg-1)' : s.done ? 'var(--op-fg-2)' : 'var(--op-fg-3)',
            }}>
              <span style={{
                width: 18, height: 18,
                border: '1px solid ' + (s.done ? 'var(--op-lime)' : s.active ? 'var(--op-cyan)' : 'var(--op-line-2)'),
                color: s.done ? 'var(--op-lime)' : s.active ? 'var(--op-cyan)' : 'var(--op-fg-3)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 10, fontWeight: 700, letterSpacing: 0,
              }}>{s.done ? '✓' : s.n}</span>
              <span style={{ fontFamily: 'var(--op-font-display)', fontSize: 13, lineHeight: 1.3 }}>{s.title}</span>
            </div>
          ))}
        </div>

        <div style={{ padding: 18, borderTop: '1px solid var(--op-line)', marginTop: 10 }}>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>files</span>
          <div style={{ marginTop: 8, display: 'flex', flexDirection: 'column', gap: 4, fontFamily: 'var(--op-font-mono)', fontSize: 11 }}>
            <FileRow path="policy/retry.ts" diff="+3 −1" active />
            <FileRow path="policy/index.ts" diff="" />
            <FileRow path="tests/retry.spec.ts" diff="+12 −0" />
          </div>
        </div>
      </aside>

      {/* main */}
      <main style={{ gridArea: 'main', display: 'grid', gridTemplateRows: '36px 1fr 1fr', overflow: 'hidden' }}>
        {/* tabs */}
        <div style={{ display: 'flex', alignItems: 'stretch', borderBottom: '1px solid var(--op-line)', background: 'var(--op-elev-1)' }}>
          {['diff','editor','tests'].map(t => (
            <button key={t} onClick={() => setTab(t)} style={{
              background: 'transparent', border: 'none', cursor: 'pointer',
              fontFamily: 'var(--op-font-mono)', fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase',
              color: tab === t ? 'var(--op-cyan)' : 'var(--op-fg-3)',
              padding: '0 18px',
              borderBottom: tab === t ? '1px solid var(--op-cyan)' : '1px solid transparent',
              marginBottom: -1,
            }}>{t}</button>
          ))}
          <span style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 12, padding: '0 16px', fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>
            policy/retry.ts <span style={{ color: 'var(--op-lime)' }}>+3</span> <span style={{ color: 'var(--op-magenta)' }}>−1</span>
          </span>
        </div>

        {/* DIFF */}
        <div style={{ overflow: 'auto', background: 'var(--op-base)', borderBottom: '1px solid var(--op-line)', paddingBottom: 12 }}>
          {DIFF.map((d, i) => <DiffLine key={i} line={d} />)}
        </div>

        {/* TERMINAL */}
        <div style={{ background: '#05060A', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 16px', borderBottom: '1px solid var(--op-line)' }}>
            <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>terminal // sandbox</span>
            <span style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 5, fontFamily: 'var(--op-font-mono)', fontSize: 10, color: 'var(--op-lime)', letterSpacing: '0.1em' }}>
              <span style={{ width: 5, height: 5, borderRadius: '50%', background: 'var(--op-lime)', boxShadow: '0 0 6px var(--op-lime)' }}></span>passing
            </span>
          </div>
          <div style={{ padding: '10px 16px', fontFamily: 'var(--op-font-mono)', fontSize: 12, color: 'var(--op-fg-2)', overflow: 'auto', display: 'flex', flexDirection: 'column', gap: 4, flex: 1 }}>
            <div><span style={{ color: 'var(--op-cyan)' }}>$</span> orbit test policy/retry</div>
            <div style={{ color: 'var(--op-fg-3)' }}>·· loading sandbox runtime</div>
            <div style={{ color: 'var(--op-fg-3)' }}>·· replaying run_42 against patched policy</div>
            <div><span style={{ color: 'var(--op-lime)' }}>✓</span> retries: exponential backoff applied (3 attempts)</div>
            <div><span style={{ color: 'var(--op-lime)' }}>✓</span> cache fallback returned 1.2kb after 2nd timeout</div>
            <div><span style={{ color: 'var(--op-lime)' }}>✓</span> mission resumed at step 03/14</div>
            <div style={{ color: 'var(--op-fg-3)' }}>·· 12 assertions in 412ms</div>
            <div><span style={{ color: 'var(--op-cyan)' }}>$</span> <span style={{ color: 'var(--op-fg-1)' }}>orbit graduate retry-with-cache</span><span style={{ color: 'var(--op-cyan)', animation: 'opBlink 1s steps(2) infinite' }}>▌</span></div>
          </div>
        </div>
      </main>

      {/* SIDE — narrative */}
      <aside style={{ gridArea: 'side', borderLeft: '1px solid var(--op-line)', background: 'var(--op-elev-1)', overflow: 'auto', padding: '20px 22px' }}>
        <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>step 3 // wire up</span>
        <h2 style={{ margin: '8px 0 6px', fontFamily: 'var(--op-font-display)', fontSize: 22, fontWeight: 600, letterSpacing: '-0.02em', color: 'var(--op-fg-1)' }}>
          Make the retry policy<br/>resilient<span style={{ color: 'var(--op-cyan)' }}>.</span>
        </h2>
        <p style={{ fontFamily: 'var(--op-font-display)', fontSize: 14, color: 'var(--op-fg-2)', lineHeight: 1.5 }}>
          Switch <code style={{ fontFamily: 'var(--op-font-mono)', fontSize: 12, color: 'var(--op-cyan)' }}>backoff</code> to exponential, then add a cache fallback. The agent will pull the last known good response when the network stalls.
        </p>

        <div style={{ marginTop: 18, padding: '12px 14px', border: '1px solid rgba(0,229,255,0.25)', background: 'rgba(0,229,255,0.04)', display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-cyan)' }}>→ try it</span>
          <p style={{ margin: 0, fontFamily: 'var(--op-font-display)', fontSize: 13, color: 'var(--op-fg-1)', lineHeight: 1.4 }}>
            Apply the diff, then run the sandbox replay. The errored run for <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 12, color: 'var(--op-cyan)' }}>agt_p4mb</span> should now succeed at step 3.
          </p>
        </div>

        <div style={{ marginTop: 18 }}>
          <span style={{ fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>hint</span>
          <p style={{ marginTop: 6, fontFamily: 'var(--op-font-display)', fontSize: 13, color: 'var(--op-fg-2)', lineHeight: 1.45 }}>
            <code style={{ fontFamily: 'var(--op-font-mono)', fontSize: 12, color: 'var(--op-fg-2)' }}>onTimeout</code> receives the full tool context — return <code style={{ fontFamily: 'var(--op-font-mono)', fontSize: 12, color: 'var(--op-cyan)' }}>ctx.skip(name)</code> to advance without failing the mission.
          </p>
        </div>

        <div style={{ marginTop: 24, display: 'flex', gap: 8 }}>
          <button style={{ fontFamily: 'var(--op-font-mono)', fontSize: 11, letterSpacing: '0.08em', textTransform: 'uppercase', padding: '8px 14px', border: '1px solid var(--op-line-2)', background: 'transparent', color: 'var(--op-fg-2)', cursor: 'pointer' }}>← Back</button>
          <button style={{ flex: 1, fontFamily: 'var(--op-font-mono)', fontSize: 11, letterSpacing: '0.08em', textTransform: 'uppercase', padding: '8px 14px', border: '1px solid var(--op-cyan)', background: 'rgba(0,229,255,0.05)', color: 'var(--op-cyan)', boxShadow: '0 0 18px -6px var(--op-cyan-glow)', cursor: 'pointer' }}>Run sandbox →</button>
        </div>
      </aside>

      {/* bottom */}
      <div style={{ gridArea: 'bot', borderTop: '1px solid var(--op-line)', background: 'var(--op-elev-1)', display: 'flex', alignItems: 'center', padding: '0 16px', gap: 14, fontFamily: 'var(--op-font-mono)', fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--op-fg-3)' }}>
        <span>● branch: retry-with-cache</span>
        <span style={{ color: 'var(--op-fg-4)' }}>/</span>
        <span><span style={{ color: 'var(--op-lime)' }}>+15</span> <span style={{ color: 'var(--op-magenta)' }}>−1</span></span>
        <span style={{ color: 'var(--op-fg-4)' }}>/</span>
        <span>tests <span style={{ color: 'var(--op-lime)' }}>12/12</span></span>
        <span style={{ marginLeft: 'auto' }}>⌘↩ run · ⌘→ next step · ⌘G graduate</span>
      </div>
    </div>
  );
}

function FileRow({ path, diff, active }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '4px 8px',
      background: active ? 'var(--op-elev-3)' : 'transparent',
      color: active ? 'var(--op-fg-1)' : 'var(--op-fg-2)',
      borderLeft: '2px solid ' + (active ? 'var(--op-cyan)' : 'transparent'),
      marginLeft: -8,
    }}>
      <span>{path}</span>
      {diff && (
        <span style={{ color: 'var(--op-fg-3)', fontSize: 10 }}>
          {diff.split(' ').map((d, i) => (
            <span key={i} style={{ color: d.startsWith('+') ? 'var(--op-lime)' : 'var(--op-magenta)' }}>{d} </span>
          ))}
        </span>
      )}
    </div>
  );
}

function DiffLine({ line }) {
  if (line.kind === 'meta') {
    return (
      <div style={{ padding: '8px 16px', borderBottom: '1px solid var(--op-line)', fontFamily: 'var(--op-font-mono)', fontSize: 11, letterSpacing: '0.08em', color: 'var(--op-fg-3)' }}>
        <span style={{ color: 'var(--op-cyan)' }}>───</span> {line.text}
      </div>
    );
  }
  const colors = {
    add: { bg: 'rgba(184,255,60,0.06)', gut: 'var(--op-lime)',    text: 'var(--op-fg-1)',  sign: '+' },
    del: { bg: 'rgba(255,46,142,0.06)', gut: 'var(--op-magenta)', text: 'var(--op-fg-2)',  sign: '−' },
    ctx: { bg: 'transparent',           gut: 'var(--op-fg-3)',    text: 'var(--op-fg-2)',  sign: ' ' },
  }[line.kind];
  return (
    <div style={{
      display: 'grid', gridTemplateColumns: '50px 14px 1fr',
      background: colors.bg,
      fontFamily: 'var(--op-font-mono)', fontSize: 12, lineHeight: 1.6,
    }}>
      <span style={{ textAlign: 'right', paddingRight: 12, color: colors.gut, opacity: 0.7 }}>{line.no || ''}</span>
      <span style={{ color: colors.gut, fontWeight: 700 }}>{colors.sign}</span>
      <span style={{ color: colors.text, whiteSpace: 'pre' }}>{line.text}</span>
    </div>
  );
}

Object.assign(window, { CodexShell });
