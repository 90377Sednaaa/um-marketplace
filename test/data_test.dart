import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:um_marketplace/auth/um_email_policy.dart';
import 'package:um_marketplace/data/chat_store.dart';
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

  group('chat helpers', () {
    test('chatIdFor joins listing and buyer with an underscore', () {
      expect(chatIdFor('abc123', 'buyer1'), 'abc123_buyer1');
    });

    test('Chat.fromDoc reads the chat fields and participants', () {
      final chat = Chat.fromDoc('abc_b1', {
        'listingId': 'abc',
        'sellerId': 's1',
        'buyerId': 'b1',
        'participants': {'s1': true, 'b1': true},
        'lastMessagePreview': 'Hey!',
        'lastMessageAt': Timestamp.fromDate(DateTime(2026, 8, 28, 12)),
      });
      expect(chat.id, 'abc_b1');
      expect(chat.listingId, 'abc');
      expect(chat.sellerId, 's1');
      expect(chat.buyerId, 'b1');
      expect(chat.participants, {'s1', 'b1'});
      expect(chat.lastMessagePreview, 'Hey!');
      expect(chat.lastMessageAt, DateTime(2026, 8, 28, 12));
    });

    test('Chat.fromDoc defaults a fresh chat with no preview yet', () {
      final chat = Chat.fromDoc('abc_b1', {
        'listingId': 'abc',
        'sellerId': 's1',
        'buyerId': 'b1',
        'participants': {'s1': true, 'b1': true},
      });
      expect(chat.lastMessagePreview, '');
      expect(chat.lastMessageAt, isNull);
    });

    test('ChatMessage.fromDoc reads text and offer messages', () {
      final text = ChatMessage.fromDoc('m1', {
        'senderId': 's1',
        'type': 'text',
        'text': 'Hello',
        'createdAt': Timestamp.fromDate(DateTime(2026, 8, 28, 12)),
      });
      expect(text.type, 'text');
      expect(text.text, 'Hello');
      expect(text.price, isNull);

      final offer = ChatMessage.fromDoc('m2', {
        'senderId': 'b1',
        'type': 'offer',
        'text': 'Would you take this?',
        'price': 250,
        'createdAt': Timestamp.fromDate(DateTime(2026, 8, 28, 13)),
      });
      expect(offer.type, 'offer');
      expect(offer.price, 250.0);
      expect(offer.createdAt, DateTime(2026, 8, 28, 13));
    });

    test('chatPreview truncates long text and formats offers', () {
      final long = ChatMessage.fromDoc('m1', {
        'senderId': 's1',
        'type': 'text',
        'text': List.filled(80, 'x').join(),
      });
      expect(chatPreview(long).length, kChatPreviewLength + 1);
      expect(chatPreview(long).endsWith('…'), isTrue);

      final offer = ChatMessage.fromDoc('m2', {
        'senderId': 'b1',
        'type': 'offer',
        'text': '',
        'price': 250,
      });
      expect(chatPreview(offer), 'Offer: ₱250');
    });

    test('mergeChatStreams dedupes, sorts by activity desc, caps at 50', () {
      Chat chat(String id, DateTime? at) => Chat(
            id: id,
            listingId: 'l-$id',
            sellerId: 's-$id',
            buyerId: 'b-$id',
            participants: {'s-$id', 'b-$id'},
            lastMessagePreview: '',
            lastMessageAt: at,
          );

      final a = [
        chat('1', DateTime(2026, 8, 28, 10)),
        chat('2', DateTime(2026, 8, 28, 9)),
      ];
      final b = [
        chat('3', DateTime(2026, 8, 28, 11)),
        chat('1', DateTime(2026, 8, 28, 10)),
        chat('4', null),
      ];
      final merged = mergeChatStreams(a, b);
      expect(merged.map((c) => c.id).toList(), ['3', '1', '2', '4']);
      expect(merged.length, 4);
    });

    test('chat open/send failures are typed exceptions', () {
      expect(
        ChatOpenException(ChatOpenFailure.listingInactive).reason,
        ChatOpenFailure.listingInactive,
      );
      expect(ChatSendException(), isA<Exception>());
    });
  });
}