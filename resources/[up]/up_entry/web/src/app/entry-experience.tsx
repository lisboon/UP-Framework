import { ArrivalScreen } from '../components/arrival/arrival-screen'
import { CharacterScreen } from '../components/character/character-screen'
import { EntryShell } from '../components/layout/entry-shell'
import { useEntry } from '../providers/entry-context'

export function EntryExperience() {
  const { state, retry } = useEntry()

  if (state.view === 'hidden') return null
  if (state.view === 'arrival') return <ArrivalScreen />
  if (state.view !== 'ready') return <EntryShell state={state} onRetry={retry} />

  const constraints = state.constraints
  if (!constraints) return <EntryShell state={{ ...state, view: 'error', error: 'Configuração de personagens indisponível.' }} onRetry={retry} />

  return <CharacterScreen constraints={constraints} />
}
