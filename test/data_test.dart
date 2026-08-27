import 'package:flutter_test/flutter_test.dart';
import 'package:um_marketplace/auth/um_email_policy.dart';
import 'package:um_marketplace/data/member_store.dart';
import 'package:um_marketplace/home/money_format.dart';

void main() {
  group('Member.fromDoc', () {
    test('reads the account fields', () {
      final member = Member.fromDoc('u1', {
        'uid': 'u1',
        'email': 'r.tabay.123456@umindanao.edu.ph',
        'displayName': 'R. Tabay',
        'isAdmin': false,
        'banned': false,
        'blocked': {'other': true},
      });
      expect(member.uid, 'u1');
      expect(member.displayName, 'R. Tabay');
      expect(member.blocked, {'other'});
      expect(member.isAdmin, isFalse);
      expect(member.banned, isFalse);
    });

    test('defaults missing optional flags', () {
      final member = Member.fromDoc('u1', {
        'email': 'a.b.000001@umindanao.edu.ph',
        'displayName': 'A. B',
      });
      expect(member.isAdmin, isFalse);
      expect(member.banned, isFalse);
      expect(member.blocked, isEmpty);
    });
  });

  group('formatPesos', () {
    test('formats with thousands separators', () {
      expect(formatPesos(0), '₱0');
      expect(formatPesos(250), '₱250');
      expect(formatPesos(1250), '₱1,250');
      expect(formatPesos(1234567), '₱1,234,567');
    });

    test('rounds decimals to whole pesos', () {
      expect(formatPesos(249.9), '₱250');
      expect(formatPesos(249.4), '₱249');
    });
  });

  group('displayNameFromUmEmail', () {
    test('derives initial + surname, never the ID (ADR 0007)', () {
      expect(
        displayNameFromUmEmail('l.murillo.546842@umindanao.edu.ph'),
        'L. Murillo',
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
  });
}