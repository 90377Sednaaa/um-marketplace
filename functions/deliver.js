// Shared delivery (ADR 0005): notification doc (feeds the in-app center)
// + FCM push to every device token + dead-token pruning. `db` and the
// messaging instance are injected by callers for testability.
const { FieldValue } = require('firebase-admin/firestore');
const { shouldPruneToken } = require('./payload');

/**
 * Writes the member's notification doc and pushes it to all their device
 * tokens, pruning dead ones. Returns the number of pushes attempted.
 */
async function deliver({ recipientUid, payload, db, messaging }) {
  const memberRef = db.collection('members').doc(recipientUid);
  const memberSnap = await memberRef.get();
  const member = memberSnap.data();
  if (!member || member.banned === true) return 0;

  await db.collection('notifications').add({
    ownerId: recipientUid,
    type: payload.type,
    title: payload.title,
    body: payload.body,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  const devices = await db
    .collection('members')
    .doc(recipientUid)
    .collection('devices')
    .get();

  let attempted = 0;
  await Promise.all(
    devices.docs.map(async (doc) => {
      const token = doc.data().token;
      if (!token) return;
      attempted += 1;
      try {
        await messaging.send({
          token,
          notification: { title: payload.title, body: payload.body },
          android: {
            priority: 'high',
            notification: { channelId: 'deals' },
          },
        });
      } catch (err) {
        if (shouldPruneToken(err.code)) {
          await doc.ref.delete();
        }
      }
    }),
  );
  return attempted;
}

module.exports = { deliver };