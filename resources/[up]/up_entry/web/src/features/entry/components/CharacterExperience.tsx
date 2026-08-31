import { CharacterList } from './CharacterList'
import { CreateCharacterDialog } from './CreateCharacterDialog'
import { DeleteCharacterDialog } from './DeleteCharacterDialog'
import { EntryShell } from './EntryShell'
import { useEntry } from '../providers/EntryProvider'

export function CharacterExperience() {
  const { state, openCreate, retry } = useEntry()

  if (state.view === 'hidden') return null
  if (state.view !== 'ready') return <EntryShell state={state} onRetry={retry} />

  const constraints = state.constraints
  if (!constraints) return <EntryShell state={{ ...state, view: 'error', error: 'Configuração de personagens indisponível.' }} onRetry={retry} />
  const hasSlot = state.characters.length < constraints.maxPerAccount

  return (
    <main className="character-screen" aria-busy={state.mutation !== null}>
      <div className="character-atmosphere" aria-hidden="true" />

      <header className="character-header">
        <div className="brand-lockup character-brand">
          <span className="brand-mark">UP</span>
          <span className="brand-name">Universo Paralelo</span>
        </div>
        <div className="step-indicator"><span>01</span><span className="step-active">Identidade</span><span>02 Chegada</span></div>
      </header>

      <CharacterList characters={state.characters} disabled={state.mutation !== null} hasSlot={hasSlot} onCreate={openCreate} />

      <footer className="coordinates character-footer">
        <span>UP // IDENTITY</span>
        <span>PROTOCOLO 01</span>
        <span className="slot-readout" aria-label={`${state.characters.length} de ${constraints.maxPerAccount} personagens`}>{String(state.characters.length).padStart(2, '0')} / {String(constraints.maxPerAccount).padStart(2, '0')} identidades</span>
      </footer>

      {state.dialog?.type === 'create' && <CreateCharacterDialog constraints={constraints} />}
      {state.dialog?.type === 'delete' && <DeleteCharacterDialog character={state.dialog.character} />}
    </main>
  )
}
