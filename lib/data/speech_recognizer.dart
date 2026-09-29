import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// What listening for a spoken command actually needs: ask the platform
/// for permission once, start and stop a listening session, and report
/// words back as they are recognised.
///
/// A thin interface over the speech_to_text package rather than its own
/// class used directly throughout the app, so a widget test can drive the
/// whole voice flow with a fake instead of a real microphone.
abstract class SpeechRecognizer {
  /// Requests the platform's speech permission and readies the engine.
  /// False means there is nothing this session can do -- no microphone
  /// permission, or the platform has no speech recognition at all.
  Future<bool> initialize();

  /// Starts one listening session. [onResult] is called with the words
  /// heard so far and whether that is the final read of them; [onDone] is
  /// called once the session ends on its own (silence, a time limit) --
  /// not when [stop] or [cancel] ends it, since the caller already knows
  /// that.
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  });

  /// Ends the session and keeps whatever was already recognised.
  Future<void> stop();

  /// Ends the session and discards it.
  Future<void> cancel();

  bool get isListening;
}

/// The real recognizer, backed by the platform's own speech engine.
class PlatformSpeechRecognizer implements SpeechRecognizer {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;

  @override
  Future<bool> initialize() async {
    _available = await _speech.initialize();
    return _available;
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    if (!_available) return;
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
        if (result.finalResult) onDone();
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: 'ru_RU',
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

  @override
  bool get isListening => _speech.isListening;
}
