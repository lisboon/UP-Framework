import type { EntryMessage } from './entryContract'

export type EntryView = 'hidden' | 'ready' | 'error'

export interface EntryState {
  view: EntryView
  message?: string
}

export const initialEntryState: EntryState = { view: 'hidden' }

export function reduceEntry(state: EntryState, message: EntryMessage): EntryState {
  switch (message.action) {
    case 'entry/open':
      return { view: 'ready' }
    case 'entry/close':
      return initialEntryState
    case 'entry/error':
      return { view: 'error', message: message.payload?.message }
    default:
      return state
  }
}
