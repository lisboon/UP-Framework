import { nuiRequest } from '../../../shared/services/nuiClient'
import { UI_PROTOCOL_VERSION } from '../model/entryContract'
import type { SpawnLocation } from '../model/entryReducer'

interface NuiResponse<T> {
  version: number
  ok: boolean
  result?: T
  error?: string
}

const previewLocations: SpawnLocation[] = [
  { id: 'airport', label: 'Aeroporto Internacional de Los Santos' },
  { id: 'city', label: 'Centro de Los Santos' },
  { id: 'north', label: 'Deserto de Grand Senora' }
]

async function request<T>(event: string, payload: object = {}): Promise<T> {
  if (import.meta.env.DEV && typeof window.GetParentResourceName !== 'function') {
    if (event === 'spawns/load') return previewLocations as T
    if (event === 'spawns/preview') return true as T
    if (event === 'spawns/select') return { attemptId: 'preview' } as T
  }

  const response = await nuiRequest<NuiResponse<T>>(event, { version: UI_PROTOCOL_VERSION, payload })
  if (!response?.ok || response.version !== UI_PROTOCOL_VERSION || response.result === undefined) throw new Error(response?.error ?? 'request_failed')
  return response.result
}

export const spawnService = {
  load: () => request<SpawnLocation[]>('spawns/load'),
  preview: (locationId: string) => request<boolean>('spawns/preview', { locationId }),
  select: (locationId: string) => request<{ attemptId: string }>('spawns/select', { locationId })
}
