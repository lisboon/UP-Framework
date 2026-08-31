import { useMemo, useState } from 'react'
import type { CharacterConstraints, CharacterDraft } from '../model/entryReducer'
import { useEntry } from '../providers/entryContext'
import { DialogFrame } from './DialogFrame'

interface CreateCharacterDialogProps {
  constraints: CharacterConstraints
}

function isoDate(yearOffset: number) {
  const date = new Date()
  date.setFullYear(date.getFullYear() - yearOffset)
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

export function CreateCharacterDialog({ constraints }: CreateCharacterDialogProps) {
  const { closeDialog, createCharacter, state } = useEntry()
  const [draft, setDraft] = useState<CharacterDraft>({ firstName: '', lastName: '', birthDate: '' })
  const minimumBirthDate = isoDate(constraints.maximumAge)
  const maximumBirthDate = isoDate(constraints.minimumAge)
  const valid = useMemo(() => {
    const firstLength = draft.firstName.trim().length
    const lastLength = draft.lastName.trim().length
    return firstLength >= constraints.firstNameMinLength
      && firstLength <= constraints.firstNameMaxLength
      && lastLength >= constraints.lastNameMinLength
      && lastLength <= constraints.lastNameMaxLength
      && draft.birthDate >= minimumBirthDate
      && draft.birthDate <= maximumBirthDate
  }, [constraints, draft, maximumBirthDate, minimumBirthDate])

  return (
    <DialogFrame labelledBy="create-title" onClose={closeDialog} locked={state.mutation !== null}>
      <form onSubmit={(event) => { event.preventDefault(); if (valid) void createCharacter(draft) }}>
        <div className="dialog-heading"><p className="eyebrow"><span>+</span> Nova identidade</p><h2 id="create-title">Quem você será?</h2></div>
        {state.error && <p className="inline-error" role="alert">{state.error}</p>}
        <div className="form-grid">
          <label><span>Nome</span><input autoFocus required minLength={constraints.firstNameMinLength} maxLength={constraints.firstNameMaxLength} value={draft.firstName} onChange={(event) => setDraft({ ...draft, firstName: event.target.value })} autoComplete="off" /></label>
          <label><span>Sobrenome</span><input required minLength={constraints.lastNameMinLength} maxLength={constraints.lastNameMaxLength} value={draft.lastName} onChange={(event) => setDraft({ ...draft, lastName: event.target.value })} autoComplete="off" /></label>
          <label className="birth-field"><span>Data de nascimento</span><input required type="date" min={minimumBirthDate} max={maximumBirthDate} value={draft.birthDate} onChange={(event) => setDraft({ ...draft, birthDate: event.target.value })} /></label>
        </div>
        <div className="dialog-actions"><button className="text-action" type="button" onClick={closeDialog} disabled={state.mutation !== null}>Cancelar</button><button className="primary-action" type="submit" disabled={!valid || state.mutation !== null}>{state.mutation === 'creating' ? 'Criando…' : 'Criar identidade'}</button></div>
      </form>
    </DialogFrame>
  )
}
