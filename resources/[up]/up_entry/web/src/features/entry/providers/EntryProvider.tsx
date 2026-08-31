import { createContext, useContext, useEffect, useMemo, useReducer, useRef } from 'react'
import { UI_PROTOCOL_VERSION } from '../model/entryContract'
import { useEntryBridge } from '../hooks/useEntryBridge'
import { initialEntryState, reduceEntry } from '../model/entryReducer'
import type { Character, CharacterDraft, EntryState } from '../model/entryReducer'
import { characterService } from '../services/characterService'

interface EntryContextValue {
  state: EntryState
  openCreate: () => void
  openDelete: (character: Character) => void
  closeDialog: () => void
  createCharacter: (draft: CharacterDraft) => Promise<void>
  deleteCharacter: (passport: number) => Promise<void>
  selectCharacter: (passport: number) => Promise<void>
  retry: () => void
}

const EntryContext = createContext<EntryContextValue | null>(null)

const errorMessages: Record<string, string> = {
  timeout: 'O servidor demorou para responder. Tente novamente.',
  invalid_name: 'Revise o nome e o sobrenome informados.',
  invalid_birth_date: 'A data de nascimento não atende às regras do servidor.',
  character_limit_reached: 'Todos os seus espaços de personagem estão ocupados.',
  character_not_available: 'Este personagem não está mais disponível.',
  character_busy: 'Este personagem já está sendo alterado.',
  player_busy: 'Outra operação ainda está em andamento.',
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
    retry: () => dispatch({ version: UI_PROTOCOL_VERSION, action: 'entry/open' })
  }), [state])

  return <EntryContext value={value}>{children}</EntryContext>
}

export function useEntry() {
  const context = useContext(EntryContext)
  if (!context) throw new Error('useEntry must be used within EntryProvider')
  return context
}
