UP = {}

dofile('resources/[up]/up_core/shared/config.lua')
dofile('resources/[up]/up_core/server/validation.lua')

assert(UP.Validation.characterName('  Ana   Maria  ', 2, 32) == 'Ana Maria')
assert(UP.Validation.characterName('João', 2, 32) == 'João')
assert(UP.Validation.characterName("D'Ávila", 2, 32) == "D'Ávila")
assert(UP.Validation.characterName('A1', 2, 32) == nil)
assert(UP.Validation.characterName('Ana😀', 2, 32) == nil)
assert(UP.Validation.birthDate('2000-02-29', 18, 90))
assert(not UP.Validation.birthDate('2001-02-29', 18, 90))
assert(not UP.Validation.birthDate('2020-01-01', 18, 90))
assert(UP.Validation.passport(1000))
assert(not UP.Validation.passport(-1))
