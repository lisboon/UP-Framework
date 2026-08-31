export interface NuiResponse<T> {
  version: number
  ok: boolean
  result?: T
  error?: string
}

export async function nuiRequest<T>(event: string, payload: object): Promise<T | undefined> {
  if (typeof window.GetParentResourceName !== 'function') return undefined
  try {
    const response = await fetch(`https://${window.GetParentResourceName()}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload)
    })
    if (!response.ok) return undefined
    return response.json() as Promise<T>
  } catch {
    return undefined
  }
}

declare global {
  interface Window {
    GetParentResourceName?: () => string
  }
}
