import type { EntryState, EntryStateAction } from '../types/entry'

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
