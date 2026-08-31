import { EntryProvider } from '../providers/entry-provider'
import { EntryExperience } from './entry-experience'

export function App() {
  return (
    <EntryProvider>
      <EntryExperience />
    </EntryProvider>
  )
}
