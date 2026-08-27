/// UM Address policies (ADR 0001, ADR 0007).
///
/// Membership is restricted to University of Mindanao students whose
/// address matches the exact student shape
/// `initial.surname.######@umindanao.edu.ph` — the 6-digit ID segment
/// excludes staff and alumni by construction (their addresses carry no
/// ID segment).
library;

final RegExp _umStudentEmail = RegExp(
  r'^([a-z])\.([a-z]+)\.(\d{6})@umindanao\.edu\.ph$',
  caseSensitive: false,
);

/// The only domain whose addresses are eligible for membership.
const String umDomain = 'umindanao.edu.ph';

/// A real student address — shown in UI copy when explaining the gate.
const String umStudentEmailExample = 'l.murillo.546842@umindanao.edu.ph';

/// Whether [email] is a valid UM student address (format only; ownership
/// is proven separately — by Google Sign-In per ADR 0008).
bool isValidUmStudentEmail(String email) =>
    _umStudentEmail.hasMatch(email.trim().toLowerCase());

/// Display name derived from the address — initial + surname only.
///
/// The 6-digit student ID is PII (ADR 0001) and must never surface
/// anywhere; profiles show `L. Murillo`, never the digits.
String displayNameFromUmEmail(String email) {
  final normalized = email.trim().toLowerCase();
  final match = _umStudentEmail.firstMatch(normalized);
  if (match == null) return normalized;
  final initial = match.group(1)!.toUpperCase();
  final surname = match.group(2)!;
  return '$initial. ${surname[0].toUpperCase()}${surname.substring(1)}';
}