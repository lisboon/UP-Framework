export const UI_PROTOCOL_VERSION = 1 as const

export type EntryAction = 'entry/open' | 'entry/close' | 'entry/error' | 'spawn/failed'

export interface EntryMessage {
  version: number
  action: EntryAction
  payload?: {
    reason?: string
    message?: string
  }
}

export function isEntryMessage(value: unknown): value is EntryMessage {
  if (!value || typeof value !== 'object') return false
  const candidate = value as Partial<EntryMessage>
  return candidate.version === UI_PROTOCOL_VERSION
    && candidate.action !== undefined
    && ['entry/open', 'entry/close', 'entry/error', 'spawn/failed'].includes(candidate.action)
}

export interface Character {
  passport: number
  firstName: string
  lastName: string
  birthDate: string
  createdAt: string
  updatedAt: string
  lastSelectedAt?: string
}

export interface CharacterConstraints {
  firstNameMinLength: number
  firstNameMaxLength: number
  lastNameMinLength: number
  lastNameMaxLength: number
  maxPerAccount: number
  minimumAge: number
  maximumAge: number
}

export interface CharacterDraft {
  firstName: string
  lastName: string
  birthDate: string
}

export interface SpawnLocation {
  id: string
  label: string
}

export type EntryView = 'hidden' | 'loading' | 'ready' | 'arrivalLoading' | 'arrival' | 'spawning' | 'error'
export type EntryDialog = { type: 'create' } | { type: 'delete'; character: Character } | null
export type EntryMutation = 'creating' | 'deleting' | 'selecting' | 'spawning' | null

export interface EntryState {
  view: EntryView
  characters: Character[]
  constraints?: CharacterConstraints
  locations: SpawnLocation[]
  dialog: EntryDialog
  mutation: EntryMutation
  error?: string
}

export type EntryStateAction = EntryMessage
  | { type: 'characters/loaded'; characters: Character[]; constraints: CharacterConstraints; selectedPassport?: number }
  | { type: 'characters/created'; character: Character }
  | { type: 'characters/deleted'; passport: number }
  | { type: 'characters/selected' }
  | { type: 'locations/loaded'; locations: SpawnLocation[] }
  | { type: 'spawn/started' }
  | { type: 'spawn/requested' }
  | { type: 'request/started'; mutation: Exclude<EntryMutation, null> }
  | { type: 'request/failed'; error: string }
  | { type: 'dialog/create' }
  | { type: 'dialog/delete'; character: Character }
  | { type: 'dialog/closed' }
