# 0009: Deterministic chat ids

**Status:** Accepted

## Context

A Chat is born only from a Listing and pairs its seller with exactly one buyer (`chats/{id}`, ADR 0007); the create rule requires `buyerId == request.auth.uid`, so chat creation is buyer-initiated and the buyer plus the Listing fix the chat's identity. The app needs find-or-create semantics from the Listing's detail screen — re-tapping Chat must reopen the same thread, never duplicate it.

## Decision

The chat document id is deterministic: `{listingId}_{buyerId}`. Opening a chat is a direct `get` of `chats/{listingId}_{buyerId}` followed by a create only when the document does not exist, so find-or-create is idempotent with no race and no listingId+buyerId lookup query (and no index for it).

The conversation list ("my chats") deliberately avoids `participants.<uid>` map-key equality: Firestore cannot index map keys generically — the required composite index hard-codes the concrete key, which would mean one index per user. Instead the list runs two plain-field equality queries (`buyerId == uid`, `sellerId == uid`, each ordered by `lastMessageAt`) and merges them client-side; a chat belongs to exactly one side because the create rule forbids `buyerId == sellerId`.

## Consequences

- Duplicate chats are structurally impossible; the id is safe to embed in URLs/deep links later.
- The seller's uid is visible in chat document ids (buyer ids already are, by rule) — no PII is exposed beyond what the rules already publish.
- Reversing this is expensive: migrating chat ids means rewriting document ids and their message subcollection paths, so any future change must keep a migration story.
- The deterministic-id property is what makes the two-query list correct (a chat appears under exactly one of buyerId/sellerId).