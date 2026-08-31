import type { EntryState } from '../../types/entry'

interface EntryShellProps {
  state: EntryState
  onRetry?: () => void
}

export function EntryShell({ state, onRetry }: EntryShellProps) {
  const selected = state.view === 'arrivalLoading' || state.view === 'spawning'
  const spawning = state.view === 'spawning'
  const failed = state.view === 'error'

  return (
    <main className="entry-shell" data-view={state.view} aria-live="polite">
      <div className="atmosphere" aria-hidden="true">
        <div className="plane plane-near" />
        <div className="plane plane-far" />
      </div>

      <header className="brand-lockup">
        <span className="brand-mark">UP</span>
        <span className="brand-name">Universo Paralelo</span>
      </header>

      <section className="entry-copy">
        <p className="eyebrow"><span>01</span> {selected ? 'Identidade confirmada' : 'Travessia em curso'}</p>
        <h1>{selected ? <>Seu universo<br />aguarda.</> : <>Entre dois<br />mundos.</>}</h1>
        <p className="supporting-copy">{spawning ? 'Sua chegada foi autorizada. Preparando o mundo ao seu redor.' : 'Sua identidade está sendo sincronizada com este universo.'}</p>

        <div className="status-line">
          <span className="status-pulse" aria-hidden="true" />
          <span>{failed ? state.error ?? 'Não foi possível concluir a travessia' : spawning ? 'Materializando personagem' : selected ? 'Preparando locais de chegada' : 'Preparando suas identidades'}</span>
        </div>
        {failed && onRetry && <button className="text-action shell-retry" type="button" onClick={onRetry}>Tentar novamente</button>}
      </section>

      <footer className="coordinates">
        <span>UP // ENTRY</span>
        <span>PROTOCOLO 01</span>
        <span className="coordinate-value">15°35′S · 56°06′W</span>
      </footer>
    </main>
  )
}
