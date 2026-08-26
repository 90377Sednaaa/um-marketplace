# 0006: Listing photos live inside the Listing document (Spark, no billing)

Listing photos are stored as compressed byte blobs **inside the Listing document** on the no-cost Spark plan. No Firebase Storage, no billing account, no payment method.

Firebase Storage has required a linked billing account (Blaze plan) since February 2026, even at zero usage. The project was created after that change, so there is no legacy exemption — for a school project with pilot-scale usage, we deliberately refuse the billing commitment: compressed 800px photos (100–200 KB each, 2–3 per Listing) fit comfortably in Firestore's 1 MiB document limit, and pilot traffic (hundreds of reads/day) sits far below Spark's 50K-reads/day quota.

**Considered options (rejected for v1):** Firebase Storage on Blaze (billing commitment, though bill stays ~₱0 at pilot scale — revisit when outgrowing Spark); third-party image hosting (new account and dependency for no real gain).

**Consequences:** every Listing card in the feed carries its image bytes (~100–200 KB per card), so feed weight is heavier and the app renders photos through a single centralized widget. Lazy-loading and storage migration (blobs → Storage URLs) is a contained one-time script when the app outgrows Spark — nothing about the Listing's shape forces re-architecture, because photos occupy exactly one field. MUST NOT: scatter photo bytes into subcollections or extra documents — that is what would make the migration painful.