# UM Marketplace

Campus marketplace for University of Mindanao students to buy and sell items to each other. Membership is restricted to students by their university email.

## Language

**Membership & identity**

**Student**:
A University of Mindanao student, identified by their 6-digit student ID. The only member class of the marketplace in v1.
_Avoid_: user, account, customer

**UM Address**:
The university email `initial.surname.######@umindanao.edu.ph` (e.g. `r.tabay.123456@umindanao.edu.ph`); both identifies the Student and proves they are a student, because staff and alumni addresses do not carry the 6-digit ID segment.
_Avoid_: university gmail, school email

**Member Account**:
The login identity bound to exactly one UM Address, held by exactly one Student.
_Avoid_: account, profile

**Verified Student**:
A Student whose Member Account has proven ownership of its UM Address (a verification code was delivered to that inbox and entered). Every usable Member Account is Verified by construction — there is no unverified-but-active state.
_Avoid_: verified account, badge, checkmark

## Relationships

- A **Student** is identified by the 6-digit ID inside their **UM Address**
- A **Member Account** is bound to exactly one **UM Address** and belongs to exactly one **Student**
- **Verified** is a property of a **Member Account** that has proven ownership of its **UM Address**
- Every **Member Account** that can list or chat is a **Verified Student**
- A **Verified Student** creates one or more **Listings**
- A **Listing** receives **Offers** from other **Verified Students** and is set to **Sold** by its seller once the in-person deal is done
- A **Chat** is attached to exactly one **Listing** and links its seller with one buyer; a **Listing** can have many **Chats**, one per interested buyer
- The app never handles money — an accepted **Offer** leads to an in-person meetup on campus, settled in cash or GCash person-to-person
- Any **Verified Student** can file a **Report** and can **Block** another **Verified Student**
- The **Admin** reviews **Reports**, hides **Listings**, and can **Ban** a **Member Account**
- A **Rating** is exchanged between the two parties of a **Sold Listing**'s chat, once per party, and only after the Listing is **Sold**

**Trading**

**Listing**:
An offer by a Student to sell a physical item they own (textbook, gadget, org merch, dorm essentials, review materials), shown on the marketplace with photos and a price.
_Avoid_: post, ad, product, item listing

**Offer**:
A message from a buyer to a seller expressing intent to purchase a Listing, usually with a stated price. No money moves in the app; an accepted Offer leads to an in-person meetup.
_Avoid_: buy, bid, reservation, checkout

**Chat**:
A conversation attached to exactly one Listing between its seller and one interested buyer, started only from the Listing's Chat or Make-an-offer actions. There is no person-to-person chat outside Listings — every Listing can have several Chats (one per interested buyer).
_Avoid_: DM, PM, inbox thread

**Sold**:
The terminal state of a Listing, set by its seller once an in-person deal is done; the Listing stops appearing in search results.
_Avoid_: completed, closed, finished

**Category**:
One of a fixed set of item types (textbooks, gadgets, org merch, dorm essentials, review materials) used by the Home tiles and by search filtering.
_Avoid_: type, tag, department

**Rating**:
A one-time score (1–5 stars) given by one party of a completed deal to the other — buyer rates seller, seller rates buyer — recorded against a Sold Listing and shown as an average with a trade count. Ratings cannot be given by anyone who was not in that Listing's chat.
_Avoid_: review, feedback, score

**Notification**:
A push message delivered to a member's phone by FCM (banner in the system notification shade, even when the phone is locked) when an event needs their attention: a new Offer or message on their Listing, a Listing Sold, a Rating received.
_Avoid_: alert, ping, toast

**Trust & moderation**

**Report**:
A record a Verified Student files against a Listing or a chat, naming what was reported, by whom, and why. Only the Admin acts on Reports.
_Avoid_: ticket, complaint, flag

**Block**:
A member-level action that hides another member's Listings from you and stops their chat messages from reaching you. The blocked member is not notified.
_Avoid_: mute, ignore

**Ban**:
The Admin-only action that revokes a Member Account's ability to sign in; the banned member's Listings disappear from the marketplace.
_Avoid_: suspend, deactivate

**Admin**:
The single Member Account (the developer's, `l.murillo.546842@umindanao.edu.ph`) that additionally has access to the Admin area: reviewing Reports, looking up members, hiding Listings, and Banning Member Accounts. The Admin is also an ordinary marketplace user.
_Avoid_: moderator, staff, superuser

## Example dialogue

> **Dev:** "When someone signs up with a UM Address, do we trust the format?"
> **Domain expert:** "No — format plus ownership. Format proves it's a student address; ownership proves they control that inbox. Only a **Verified Student** can list or chat."

## Flagged ambiguities

- "valid university email" was used to mean three different things — the domain, the address format, and proof the person owns the inbox. Resolved: the format is **UM Address**; the ownership proof is what makes a **Member Account Verified**.
- "gmail" was used loosely — the address is a university email, not a Gmail account; the term is **UM Address**.
- "account" was used to mean both the Student and their login — resolved: **Student** is the person, **Member Account** is the login.
- "Buy/Offer buttons" in the visual spec — resolved: a "Buy" action does not exist; the app never handles money. The product-detail action bar offers **Chat** and **Make an offer** only.
