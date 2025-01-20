import 'package:son/son.dart';
import 'package:test/test.dart';

void main() {
  group('$Son', () {
    group('encoder', () {
      test('has withDictionary set to false', () {
        final son = Son(withDictionary: false);
        expect(
          son.encoder,
          isA<SonEncoder>()
              .having((e) => e.withDictionary, 'withDictionary', isFalse),
        );
      });

      test('has withDictionary set to true', () {
        final son = Son(withDictionary: true);
        expect(
          son.encoder,
          isA<SonEncoder>()
              .having((e) => e.withDictionary, 'withDictionary', isTrue),
        );
      });
    });

    group('decoder', () {
      test('has withDictionary set to false', () {
        final son = Son(withDictionary: false);
        expect(
          son.decoder,
          isA<SonDecoder>()
              .having((e) => e.withDictionary, 'withDictionary', isFalse),
        );
      });

      test('has withDictionary set to true', () {
        final son = Son(withDictionary: true);
        expect(
          son.decoder,
          isA<SonDecoder>()
              .having((e) => e.withDictionary, 'withDictionary', isTrue),
        );
      });
    });
  });
}
