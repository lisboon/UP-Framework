import type { EntryMessage } from './entryContract'

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

export const initialEntryState: EntryState = {
  view: 'hidden',
  characters: [],
  locations: [],
  dialog: null,
  mutation: null
}

export function reduceEntry(state: EntryState, action: EntryStateAction): EntryState {
  if ('action' in action) {
    if (action.action === 'entry/open') return { ...initialEntryState, view: 'loading' }
    if (action.action === 'entry/close') return initialEntryState
    if (action.action === 'spawn/failed') return { ...state, view: 'arrival', mutation: null, error: 'A chegada expirou antes de ser concluída. Escolha o local novamente.' }
    return { ...state, view: 'error', mutation: null, error: action.payload?.message }
  }

  switch (action.type) {
    case 'characters/loaded':
      return { ...state, view: action.selectedPassport ? 'arrivalLoading' : 'ready', characters: action.characters, constraints: action.constraints, mutation: null, error: undefined }
    case 'characters/created':
      if (state.view !== 'ready') return state
      return { ...state, characters: [...state.characters, action.character], dialog: null, mutation: null, error: undefined }
    case 'characters/deleted':
      if (state.view !== 'ready') return state
      return { ...state, characters: state.characters.filter(({ passport }) => passport !== action.passport), dialog: null, mutation: null, error: undefined }
    case 'characters/selected':
      if (state.view !== 'ready') return state
      return { ...state, view: 'arrivalLoading', dialog: null, mutation: null, error: undefined }
    case 'locations/loaded':
      if (state.view !== 'arrivalLoading') return state
      return { ...state, view: 'arrival', locations: action.locations, mutation: null, error: undefined }
    case 'spawn/started':
      if (state.view !== 'arrival' || state.mutation) return state
      return { ...state, mutation: 'spawning', error: undefined }
    case 'spawn/requested':
      if (state.view !== 'arrival') return state
      return { ...state, view: 'spawning', mutation: null, error: undefined }
    case 'request/started':
      if (state.view !== 'ready' || state.mutation) return state
      return { ...state, mutation: action.mutation, error: undefined }
    case 'request/failed':
      return { ...state, view: state.view === 'loading' || state.view === 'arrivalLoading' ? 'error' : state.view, mutation: null, error: action.error }
    case 'dialog/create':
      return { ...state, dialog: { type: 'create' }, error: undefined }
    case 'dialog/delete':
      return { ...state, dialog: { type: 'delete', character: action.character }, error: undefined }
    case 'dialog/closed':
      return { ...state, dialog: null, error: undefined }
    default:
      return state
  }
}
