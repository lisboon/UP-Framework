import { fireEvent, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { App } from './App'

afterEach(() => {
  delete window.GetParentResourceName
})

describe('entry shell', () => {
  it('handshakes with Lua and renders only supported messages', async () => {
    window.GetParentResourceName = () => 'up_entry'
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('{"ok":true}'))
    render(<App />)

    expect(screen.queryByRole('main')).not.toBeInTheDocument()
    expect(fetchMock).toHaveBeenCalledWith('https://up_entry/entry/ready', expect.objectContaining({ method: 'POST' }))

    fireEvent(window, new MessageEvent('message', { data: { version: 2, action: 'entry/open' } }))
    expect(screen.queryByRole('main')).not.toBeInTheDocument()

    fireEvent(window, new MessageEvent('message', { data: { version: 1, action: 'entry/open' } }))
    expect(screen.getByRole('main')).toHaveAttribute('data-view', 'ready')

    fireEvent(window, new MessageEvent('message', { data: { version: 1, action: 'entry/close' } }))
    expect(screen.queryByRole('main')).not.toBeInTheDocument()
    fetchMock.mockRestore()
  })
})
