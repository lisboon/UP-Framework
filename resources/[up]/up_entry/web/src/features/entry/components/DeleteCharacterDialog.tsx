import type { Character } from '../model/entryReducer'
import { useEntry } from '../providers/entryContext'
import { DialogFrame } from './DialogFrame'

interface DeleteCharacterDialogProps { character: Character }

export function DeleteCharacterDialog({ character }: DeleteCharacterDialogProps) {
  const { closeDialog, deleteCharacter, state } = useEntry()
  return (
    <DialogFrame labelledBy="delete-title" onClose={closeDialog} locked={state.mutation !== null} className="delete-dialog">
      <div className="dialog-heading"><p className="eyebrow danger"><span>!</span> Ação permanente</p><h2 id="delete-title">Apagar esta identidade?</h2></div>
      <p className="dialog-copy"><strong>{character.firstName} {character.lastName}</strong>, passaporte {character.passport}, será removido. Esta ação não pode ser desfeita.</p>
      {state.error && <p className="inline-error" role="alert">{state.error}</p>}
      <div className="dialog-actions"><button className="text-action" autoFocus type="button" onClick={closeDialog} disabled={state.mutation !== null}>Manter personagem</button><button className="danger-action" type="button" onClick={() => void deleteCharacter(character.passport)} disabled={state.mutation !== null}>{state.mutation === 'deleting' ? 'Excluindo…' : 'Excluir definitivamente'}</button></div>
    </DialogFrame>
  )
}
