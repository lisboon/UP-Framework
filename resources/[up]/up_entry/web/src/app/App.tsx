import { CharacterExperience } from '../features/entry/components/CharacterExperience'
import { EntryProvider } from '../features/entry/providers/EntryProvider'

export function App() {
  return (
    <EntryProvider>
      <CharacterExperience />
    </EntryProvider>
  )
}
