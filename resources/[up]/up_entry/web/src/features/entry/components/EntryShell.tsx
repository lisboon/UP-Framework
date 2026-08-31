import type { EntryState } from '../model/entryReducer'

interface EntryShellProps {
  state: EntryState
}

export function EntryShell({ state }: EntryShellProps) {
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
        <p className="eyebrow"><span>01</span> Travessia em curso</p>
        <h1>Entre dois<br />mundos.</h1>
        <p className="supporting-copy">Sua identidade está sendo sincronizada com este universo.</p>

        <div className="status-line">
          <span className="status-pulse" aria-hidden="true" />
          <span>{state.view === 'error' ? state.message ?? 'Não foi possível concluir a travessia' : 'Preparando sua chegada'}</span>
        </div>
      </section>

      <footer className="coordinates">
        <span>UP // ENTRY</span>
        <span>PROTOCOLO 01</span>
        <span className="coordinate-value">15°35′S · 56°06′W</span>
      </footer>
    </main>
  )
}
