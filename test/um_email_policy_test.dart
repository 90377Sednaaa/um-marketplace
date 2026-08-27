import 'package:flutter_test/flutter_test.dart';
import 'package:um_marketplace/auth/um_email_policy.dart';

void main() {
  group('isValidUmStudentEmail', () {
    test('accepts the exact student shape', () {
      expect(
        isValidUmStudentEmail('l.murillo.546842@umindanao.edu.ph'),
        isTrue,
      );
    });

    test('is case-insensitive and trims whitespace', () {
      expect(
        isValidUmStudentEmail('  L.MURILLO.546842@UMINDANAO.EDU.PH  '),
        isTrue,
      );
    });

    test('rejects staff/alumni addresses without an ID segment', () {
      expect(isValidUmStudentEmail('j.doe@umindanao.edu.ph'), isFalse);
      expect(isValidUmStudentEmail('l.murillo@umindanao.edu.ph'), isFalse);
    });

    test('rejects wrong ID segment lengths', () {
      // 5 digits and 7 digits — the segment is exactly 6 (ADR 0001).
      expect(isValidUmStudentEmail('l.murillo.54684@umindanao.edu.ph'), isFalse);
      expect(
        isValidUmStudentEmail('l.murillo.5468421@umindanao.edu.ph'),
        isFalse,
      );
    });

    test('rejects non-UM domains', () {
      expect(isValidUmStudentEmail('l.murillo.546842@gmail.com'), isFalse);
      expect(isValidUmStudentEmail('l.murillo.546842@umindanao.edu'), isFalse);
    });

    test('rejects malformed addresses', () {
      expect(isValidUmStudentEmail(''), isFalse);
      expect(isValidUmStudentEmail('l.murillo.abc546@umindanao.edu.ph'), isFalse);
      expect(
        isValidUmStudentEmail('lean.murillo.546842@umindanao.edu.ph'),
        isFalse, // "lean" is not a single initial.
      );
    });
  });

  group('displayNameFromUmEmail', () {
    test('derives initial + surname, never the ID (ADR 0007)', () {
      expect(
        displayNameFromUmEmail('l.murillo.546842@umindanao.edu.ph'),
        'L. Murillo',
      );
      expect(
        displayNameFromUmEmail('r.delacruz.123456@umindanao.edu.ph'),
        'R. Delacruz',
      );
      // The derived name never exposes the PII ID segment (ADR 0007),
      // even though the source address contains it.
      expect(
        displayNameFromUmEmail('l.murillo.546842@umindanao.edu.ph'),
        isNot(contains('546842')),
      );
    });

    test('falls back to the normalized address when the shape is foreign', () {
      expect(displayNameFromUmEmail('Lean@gmail.com '), 'lean@gmail.com');
    });
  });
}