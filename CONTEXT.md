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

## Example dialogue

> **Dev:** "When someone signs up with a UM Address, do we trust the format?"
> **Domain expert:** "No — format plus ownership. Format proves it's a student address; ownership proves they control that inbox. Only a **Verified Student** can list or chat."

## Flagged ambiguities

- "valid university email" was used to mean three different things — the domain, the address format, and proof the person owns the inbox. Resolved: the format is **UM Address**; the ownership proof is what makes a **Member Account Verified**.
- "gmail" was used loosely — the address is a university email, not a Gmail account; the term is **UM Address**.
- "account" was used to mean both the Student and their login — resolved: **Student** is the person, **Member Account** is the login.
