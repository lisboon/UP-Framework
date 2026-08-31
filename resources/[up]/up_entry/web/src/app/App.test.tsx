import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import type { Character } from '../features/entry/model/entryReducer'
import { App } from './App'

const constraints = {
  firstNameMinLength: 2,
  firstNameMaxLength: 32,
  lastNameMinLength: 2,
  lastNameMaxLength: 32,
  maxPerAccount: 3,
  minimumAge: 18,
  maximumAge: 90
}

function response(result: unknown) {
  return new Response(JSON.stringify({ version: 1, ok: true, result }))
}

function installNui(initialCharacters: Character[] = []) {
  let characters = initialCharacters
  return vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
    const url = String(input)
    const envelope = init?.body ? JSON.parse(String(init.body)) : {}
    if (url.endsWith('/entry/ready')) return new Response('{"ok":true}')
    if (url.endsWith('/characters/load')) return response({ characters, constraints })
    if (url.endsWith('/characters/create')) {
      const character = { ...envelope.payload, passport: 1001, createdAt: 'now', updatedAt: 'now' }
      characters = [...characters, character]
      return response(character)
    }
    if (url.endsWith('/characters/delete')) {
      characters = characters.filter(({ passport }) => passport !== envelope.payload.passport)
      return response(true)
    }
    if (url.endsWith('/characters/select')) return response({ passport: envelope.payload.passport })
    return new Response('', { status: 404 })
  })
}

function openEntry() {
  fireEvent(window, new MessageEvent('message', { data: { version: 1, action: 'entry/open' } }))
}

afterEach(() => {
  cleanup()
  delete window.GetParentResourceName
  vi.restoreAllMocks()
})

describe('character experience', () => {
  it('handshakes with Lua and accepts only the supported protocol', async () => {
    window.GetParentResourceName = () => 'up_entry'
    const fetchMock = installNui()
    render(<App />)

    expect(screen.queryByRole('main')).not.toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledWith('https://up_entry/entry/ready', expect.objectContaining({ method: 'POST' }))

    fireEvent(window, new MessageEvent('message', { data: { version: 2, action: 'entry/open' } }))
    expect(screen.queryByRole('main')).not.toBeInTheDocument()

    openEntry()
    await waitFor(() => expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(/Crie uma\s*identidade/))

    fireEvent(window, new MessageEvent('message', { data: { version: 1, action: 'entry/close' } }))
    expect(screen.queryByRole('main')).not.toBeInTheDocument()
  })

  it('creates and deletes a character through versioned NUI requests', async () => {
    window.GetParentResourceName = () => 'up_entry'
    installNui()
    render(<App />)
    openEntry()

    await screen.findByRole('button', { name: 'Criar identidade' })
    fireEvent.click(screen.getByRole('button', { name: 'Criar identidade' }))
    fireEvent.change(screen.getByLabelText('Nome'), { target: { value: 'Ana' } })
    fireEvent.change(screen.getByLabelText('Sobrenome'), { target: { value: 'Silva' } })
    fireEvent.change(screen.getByLabelText('Data de nascimento'), { target: { value: '2000-02-29' } })
    fireEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Criar identidade' }))

    await screen.findByText('Ana')
    fireEvent.click(screen.getByRole('button', { name: 'Excluir Ana Silva' }))
    expect(screen.getByRole('dialog')).toHaveTextContent('Esta ação não pode ser desfeita.')
    fireEvent.click(screen.getByRole('button', { name: 'Excluir definitivamente' }))
    await screen.findByRole('button', { name: 'Criar identidade' })
  })

  it('selects a character and advances to the next presentation state', async () => {
    window.GetParentResourceName = () => 'up_entry'
    installNui([{ passport: 1000, firstName: 'Ana', lastName: 'Silva', birthDate: '2000-02-29', createdAt: 'then', updatedAt: 'then' }])
    render(<App />)
    openEntry()

    await screen.findByText('Ana')
    fireEvent.click(screen.getByRole('button', { name: /Entrar/ }))
    await waitFor(() => expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(/Seu universo\s*aguarda\./))
  })
})
