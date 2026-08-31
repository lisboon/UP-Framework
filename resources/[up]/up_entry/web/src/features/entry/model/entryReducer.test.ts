import { describe, expect, it } from 'vitest'
import { UI_PROTOCOL_VERSION, isEntryMessage } from './entryContract'
import { initialEntryState, reduceEntry } from './entryReducer'

describe('entry protocol', () => {
  it('rejects unsupported and unknown messages', () => {
    expect(isEntryMessage({ version: 2, action: 'entry/open' })).toBe(false)
    expect(isEntryMessage({ version: UI_PROTOCOL_VERSION, action: 'unknown' })).toBe(false)
  })

  it('moves through open, error and close states', () => {
    const open = reduceEntry(initialEntryState, { version: 1, action: 'entry/open' })
    expect(open.view).toBe('ready')

    const error = reduceEntry(open, { version: 1, action: 'entry/error', payload: { message: 'Falha' } })
    expect(error).toEqual({ view: 'error', message: 'Falha' })

    expect(reduceEntry(error, { version: 1, action: 'entry/close' })).toEqual(initialEntryState)
  })
})
