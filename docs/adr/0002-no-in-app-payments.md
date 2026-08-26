# 0002: No in-app payments — deals settle in person

The app never handles money in v1. It is a listing + chat + Sold-state platform: buyers and sellers find each other, talk, and complete the deal in person on campus, settled in cash or GCash person-to-person. The "Buy" action from the visual spec does not exist.

A marketplace reader would otherwise assume payments are missing by oversight; they are missing deliberately. Every user is on the same campus, so meetups are trivial; in-app payments would require enabling billing, a payment processor, and Philippine merchant registration — all out of scope for a school project with real but pilot-scale usage. This shapes the UI (no Buy button, no checkout, no payment fields) and the data model (no orders, no transactions — a Listing simply flips to Sold).

**Considered options (rejected for v1):** in-app payments via a PH processor (GCash/PayMongo/Stripe — needs billing + registration); shipping (everyone is on campus).

**Consequences:** the chat quality is a core trust surface since all deal negotiation happens there; if payments are ever added, the Offer → acceptance → payment flow will be a new subsystem, not an extension of the current one.