# 0004: Ratings exist only between parties of a completed deal

A Rating (1–5 stars) can only be exchanged by the two members who were in a Sold Listing's chat — buyer rates seller, seller rates buyer, once each, after the Listing flips to Sold. Ratings display as an average plus a trade count on the seller strip.

Most marketplaces let anyone rate anyone; we deliberately do not. With no payments and no shipping, the only deal evidence the app has is the chat thread plus the seller's own Sold flag, so open ratings would manufacture a review-bombing surface for zero trust value. Locking ratings to the actual parties keeps them earned — you can only score people you demonstrably traded with — at the admitted cost that a seller who never marks a Listing Sold never accrues ratings (their unsold scam listings instead accumulate Reports, which the Admin acts on per ADR 0003).

**Considered options (rejected):** open ratings by any member (gameable, review-bombing); ratings from any chat participant (chat alone is not proof of a deal); seller-only ratings with no buyer side (unbalanced trust picture).

**Consequences:** a ratings screen/state machine needs to know "who was in this Listing's chat" and "is this Listing Sold" — both already exist in the data model, so the Rating feature is a thin addition when time permits.