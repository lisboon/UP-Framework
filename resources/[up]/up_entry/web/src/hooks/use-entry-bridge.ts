import { useEffect } from 'react'
import { nuiRequest } from '../services/nui-client'
import { isEntryMessage, UI_PROTOCOL_VERSION } from '../types/entry'
import type { EntryStateAction } from '../types/entry'

export function useEntryBridge(dispatch: React.Dispatch<EntryStateAction>) {
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
  }, [dispatch])
}
