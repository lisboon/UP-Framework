import { createContext, useContext } from 'react'
import type { Character, CharacterDraft, EntryState } from '../model/entryReducer'

export interface EntryContextValue {
  state: EntryState
  openCreate: () => void
  openDelete: (character: Character) => void
  closeDialog: () => void
  createCharacter: (draft: CharacterDraft) => Promise<void>
  deleteCharacter: (passport: number) => Promise<void>
  selectCharacter: (passport: number) => Promise<void>
  previewCharacter: (passport: number) => void
  previewLocation: (locationId: string) => void
  selectLocation: (locationId: string) => Promise<void>
  retry: () => void
}

export const EntryContext = createContext<EntryContextValue | null>(null)

export function useEntry() {
  const context = useContext(EntryContext)
  if (!context) throw new Error('useEntry must be used within EntryProvider')
  return context
}
