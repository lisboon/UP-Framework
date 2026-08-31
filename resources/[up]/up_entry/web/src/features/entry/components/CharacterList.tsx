import { useEffect, useState } from 'react'
import type { Character } from '../model/entryReducer'
import { useEntry } from '../providers/entryContext'

interface CharacterListProps {
  characters: Character[]
  disabled: boolean
  hasSlot: boolean
  onCreate: () => void
}

function ageFrom(birthDate: string) {
  const birth = new Date(`${birthDate}T00:00:00`)
  const now = new Date()
  let age = now.getFullYear() - birth.getFullYear()
  if (now.getMonth() < birth.getMonth() || (now.getMonth() === birth.getMonth() && now.getDate() < birth.getDate())) age--
  return age
}

export function CharacterList({ characters, disabled, hasSlot, onCreate }: CharacterListProps) {
  const { openDelete, previewCharacter, selectCharacter, state } = useEntry()
  const [activePassport, setActivePassport] = useState<number | undefined>(characters[0]?.passport)

  useEffect(() => {
    if (!characters.some(({ passport }) => passport === activePassport)) setActivePassport(characters[0]?.passport)
  }, [activePassport, characters])

  useEffect(() => {
    if (activePassport) previewCharacter(activePassport)
  }, [activePassport, previewCharacter])

  const activeCharacter = characters.find(({ passport }) => passport === activePassport)

  return (
    <div className="character-stage">
      <div className="character-identity" aria-live="polite">
        {activeCharacter ? (
          <>
            <p className="identity-kicker">Identidade selecionada</p>
            <h1><span>{activeCharacter.firstName}</span><strong>{activeCharacter.lastName}</strong></h1>
            <div className="identity-rule" aria-hidden="true"><i /><i /><i /></div>
            <p className="identity-meta">Passaporte {activeCharacter.passport} <span>·</span> {ageFrom(activeCharacter.birthDate)} anos</p>
          </>
        ) : (
          <>
            <p className="identity-kicker">Primeira travessia</p>
            <h1 className="empty-title"><span>Crie uma</span><strong>identidade</strong></h1>
            <p className="identity-meta">Seu universo começa com uma história.</p>
          </>
        )}
      </div>

      {state.error && <p className="inline-error" role="alert">{state.error}</p>}

      <div className="character-dock">
        <div className="dock-primary">
          {activeCharacter ? (
            <button className="play-action" type="button" disabled={disabled} onClick={() => void selectCharacter(activeCharacter.passport)}>
              <span className="play-bars" aria-hidden="true"><i /><i /><i /></span>
              <span>{state.mutation === 'selecting' ? 'Sincronizando' : 'Entrar no universo'}</span>
            </button>
          ) : (
            <button className="play-action" type="button" disabled={!hasSlot || disabled} onClick={onCreate}>
              <span className="play-bars" aria-hidden="true"><i /><i /><i /></span>
              <span>Criar identidade</span>
            </button>
          )}
        </div>

        <nav className="identity-nav" aria-label="Suas identidades">
          {characters.map((character, index) => {
            const active = character.passport === activePassport
            return (
              <button className="identity-option" data-active={active} key={character.passport} type="button" disabled={disabled} onClick={() => setActivePassport(character.passport)} aria-pressed={active}>
                <span className="option-label">{character.firstName} {character.lastName}</span>
                <span className="option-index">{String(index + 1).padStart(2, '0')}</span>
              </button>
            )
          })}
          {hasSlot && (
            <button className="identity-option identity-add" type="button" disabled={disabled} onClick={onCreate}>
              <span className="option-label">Nova identidade</span><span className="option-index">+</span>
            </button>
          )}
        </nav>
      </div>

      {activeCharacter && <button className="delete-action" type="button" disabled={disabled} onClick={() => openDelete(activeCharacter)} aria-label={`Excluir ${activeCharacter.firstName} ${activeCharacter.lastName}`}>Excluir personagem</button>}
    </div>
  )
}
