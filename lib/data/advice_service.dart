import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/spending_advice.dart';
import '../models/spending_snapshot.dart';

/// Something the user needs to be told, in words they can act on.
class AdviceException implements Exception {
  final String message;
  const AdviceException(this.message);

  @override
  String toString() => message;
}

/// Asks the worker in worker/ to read a [SpendingSnapshot] and hand back
/// advice for it, at the same address and under the same account token as
/// [ScanService] -- the two share one worker, one auth check, and one
/// daily quota.
class AdviceService {
  /// Set with --dart-define=SCAN_ENDPOINT=..., same variable the scanner
  /// uses: this is a second route (/advice) on the same worker, not a
  /// second deployment.
  static const endpoint = String.fromEnvironment('SCAN_ENDPOINT');

  static bool get isConfigured => endpoint.isNotEmpty;

  final http.Client _client;
  final Future<String?> Function() _token;
  final String _endpoint;

  /// [endpoint] and [token] exist so the whole request can be driven in a
  /// test: a compile-time constant cannot be set from one, and the real
  /// token comes from Firebase.
  AdviceService({
    http.Client? client,
    Future<String?> Function()? token,
    String? endpoint,
  })  : _client = client ?? http.Client(),
        _token = token ?? _firebaseToken,
        _endpoint = endpoint ?? AdviceService.endpoint;

  static Future<String?> _firebaseToken() =>
      FirebaseAuth.instance.currentUser?.getIdToken() ?? Future.value(null);

  Future<SpendingAdvice> advise(SpendingSnapshot snapshot) async {
    if (_endpoint.isEmpty) {
      throw const AdviceException('Советы не настроены');
    }

    final token = await _token();
    if (token == null || token.isEmpty) {
      throw const AdviceException(
          'Нет связи с аккаунтом, перезапустите приложение');
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_endpoint).resolve('advice'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(snapshot.toRequestJson()),
          )
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw const AdviceException(
          'Не удалось связаться с сервером. Проверьте интернет');
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
      throw AdviceException(
        message is String && message.isNotEmpty
            ? message
            : 'Сервер ответил ошибкой (${response.statusCode})',
      );
    }
    if (body == null) {
      throw const AdviceException('Сервер вернул непонятный ответ');
    }

    final advice = SpendingAdvice.tryFromJson(body);
    if (advice == null) {
      throw const AdviceException('Сервер вернул непонятный ответ');
    }
    return advice;
  }

  void dispose() => _client.close();
}
