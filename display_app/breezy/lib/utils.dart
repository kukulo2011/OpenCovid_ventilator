import 'dart:math' show Random;

/// A minimal implementation of v4 UUIDs.
/// cf. https://tools.ietf.org/html/rfc4122
class UUID {
  final int time_low; // 4 bytes
  final int time_mid; // 2 bytes
  final int time_hi_and_version; // 2 bytes
  final int clock_seq_hi_and_reserved; // 1 byte
  final int clock_seq_low; // 1 byte
  final int node; // 6 bytes

  static final Random _random = Random.secure();

  /// Generate a random (v4) UUID
  UUID.random()
      : clock_seq_hi_and_reserved = 0x80 | _random.nextInt(0x40),
        time_hi_and_version = 0x4000 | _random.nextInt(0x1000),
        time_low = _random.nextInt(0x100000000),
        time_mid = _random.nextInt(0x10000),
        clock_seq_low = _random.nextInt(0x100),
        node = (_random.nextInt(0x10000) << 8) | _random.nextInt(0x100000000);

  String toString() {
    return toHex(time_low, 8) +
        '-' +
        toHex(time_mid, 4) +
        '-' +
        toHex(time_hi_and_version, 4) +
        '-' +
        toHex(clock_seq_hi_and_reserved, 2) + // no dash
        toHex(clock_seq_low, 2) +
        '-' +
        toHex(node, 12);
  }
}

String toHex(int value, int digits) {
  String s = value.toRadixString(16);
  const String zeros = '0000000000000000'; // Enough for 64 bits
  return zeros.substring(0, digits - s.length) + s;
}
