// Pure notification-content builders (ADR 0005). Kept free of Firebase
// imports so node:test can cover them offline.

function formatPesos(amount) {
  const digits = Math.round(Number(amount)).toString();
  let out = '₱';
  for (let i = 0; i < digits.length; i++) {
    out += digits[i];
    const remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 === 0) out += ',';
  }
  return out;
}

function messagePayload({ type, senderName, listingTitle, price }) {
  if (type === 'offer') {
    return {
      type: 'offer',
      title: 'New offer on your listing',
      body: `${formatPesos(price)} for "${listingTitle}"`,
    };
  }
  return {
    type: 'message',
    title: 'New message',
    body: `${senderName} wrote on "${listingTitle}"`,
  };
}

function soldPayload({ listingTitle }) {
  return {
    type: 'sold',
    title: 'Listing sold',
    body: `"${listingTitle}" was marked sold.`,
  };
}

function ratingPayload({ stars, raterName, listingTitle }) {
  return {
    type: 'rating',
    title: 'You got a rating',
    body: `★${stars} from ${raterName} on "${listingTitle}".`,
  };
}

// FCM send failures that mean the token is dead — the device doc is
// pruned then (ADR 0005).
function shouldPruneToken(errorCode) {
  return (
    errorCode === 'messaging/unregistered-device' ||
    errorCode === 'messaging/invalid-argument'
  );
}

module.exports = {
  formatPesos,
  messagePayload,
  soldPayload,
  ratingPayload,
  shouldPruneToken,
};