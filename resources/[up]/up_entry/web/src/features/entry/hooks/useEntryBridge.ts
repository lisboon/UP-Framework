import { useEffect, useReducer } from 'react'
import { nuiRequest } from '../../../shared/services/nuiClient'
import { isEntryMessage, UI_PROTOCOL_VERSION } from '../model/entryContract'
import { initialEntryState, reduceEntry } from '../model/entryReducer'

export function useEntryBridge() {
  const [state, dispatch] = useReducer(reduceEntry, initialEntryState)

  useEffect(() => {
    const receive = (event: MessageEvent) => {
      if (isEntryMessage(event.data)) dispatch(event.data)
    }

    window.addEventListener('message', receive)
    void nuiRequest('entry/ready', { version: UI_PROTOCOL_VERSION })

    if (import.meta.env.DEV && typeof window.GetParentResourceName !== 'function') {
      dispatch({ version: UI_PROTOCOL_VERSION, action: 'entry/open' })
    }

    return () => window.removeEventListener('message', receive)
  }, [])

  return state
}
