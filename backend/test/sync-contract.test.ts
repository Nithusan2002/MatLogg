import * as assert from 'node:assert/strict';
import {
  decodeBase64Payload, favoritePayloadSchema, logPayloadSchema, MAX_SYNC_EVENTS,
  MAX_SYNC_PAYLOAD_BASE64_CHARS, MAX_SYNC_PAYLOAD_BYTES, savedMealPayloadSchema,
  SYNC_SCHEMA_VERSION, syncEventTypes, weightPayloadSchema,
} from '../src/sync/sync.contract';

const id = '550e8400-e29b-41d4-a716-446655440000';
assert.equal(SYNC_SCHEMA_VERSION, 1);
assert.equal(MAX_SYNC_EVENTS, 50);
assert.equal(MAX_SYNC_PAYLOAD_BYTES, 65_536);
assert.equal(MAX_SYNC_PAYLOAD_BASE64_CHARS, 87_384);
assert.equal(decodeBase64Payload(Buffer.from('{"ok":true}').toString('base64'))?.toString('utf8'), '{"ok":true}');
assert.equal(decodeBase64Payload('not base64'), null);
assert.equal(decodeBase64Payload('e30'), null);
assert(syncEventTypes.has('log.upsert'));
assert(syncEventTypes.has('weight.delete'));
assert(syncEventTypes.has('saved_meal.upsert'));
assert(logPayloadSchema.safeParse({
  id, date: '2026-09-15T10:00:00Z', meal: 'lunsj', grams: 100, kcal: 200,
  protein: 10, carbs: 20, fat: 5, productRef: id,
}).success);
assert(!logPayloadSchema.safeParse({ id, date: 'not-a-date', meal: '', grams: -1 }).success);

assert(savedMealPayloadSchema.safeParse({
  id,
  name: 'Vanlig frokost',
  suggestedMealType: 'frokost',
  updatedAt: '2026-09-24T12:00:00Z',
  items: [{
    id, productId: id, productName: 'Havregryn',
    amountG: 80, calories: 296, protein: 10, carbs: 48, fat: 6,
    nutritionSource: 'matvaretabellen', sortIndex: 0,
  }],
}).success);
assert(!savedMealPayloadSchema.safeParse({
  id, name: '', updatedAt: '2026-09-24T12:00:00Z', items: [],
}).success);
assert(favoritePayloadSchema.safeParse({ productId: id }).success);
assert(weightPayloadSchema.safeParse({ id, date: '2026-09-15T00:00:00Z', weightKg: 75.2 }).success);
assert(!weightPayloadSchema.safeParse({ id, date: '2026-09-15T00:00:00Z', weightKg: -1 }).success);

console.log('Sync contract tests passed');
