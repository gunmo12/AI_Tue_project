import 'package:flutter_test/flutter_test.dart';
import 'package:spending_assistant/cloud_report.dart';

void main() {
  test('accepts both forms of Cloud Run HTTPS address', () {
    expect(
      () => CloudReport('https://moneymate-123.asia-northeast3.run.app'),
      returnsNormally,
    );
    expect(
      () => CloudReport('https://moneymate-abc.a.run.app/'),
      returnsNormally,
    );
  });

  test('refuses unsafe destinations', () {
    for (final url in [
      'http://moneymate.run.app',
      'https://moneymate.run.app.example.com',
      'https://moneymate.run.app:8443',
      'https://moneymate.run.app/other',
    ]) {
      expect(() => CloudReport(url), throwsFormatException);
    }
  });
}
