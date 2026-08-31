import { useEffect, useState } from 'react'
import { useEntry } from '../../providers/entry-context'

export function ArrivalScreen() {
  const { previewLocation, selectLocation, state } = useEntry()
  const [activeId, setActiveId] = useState<string | undefined>(state.locations[0]?.id)
  const activeLocation = state.locations.find(({ id }) => id === activeId)

  useEffect(() => {
    if (activeId) previewLocation(activeId)
  }, [activeId, previewLocation])

  return (
    <main className="arrival-screen" aria-busy={state.mutation === 'spawning'}>
      <div className="arrival-vignette" aria-hidden="true" />
      <header className="character-header">
        <div className="brand-lockup character-brand"><span className="brand-mark">UP</span><span className="brand-name">Universo Paralelo</span></div>
        <div className="step-indicator"><span>02</span><span>01 Identidade</span><span className="step-active">Chegada</span></div>
      </header>

      <section className="arrival-copy">
        <p className="identity-kicker">Escolha seu ponto de chegada</p>
        <h1>Onde sua<br /><strong>história começa?</strong></h1>
        <p>A câmera acompanha cada destino. A posição final é autorizada pelo servidor.</p>
      </section>

      {state.error && <p className="inline-error" role="alert">{state.error}</p>}

      <div className="arrival-controls">
        <nav className="location-list" aria-label="Locais de chegada">
          {state.locations.map((location, index) => (
            <button key={location.id} type="button" data-active={location.id === activeId} aria-pressed={location.id === activeId} onClick={() => setActiveId(location.id)} disabled={state.mutation !== null}>
              <span>{String(index + 1).padStart(2, '0')}</span><strong>{location.label}</strong>
            </button>
          ))}
        </nav>
        <button className="arrival-action" type="button" disabled={!activeLocation || state.mutation !== null} onClick={() => activeLocation && void selectLocation(activeLocation.id)}>
          <span>{state.mutation === 'spawning' ? 'Autorizando chegada' : 'Chegar neste local'}</span><i aria-hidden="true">→</i>
        </button>
      </div>

      <footer className="coordinates character-footer"><span>UP // ARRIVAL</span><span>PROTOCOLO 02</span><span className="slot-readout">{activeLocation?.label ?? 'Sem destinos disponíveis'}</span></footer>
    </main>
  )
}
