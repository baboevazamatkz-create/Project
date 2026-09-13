import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../models/currency.dart';
import '../models/scanned_transaction.dart';

/// A snapshot on its way to the scanner.
class ScanImage {
  final Uint8List bytes;
  final String mime;

  const ScanImage({required this.bytes, required this.mime});

  Map<String, dynamic> toJson() => {'data': base64Encode(bytes), 'mime': mime};
}

/// Something the user needs to be told, in words they can act on.
class ScanException implements Exception {
  final String message;
  const ScanException(this.message);

  @override
  String toString() => message;
}

/// Reads snapshots through the Cloudflare worker in worker/.
///
/// The address arrives at build time rather than living in the source:
/// it is not a secret, but it changes per deployment, and an unset one has
/// to mean "the scanner is not set up" rather than "the app is broken".
class ScanService {
  /// Set with --dart-define=SCAN_ENDPOINT=..., which both workflows pass
  /// from the repository variable of the same name.
  static const endpoint = String.fromEnvironment('SCAN_ENDPOINT');

  static bool get isConfigured => endpoint.isNotEmpty;

  /// Beyond this the worker refuses the snapshot; the app never gets
  /// close, since [prepareScanImage] resizes first.
  static const maxImages = 4;

  final http.Client _client;
  final Future<String?> Function() _token;
  final String _endpoint;

  /// [endpoint] and [token] exist so the whole request can be driven in a
  /// test: a compile-time constant cannot be set from one, and the real
  /// token comes from Firebase.
  ScanService({
    http.Client? client,
    Future<String?> Function()? token,
    String? endpoint,
  })  : _client = client ?? http.Client(),
        _token = token ?? _firebaseToken,
        _endpoint = endpoint ?? ScanService.endpoint;

  static Future<String?> _firebaseToken() =>
      FirebaseAuth.instance.currentUser?.getIdToken() ?? Future.value(null);

  Future<ScanResult> scan({
    required List<ScanImage> images,
    required AppCurrency currency,
    DateTime? today,
  }) async {
    if (_endpoint.isEmpty) {
      throw const ScanException('Сканер не настроен');
    }
    if (images.isEmpty || images.length > maxImages) {
      throw const ScanException('Нужно от одного до $maxImages снимков');
    }

    final token = await _token();
    if (token == null || token.isEmpty) {
      throw const ScanException(
          'Нет связи с аккаунтом, перезапустите приложение');
    }

    final now = today ?? DateTime.now();
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'images': images.map((i) => i.toJson()).toList(),
              'currency': currency.storageKey,
              'today': _isoDate(now),
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw const ScanException(
          'Не удалось связаться со сканером. Проверьте интернет');
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200) {
      final message = body?['error'];
      throw ScanException(
        message is String && message.isNotEmpty
            ? message
            : 'Сканер ответил ошибкой (${response.statusCode})',
      );
    }
    if (body == null) {
      throw const ScanException('Сканер вернул непонятный ответ');
    }

    return ScanResult.fromJson(body, fallbackCurrency: currency);
  }

  void dispose() => _client.close();
}

String _isoDate(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

/// What a model reads an image at. Past this, extra pixels cost tokens and
/// upload time without making any digit easier to read.
const int kScanMaxEdge = 1568;

/// Below this a snapshot goes as it is: the picker has already resized it
/// natively, and decoding a second time in Dart would cost a visible pause
/// -- on the web it happens on the only thread there is.
const int kScanPassThroughBytes = 500 * 1024;

/// Brings a picked photo down to something worth uploading.
///
/// Pure and synchronous so it can be tested without a picker: give it the
/// bytes, get back what should be sent.
ScanImage prepareScanImage(Uint8List raw) {
  final mime = _sniffMime(raw);
  if (mime != null && raw.length <= kScanPassThroughBytes) {
    return ScanImage(bytes: raw, mime: mime);
  }

  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    // Unreadable here does not mean unreadable by the model -- an exotic
    // but valid JPEG, say -- so send it on rather than refusing.
    return ScanImage(bytes: raw, mime: mime ?? 'image/jpeg');
  }

  final longest = math.max(decoded.width, decoded.height);
  final resized = longest > kScanMaxEdge
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? kScanMaxEdge : null,
          height: decoded.height > decoded.width ? kScanMaxEdge : null,
          interpolation: img.Interpolation.average,
        )
      : decoded;

  return ScanImage(
    bytes: img.encodeJpg(resized, quality: 82),
    mime: 'image/jpeg',
  );
}

String? _sniffMime(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}
