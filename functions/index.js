const {
  onDocumentCreated,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

const { messagePayload, soldPayload, ratingPayload } = require('./payload');
const { deliver } = require('./deliver');

// A chat message (text or offer) notifies the OTHER participant.
// Offer messages carry the price; the sender name comes from the chat's
// denormalized names (ADR 0007 — no member reads). Blocked senders are
// skipped (CONTEXT: Block).
exports.onMessageCreated = onDocumentCreated(
  'chats/{chatId}/messages/{msgId}',
  async (event) => {
    const message = event.data.data();
    if (!message || !message.senderId) return;
    const chatSnap = await db
      .collection('chats')
      .doc(event.params.chatId)
      .get();
    const chat = chatSnap.data();
    if (!chat) return;

    const recipientUid =
      message.senderId === chat.buyerId ? chat.sellerId : chat.buyerId;
    if (!recipientUid || recipientUid === message.senderId) return;

    const recipientSnap = await db
      .collection('members')
      .doc(recipientUid)
      .get();
    const recipient = recipientSnap.data();
    if (!recipient || recipient.banned === true) return;
    const blocked = recipient.blocked ?? {};
    if (blocked[message.senderId] === true) return;

    const listingSnap = await db
      .collection('listings')
      .doc(chat.listingId)
      .get();
    const listingTitle = listingSnap.data()?.title ?? 'a listing';

    const senderName =
      message.senderId === chat.buyerId ? chat.buyerName : chat.sellerName;

    const payload =
      message.type === 'offer'
        ? messagePayload({
            type: 'offer',
            senderName,
            listingTitle,
            price: message.price,
          })
        : messagePayload({ type: 'message', senderName, listingTitle });

    await deliver({ recipientUid, payload, db, messaging });
  },
);

// A listing flipping to sold (CONTEXT: Sold) notifies every buyer who had
// a chat on it.
exports.onListingSold = onDocumentUpdated(
  'listings/{listingId}',
  async (event) => {
    const before = event.data.before.data() ?? {};
    const after = event.data.after.data() ?? {};
    if (before.status === 'sold' || after.status !== 'sold') return;

    const chats = await db
      .collection('chats')
      .where('listingId', '==', event.params.listingId)
      .get();

    const payload = soldPayload({ listingTitle: after.title ?? 'a listing' });
    await Promise.all(
      chats.docs.map(async (chatDoc) => {
        const chat = chatDoc.data();
        if (!chat?.buyerId) return;
        await deliver({
          recipientUid: chat.buyerId,
          payload,
          db,
          messaging,
        });
      }),
    );
  },
);

// A rating notifies the ratee (ADR 0004/0005).
exports.onRatingCreated = onDocumentCreated(
  'ratings/{ratingId}',
  async (event) => {
    const rating = event.data.data();
    if (!rating || !rating.rateeId || rating.rateeId === rating.raterId) return;

    const raterSnap = await db
      .collection('members')
      .doc(rating.raterId)
      .get();
    const raterName = raterSnap.data()?.displayName ?? 'a member';

    const listingSnap = await db
      .collection('listings')
      .doc(rating.listingId)
      .get();
    const listingTitle = listingSnap.data()?.title ?? 'a listing';

    const payload = ratingPayload({
      stars: rating.stars,
      raterName,
      listingTitle,
    });
    await deliver({ recipientUid: rating.rateeId, payload, db, messaging });
  },
);