import { nuiRequest } from '../../../shared/services/nuiClient'
import { UI_PROTOCOL_VERSION } from '../model/entryContract'
import type { Character, CharacterConstraints, CharacterDraft } from '../model/entryReducer'

interface NuiResponse<T> {
  version: number
  ok: boolean
  result?: T
  error?: string
}

export interface CharacterBootstrap {
  characters: Character[]
  constraints: CharacterConstraints
  selectedPassport?: number
}

const previewConstraints: CharacterConstraints = {
  firstNameMinLength: 2,
  firstNameMaxLength: 32,
  lastNameMinLength: 2,
  lastNameMaxLength: 32,
  maxPerAccount: 3,
  minimumAge: 18,
  maximumAge: 90
}

let previewCharacters: Character[] = [{
  passport: 1000,
  firstName: 'Aurora',
  lastName: 'Lisboa',
  birthDate: '1998-08-31',
  createdAt: '2026-08-31T12:00:00Z',
  updatedAt: '2026-08-31T12:00:00Z'
}]

async function previewRequest<T>(event: string, payload: Record<string, unknown>): Promise<T> {
  if (event === 'characters/load') return { characters: previewCharacters, constraints: previewConstraints } as T
  if (event === 'characters/create') {
    const timestamp = new Date().toISOString()
    const character = { ...payload, passport: 1000 + previewCharacters.length, createdAt: timestamp, updatedAt: timestamp } as unknown as Character
    previewCharacters = [...previewCharacters, character]
    return character as T
  }
  if (event === 'characters/delete') {
    previewCharacters = previewCharacters.filter(({ passport }) => passport !== payload.passport)
    return true as T
  }
  if (event === 'characters/select') return { passport: payload.passport } as T
  throw new Error('request_failed')
}

async function request<T>(event: string, payload: object = {}): Promise<T> {
  if (import.meta.env.DEV && typeof window.GetParentResourceName !== 'function') return previewRequest<T>(event, payload as Record<string, unknown>)
  const response = await nuiRequest<NuiResponse<T>>(event, { version: UI_PROTOCOL_VERSION, payload })
  if (!response?.ok || response.version !== UI_PROTOCOL_VERSION || response.result === undefined) {
    throw new Error(response?.error ?? 'request_failed')
  }
  return response.result
}

export const characterService = {
  load: () => request<CharacterBootstrap>('characters/load'),
  create: (draft: CharacterDraft) => request<Character>('characters/create', draft),
  delete: (passport: number) => request<boolean>('characters/delete', { passport }),
  select: (passport: number) => request<{ passport: number }>('characters/select', { passport })
}
