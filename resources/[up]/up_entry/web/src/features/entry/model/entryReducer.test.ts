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
    expect(open.view).toBe('loading')

    const ready = reduceEntry(open, {
      type: 'characters/loaded',
      characters: [],
      constraints: {
        firstNameMinLength: 2,
        firstNameMaxLength: 32,
        lastNameMinLength: 2,
        lastNameMaxLength: 32,
        maxPerAccount: 3,
        minimumAge: 18,
        maximumAge: 90
      }
    })
    expect(ready.view).toBe('ready')

    const error = reduceEntry(open, { type: 'request/failed', error: 'Falha' })
    expect(error.view).toBe('error')
    expect(error.error).toBe('Falha')

    const closed = reduceEntry(error, { version: 1, action: 'entry/close' })
    expect(closed).toEqual(initialEntryState)
    expect(reduceEntry(closed, { type: 'characters/selected' })).toEqual(initialEntryState)
  })
})
