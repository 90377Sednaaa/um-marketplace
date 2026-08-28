const { test } = require('node:test');
const assert = require('node:assert/strict');

const {
  formatPesos,
  messagePayload,
  soldPayload,
  ratingPayload,
  shouldPruneToken,
} = require('../payload');

test('formatPesos mirrors the app formatter', () => {
  assert.equal(formatPesos(0), '₱0');
  assert.equal(formatPesos(250), '₱250');
  assert.equal(formatPesos(1250), '₱1,250');
  assert.equal(formatPesos(1234567), '₱1,234,567');
  assert.equal(formatPesos('249.9'), '₱250');
});

test('messagePayload builds offer and text payloads', () => {
  const offer = messagePayload({
    type: 'offer',
    senderName: 'B. One',
    listingTitle: 'Dorm lamp',
    price: 250,
  });
  assert.equal(offer.type, 'offer');
  assert.equal(offer.title, 'New offer on your listing');
  assert.equal(offer.body, '₱250 for "Dorm lamp"');

  const text = messagePayload({
    type: 'message',
    senderName: 'J. Dela Cruz',
    listingTitle: 'Dorm lamp',
  });
  assert.equal(text.type, 'message');
  assert.equal(text.title, 'New message');
  assert.equal(text.body, 'J. Dela Cruz wrote on "Dorm lamp"');
});

test('soldPayload and ratingPayload', () => {
  assert.deepEqual(soldPayload({ listingTitle: 'Dorm lamp' }), {
    type: 'sold',
    title: 'Listing sold',
    body: '"Dorm lamp" was marked sold.',
  });
  assert.deepEqual(
    ratingPayload({ stars: 4, raterName: 'B. One', listingTitle: 'Dorm lamp' }),
    {
      type: 'rating',
      title: 'You got a rating',
      body: '★4 from B. One on "Dorm lamp".',
    },
  );
});

test('shouldPruneToken only prunes dead-registration errors', () => {
  assert.equal(shouldPruneToken('messaging/unregistered-device'), true);
  assert.equal(shouldPruneToken('messaging/invalid-argument'), true);
  assert.equal(shouldPruneToken('messaging/third-party-auth-error'), false);
  assert.equal(shouldPruneToken(undefined), false);
});