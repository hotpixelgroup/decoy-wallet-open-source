/// In-memory hand-off for the freshly generated decoy mnemonic.
///
/// The mnemonic must never travel through router query/path parameters:
/// on web those become part of the URL (address bar, history, server logs,
/// crash reporters), and on mobile they can surface in route restoration or
/// diagnostics. Instead the generating screen stores it here and the
/// show/verify routes read it back. It is never persisted, never logged, and
/// is cleared once verification completes or a new mnemonic is generated.
class SeedHandoff {
  SeedHandoff._();

  static String? _mnemonic;
  static String? _decoyId;

  /// Stores [mnemonic] for the decoy identified by [decoyId].
  static void put({required String? mnemonic, required String? decoyId}) {
    _mnemonic = mnemonic;
    _decoyId = decoyId;
  }

  /// Returns the mnemonic only when it belongs to [decoyId].
  static String? mnemonicFor(String? decoyId) {
    if (_mnemonic == null || decoyId == null || decoyId != _decoyId) {
      return null;
    }
    return _mnemonic;
  }

  static bool get hasPending => _mnemonic != null;

  static void clear() {
    _mnemonic = null;
    _decoyId = null;
  }
}
