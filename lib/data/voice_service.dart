import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/voice_intent.dart';

/// Something the user needs to be told, in words they can act on.
class VoiceException implements Exception {
  final String message;
  const VoiceException(this.message);

  @override
  String toString() => message;
}

/// Asks the worker in worker/ what a transcribed voice command meant, at
/// the same address and under the same account token as [ScanService] and
/// [AdviceService] -- all three share one worker, one auth check, and one
/// daily quota.
class VoiceService {
  /// Set with --dart-define=SCAN_ENDPOINT=..., the same variable the
  /// scanner and the advice screen use: this is a third route (/voice) on
  /// the same worker, not a second deployment.
  static const endpoint = String.fromEnvironment('SCAN_ENDPOINT');

  static bool get isConfigured => endpoint.isNotEmpty;

  final http.Client _client;
  final Future<String?> Function() _token;
  final String _endpoint;

  /// [endpoint] and [token] exist so the whole request can be driven in a
  /// test: a compile-time constant cannot be set from one, and the real
  /// token comes from Firebase.
  VoiceService({
    http.Client? client,
    Future<String?> Function()? token,
    String? endpoint,
  })  : _client = client ?? http.Client(),
        _token = token ?? _firebaseToken,
        _endpoint = endpoint ?? VoiceService.endpoint;

  static Future<String?> _firebaseToken() =>
      FirebaseAuth.instance.currentUser?.getIdToken() ?? Future.value(null);

  Future<VoiceIntent> parse(String text, {DateTime? today}) async {
    if (_endpoint.isEmpty) {
      throw const VoiceException('Голосовой помощник не настроен');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const VoiceException('Не расслышал, повторите');
    }

    final token = await _token();
    if (token == null || token.isEmpty) {
      throw const VoiceException(
          'Нет связи с аккаунтом, перезапустите приложение');
    }

    final now = today ?? DateTime.now();
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_endpoint).resolve('voice'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'text': trimmed, 'today': _isoDate(now)}),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const VoiceException(
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
      throw VoiceException(
        message is String && message.isNotEmpty
            ? message
            : 'Сервер ответил ошибкой (${response.statusCode})',
      );
    }
    if (body == null) {
      throw const VoiceException('Сервер вернул непонятный ответ');
    }

    return VoiceIntent.fromJson(body);
  }

  void dispose() => _client.close();
}

String _isoDate(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
