# 0001: Student-only email gate (format + ownership)

Membership is restricted to University of Mindanao students by requiring both (a) a UM Address in the exact student shape `initial.surname.######@umindanao.edu.ph` and (b) proof of ownership — a verification code sent to that inbox must be entered before the account can do anything. A format-only check would let anyone register under a fabricated student address; the ownership check means only the person who controls that inbox can create a usable account.

The 6-digit student-ID segment of the format excludes staff and alumni from membership by construction (their addresses carry no ID segment). This is deliberate for v1 so no role logic is needed; loosening to a domain-only gate later is a one-line change, whereas tightening later would mean evicting already-onboarded accounts — so we start strict.

**Considered options (rejected):** domain-only gate (admits staff/alumni and requires role handling); format-only gate (no ownership proof, spoofable).

**Consequences:** the 6-digit ID embedded in every UM Address is personally identifying — how much of it is displayed publicly is a separate decision deferred to the profile/privacy session.
