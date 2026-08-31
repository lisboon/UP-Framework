import { useEffect, useMemo, useReducer, useRef } from 'react'
import { UI_PROTOCOL_VERSION } from '../model/entryContract'
import { useEntryBridge } from '../hooks/useEntryBridge'
import { initialEntryState, reduceEntry } from '../model/entryReducer'
import { characterService } from '../services/characterService'
import { spawnService } from '../services/spawnService'
import { EntryContext } from './entryContext'
import type { EntryContextValue } from './entryContext'

const errorMessages: Record<string, string> = {
  timeout: 'O servidor demorou para responder. Tente novamente.',
  invalid_name: 'Revise o nome e o sobrenome informados.',
  invalid_birth_date: 'A data de nascimento não atende às regras do servidor.',
  character_limit_reached: 'Todos os seus espaços de personagem estão ocupados.',
  character_not_available: 'Este personagem não está mais disponível.',
  character_busy: 'Este personagem já está sendo alterado.',
  player_busy: 'Outra operação ainda está em andamento.',
  spawn_not_available: 'A chegada ainda não está disponível para este personagem.',
  spawn_location_invalid: 'Este local de chegada não está mais disponível.',
  entry_not_open: 'A sessão de entrada não está disponível.',
  core_unavailable: 'O núcleo do servidor está reiniciando. Tente novamente.'
}

function messageFor(error: unknown) {
  const code = error instanceof Error ? error.message : 'request_failed'
  return errorMessages[code] ?? 'Não foi possível concluir a operação.'
}

export function EntryProvider({ children }: React.PropsWithChildren) {
  const [state, dispatch] = useReducer(reduceEntry, initialEntryState)
  const mutationLocked = useRef(false)
  useEntryBridge(dispatch)

  useEffect(() => {
    if (state.view !== 'loading') return
    let current = true
    void characterService.load()
      .then(({ characters, constraints, selectedPassport }) => {
        if (current) dispatch({ type: 'characters/loaded', characters, constraints, selectedPassport })
      })
      .catch((error) => {
        if (current) dispatch({ type: 'request/failed', error: messageFor(error) })
      })
    return () => { current = false }
  }, [state.view])

  useEffect(() => {
    if (state.view !== 'arrivalLoading') return
    let current = true
    void spawnService.load()
      .then((locations) => {
        if (current) dispatch({ type: 'locations/loaded', locations })
      })
      .catch((error) => {
        if (current) dispatch({ type: 'request/failed', error: messageFor(error) })
      })
    return () => { current = false }
  }, [state.view])

  const value = useMemo<EntryContextValue>(() => ({
    state,
    openCreate: () => dispatch({ type: 'dialog/create' }),
    openDelete: (character) => dispatch({ type: 'dialog/delete', character }),
    closeDialog: () => dispatch({ type: 'dialog/closed' }),
    createCharacter: async (draft) => {
      if (mutationLocked.current) return
      mutationLocked.current = true
      dispatch({ type: 'request/started', mutation: 'creating' })
      try {
        const character = await characterService.create(draft)
        dispatch({ type: 'characters/created', character })
      } catch (error) {
        dispatch({ type: 'request/failed', error: messageFor(error) })
      } finally {
        mutationLocked.current = false
      }
    },
    deleteCharacter: async (passport) => {
      if (mutationLocked.current) return
      mutationLocked.current = true
      dispatch({ type: 'request/started', mutation: 'deleting' })
      try {
        await characterService.delete(passport)
        dispatch({ type: 'characters/deleted', passport })
      } catch (error) {
        dispatch({ type: 'request/failed', error: messageFor(error) })
      } finally {
        mutationLocked.current = false
      }
    },
    selectCharacter: async (passport) => {
      if (mutationLocked.current) return
      mutationLocked.current = true
      dispatch({ type: 'request/started', mutation: 'selecting' })
      try {
        await characterService.select(passport)
        dispatch({ type: 'characters/selected' })
      } catch (error) {
        dispatch({ type: 'request/failed', error: messageFor(error) })
      } finally {
        mutationLocked.current = false
      }
    },
    previewCharacter: (passport) => { void characterService.preview(passport).catch(() => undefined) },
    previewLocation: (locationId) => { void spawnService.preview(locationId).catch(() => undefined) },
    selectLocation: async (locationId) => {
      if (mutationLocked.current) return
      mutationLocked.current = true
      dispatch({ type: 'spawn/started' })
      try {
        await spawnService.select(locationId)
        dispatch({ type: 'spawn/requested' })
      } catch (error) {
        dispatch({ type: 'request/failed', error: messageFor(error) })
      } finally {
        mutationLocked.current = false
      }
    },
    retry: () => dispatch({ version: UI_PROTOCOL_VERSION, action: 'entry/open' })
  }), [state])

  return <EntryContext value={value}>{children}</EntryContext>
}
