import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entities.dart';

class Vault {
  final aes = AesGcm.with256bits();
  SecretKey get key => SecretKey(
    Uint8List.fromList(List.generate(32, (i) => (i * 41 + 17) % 255)),
  );
  Future<Data?> load() async {
    try {
      final s = (await SharedPreferences.getInstance()).getString('nimble.v2');
      if (s == null) return null;
      final b = base64Decode(s),
          box = SecretBox(
            b.sublist(12, b.length - 16),
            nonce: b.sublist(0, 12),
            mac: Mac(b.sublist(b.length - 16)),
          );
      return Data.f(
        jsonDecode(utf8.decode(await aes.decrypt(box, secretKey: key))),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Data d) async {
    final b = await aes.encrypt(utf8.encode(jsonEncode(d.j())), secretKey: key);
    await (await SharedPreferences.getInstance()).setString(
      'nimble.v2',
      base64Encode([...b.nonce, ...b.cipherText, ...b.mac.bytes]),
    );
  }
}
