import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/voice_intent.dart';
import '../models/voice_parser.dart';

/// Something the user needs to be told, in words they can act on.
class VoiceException implements Exception {
  final String message;
  const VoiceException(this.message);

  @override
  String toString() => message;
}

/// Set on every response by worker versions that know the /voice route (see
/// WORKER_VERSION in worker/src/index.js). A JSON error without it came
/// from a worker deployed before /voice existed, which answers every
/// unknown address with the scanner.
const kWorkerVersionHeader = 'x-solidus-worker';

/// Asks the worker in worker/ what a transcribed voice command meant, at
/// the same address and under the same account token as [ScanService] and
/// [AdviceService] -- all three share one worker, one auth check, and one
/// daily quota.
///
/// When the worker can't answer -- unreachable, over its quota, or still
/// running a version from before /voice -- the phrase is read on the
/// device instead by [parseVoiceCommand]. The assistant's first release
/// depended on the worker alone, and a worker left undeployed answered
/// every perfectly heard command with the scanner's "Пустой снимок".
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

  /// The worker first -- it understands far looser speech -- then the
  /// device. A record or question either one recognises is returned; the
  /// worker's own error surfaces only when the device couldn't make sense
  /// of the phrase either, since that is the only case the user has to act
  /// on.
  Future<VoiceIntent> parse(String text, {DateTime? today}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const VoiceException('Не расслышал, повторите');
    }
    final now = today ?? DateTime.now();

    VoiceException? failure;
    try {
      final remote = await _parseRemotely(trimmed, now);
      if (remote is! VoiceUnclearIntent) return remote;
    } on VoiceException catch (error) {
      failure = error;
    }

    final local = parseVoiceCommand(trimmed, today: now);
    if (local is! VoiceUnclearIntent || failure == null) return local;
    throw failure;
  }

  Future<VoiceIntent> _parseRemotely(String text, DateTime now) async {
    if (_endpoint.isEmpty) {
      throw const VoiceException('Голосовой помощник не настроен');
    }

    final token = await _token();
    if (token == null || token.isEmpty) {
      throw const VoiceException(
          'Нет связи с аккаунтом, перезапустите приложение');
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_endpoint).resolve('voice'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'text': text, 'today': _isoDate(now)}),
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
      final fromCurrentWorker = response.headers.keys
          .any((name) => name.toLowerCase() == kWorkerVersionHeader);
      if (message is String && !fromCurrentWorker) {
        // Our worker answered -- the JSON error says so -- but a version
        // from before /voice existed, which sends the phrase to the
        // scanner. Its "Пустой снимок" would mean nothing to anyone.
        throw const VoiceException(
          'Сервер ещё не обновлён под голосовые команды, а эту фразу без '
          'него разобрать не удалось. Скажите проще, например: «потратил '
          '500 на такси»',
        );
      }
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
