import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_mobile/services/ai_rag_service.dart';

// Exercises the REAL AiRagService offline fallback (no Gemini key => no network).
// Previously this file tested a helper function defined inside the test itself,
// which proved nothing about the app.
void main() {
  group('AiRagService offline clinical engine (real service)', () {
    final service = AiRagService();

    setUp(() => AiRagService.geminiApiKey = '');

    Future<String> ask(String q) =>
        service.queryClinicalRag(userQuery: q, activeMeds: const []);

    test(
      'Panadol + Brufen answer gives timing/limit guidance and a disclaimer',
      () async {
        final res = await ask(
          'Can I take Panadol with Brufen for severe headache?',
        );
        expect(res, contains('alternating'));
        expect(res, contains('Never exceed'));
        expect(res, contains('not medical advice'));
      },
    );

    test('Missed dose answer warns against doubling up', () async {
      final res = await ask(
        'I missed my morning dose, should I take two pills?',
      );
      expect(res, contains('NEVER DOUBLE UP'));
      expect(res, contains('not medical advice'));
    });

    test('Glucophage answer says to take with food', () async {
      final res = await ask('When should I take Glucophage 500mg?');
      expect(res, contains('with or immediately after a substantial meal'));
    });

    test(
      'Unknown question admits it has no specific information (no fabricated guidance)',
      () async {
        final res = await ask(
          'Is dragon fruit extract safe with my heart tablet?',
        );
        expect(res, contains('will not guess'));
        expect(res, isNot(contains('evidence-based')));
        expect(res, contains('not medical advice'));
      },
    );

    test(
      'Packaging answer does not claim a scan proves authenticity or mention blockchain',
      () async {
        final res = await ask('How do I verify packaging of fake medicine?');
        expect(res, contains('can NOT prove'));
        expect(res.toLowerCase(), isNot(contains('blockchain')));
      },
    );
  });
}
