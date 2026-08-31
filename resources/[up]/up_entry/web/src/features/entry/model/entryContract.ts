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
