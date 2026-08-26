# 0005: Push notifications via FCM + Cloud Functions

Members must be notified by a system banner even when the app is closed or the phone is asleep — a new Offer or message on their Listing, a Sold state, a Rating received. Client-only notification is impossible (sending a push requires a server key that must never ship inside the app), so push delivery becomes the first server-side component in the project.

Decision: Firebase Cloud Messaging (free, no usage limits) plus a Cloud Function per notification event. Each install holds an FCM token stored on the Member Account's device record; Firestore writes (messages, offers, ratings) trigger Functions that deliver the push. Token refresh and pruning of dead tokens happen at sign-in and on failed sends.

This is a **scoped exception to ADR 0003's "no Cloud Functions" stance**: Functions exist for push delivery only — auth stays role-doc + rules, moderation stays manual by the Admin. Considered and rejected: in-app-only badges (Option A) — product chose the locked-phone banner; unread badges remain as a complementary in-app affordance where cheap.

**Consequences:** this feature introduces the project's first billing-sensitive dependency. The no-cost plan restricts Functions networking (egress to Google services only — FCM qualifies) and some sources report a reduced invocation quota on the free tier; the photo-storage decision (see ADR 0006, if written) may move the project to the pay-as-you-go plan anyway, which removes the restriction at pilot scale with a ~₱0 bill.