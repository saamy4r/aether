import 'package:flutter_test/flutter_test.dart';
import 'package:aether/core/utils/shell_escape.dart';

void main() {
  group('shQuote', () {
    test('plain word', () {
      expect(shQuote('file.txt'), "'file.txt'");
    });

    test('spaces', () {
      expect(shQuote('my file.txt'), "'my file.txt'");
    });

    test('double quotes and dollar', () {
      expect(shQuote(r'a"b $HOME `id`'), "'a\"b \$HOME `id`'");
    });

    test('single quotes are escaped', () {
      expect(shQuote("it's"), "'it'\\''s'");
    });

    test('injection attempt stays literal', () {
      const evil = 'x"; rm -rf ~; "';
      final quoted = shQuote(evil);
      expect(quoted.startsWith("'"), isTrue);
      expect(quoted.endsWith("'"), isTrue);
      // The dangerous chars are inside single quotes, never bare
      expect(quoted, "'x\"; rm -rf ~; \"'");
    });

    test('newline', () {
      expect(shQuote('a\nb'), "'a\nb'");
    });

    test('empty string yields empty quoted word', () {
      expect(shQuote(''), "''");
    });
  });
}
