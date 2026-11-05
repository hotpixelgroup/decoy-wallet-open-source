import 'dart:io';

import 'package:decoy_wallet_app/create_decoy_seed/seed_handoff.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against the decoy mnemonic travelling through router
/// query/path params (which become URLs on web, history, logs).
void main() {
  List<File> appSources() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('no route ever carries a mnemonic/seed query or path parameter', () {
    final offenders = <String>[];
    final paramKey =
        RegExp(r'''['"](mnemonic|seedPhrase)['"]\s*:\s*serializeParam''');
    final getParamKey =
        RegExp(r'''getParam[^(]*\(\s*['"](mnemonic|seedPhrase)['"]''');
    for (final file in appSources()) {
      final src = file.readAsStringSync();
      if (paramKey.hasMatch(src) || getParamKey.hasMatch(src)) {
        offenders.add(file.path);
      }
      // Path templates such as '/showSeed/:mnemonic'.
      if (RegExp(r''':(mnemonic|seedPhrase)\b''').hasMatch(src)) {
        offenders.add('${file.path} (path template)');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Mnemonic must use SeedHandoff, never router params');
  });

  test('seed flow screens never print or log the mnemonic', () {
    final logCall = RegExp(
        r'''(print|debugPrint|log|logger\.\w+)\([^;]*mnemonic''',
        caseSensitive: false);
    final offenders = [
      for (final f in appSources())
        if (logCall.hasMatch(f.readAsStringSync())) f.path
    ];
    expect(offenders, isEmpty);
  });

  group('SeedHandoff', () {
    tearDown(SeedHandoff.clear);

    test('returns mnemonic only for the matching decoy id', () {
      SeedHandoff.put(mnemonic: 'abandon ability', decoyId: 'd1');
      expect(SeedHandoff.mnemonicFor('d1'), 'abandon ability');
      expect(SeedHandoff.mnemonicFor('d2'), isNull);
      expect(SeedHandoff.mnemonicFor(null), isNull);
    });

    test('clear drops the mnemonic', () {
      SeedHandoff.put(mnemonic: 'abandon ability', decoyId: 'd1');
      SeedHandoff.clear();
      expect(SeedHandoff.hasPending, isFalse);
      expect(SeedHandoff.mnemonicFor('d1'), isNull);
    });

    test('a new generation replaces the previous mnemonic', () {
      SeedHandoff.put(mnemonic: 'old words', decoyId: 'd1');
      SeedHandoff.put(mnemonic: 'new words', decoyId: 'd2');
      expect(SeedHandoff.mnemonicFor('d1'), isNull);
      expect(SeedHandoff.mnemonicFor('d2'), 'new words');
    });
  });
}
