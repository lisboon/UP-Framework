import { EntryShell } from '../features/entry/components/EntryShell'
import { useEntryBridge } from '../features/entry/hooks/useEntryBridge'

export function App() {
  const state = useEntryBridge()
  if (state.view === 'hidden') return null
  return <EntryShell state={state} />
}
