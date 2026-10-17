import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  group('Redactor.redact', () {
    test('masks registered secrets wherever they appear', () {
      final r = Redactor(secrets: ['my-very-secret-value']);
      expect(r.redact('x my-very-secret-value y'), 'x *** y');
    });

    test('ignores too-short secrets', () {
      final r = Redactor(secrets: ['abc']);
      expect(r.redact('abc abc'), 'abc abc');
    });

    test('masks well-known key formats', () {
      final r = Redactor();
      expect(r.redact('key sk-or-v1-0123456789abcdef0123'), 'key ***');
      expect(r.redact('AIzaSyA-1234567890abcdefghijklmnopqrstu'), '***');
      expect(r.redact('Authorization: Bearer abc.def-ghi_jkl'), contains('Bearer ***'));
      expect(r.redact('https://x.googleapis.com/v2?key=XYZ123&q=1'),
          'https://x.googleapis.com/v2?key=***&q=1');
      expect(r.redact('"api_key": "hunter2hunter2"'), '"api_key": "***"');
      expect(r.redact('token=abcdef123456'), 'token=***');
    });

    test('masks e-mail addresses', () {
      expect(Redactor().redact('mail me at someone@example.com'), 'mail me at <email>');
    });

    test('replaces the home directory in all path styles', () {
      final r = Redactor(homeDir: r'C:\Users\alice');
      expect(r.redact(r'C:\Users\alice\AppData\x.png'), r'%USERPROFILE%\AppData\x.png');
      expect(r.redact('c:/users/alice/a.png'), '%USERPROFILE%/a.png');
      expect(r.redact(r'"C:\\Users\\alice\\a.png"'), r'"%USERPROFILE%\\a.png"');
    });
  });

  group('Redactor.redactJson', () {
    test('masks values under sensitive keys and recurses', () {
      final r = Redactor(secrets: ['inner-secret-123']);
      final out = r.redactJson({
        'apiKey': 'whatever-value',
        'headers': {'Authorization': 'Bearer zzzzzzzzzz'},
        'list': ['ok', 'inner-secret-123'],
        'count': 3,
      });
      expect(out, {
        'apiKey': '***',
        'headers': {'Authorization': '***'},
        'list': ['ok', '***'],
        'count': 3,
      });
    });

    test('does not mask maps that merely sit under a sensitive key', () {
      final out = Redactor().redactJson({
        'token_usage': {'prompt': 10, 'completion': 20},
      });
      expect(out, {
        'token_usage': {'prompt': 10, 'completion': 20},
      });
    });
  });
}
