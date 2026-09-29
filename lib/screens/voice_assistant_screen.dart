import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart';

import '../data/speech_recognizer.dart';
import '../data/voice_service.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../models/transaction_type.dart';
import '../models/voice_answer.dart';
import '../models/voice_intent.dart';
import '../theme.dart';
import '../widgets/app_background_pattern.dart';
import '../widgets/readable_width.dart';

enum _Stage {
  initializing,
  listening,
  processing,
  answered,
  unclear,
  error,
  unsupported,
}

/// Listens for one spoken command and either hands back a draft record for
/// [AddExpenseSheet] to confirm, or answers a spending question on the
/// spot from records already on the device.
///
/// Pushed like a dialog rather than a plain route: the caller awaits its
/// result, which is a draft [Expense] exactly when the command was "add a
/// record" and there is a sheet left to open, and null for everything
/// else (a question, answered here; the screen simply closed). Always
/// starts listening the moment it opens -- whether that open came from the
/// in-app button or the home-screen widget, the tap that got here already
/// said "I'm about to speak".
class VoiceAssistantScreen extends StatefulWidget {
  final AppCurrency currency;
  final List<Expense> expenses;

  /// Injectable for tests; production always gets the real microphone and
  /// the real worker.
  final SpeechRecognizer? recognizer;
  final VoiceService? service;

  const VoiceAssistantScreen({
    super.key,
    required this.currency,
    required this.expenses,
    this.recognizer,
    this.service,
  });

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  late final SpeechRecognizer _recognizer =
      widget.recognizer ?? PlatformSpeechRecognizer();
  late final VoiceService _service = widget.service ?? VoiceService();
  final _tts = FlutterTts();

  // Only ever running while _stage == listening -- see the note on _start
  // and _stopAndSubmit. An indeterminate animation left running past its
  // one job is exactly what turned into a battery-draining bug on the home
  // screen; this one is scoped tightly on purpose.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  _Stage _stage = _Stage.initializing;
  String _transcript = '';
  String? _errorText;
  VoiceAnswer? _answer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _recognizer.cancel();
    _service.dispose();
    unawaited(_tts.stop());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _stage = _Stage.initializing;
      _transcript = '';
      _answer = null;
    });

    final ready = await _recognizer.initialize();
    if (!mounted) return;
    if (!ready) {
      setState(() {
        _stage = _Stage.unsupported;
        _errorText = 'Нет доступа к микрофону. Проверьте разрешение в '
            'настройках телефона';
      });
      return;
    }

    setState(() => _stage = _Stage.listening);
    _pulse.repeat(reverse: true);
    await _recognizer.listen(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _transcript = text);
      },
      onDone: () {
        if (!mounted) return;
        _pulse.stop();
        _submit();
      },
    );
  }

  Future<void> _stopAndSubmit() async {
    if (_stage != _Stage.listening) return;
    _pulse.stop();
    await _recognizer.stop();
    if (!mounted) return;
    _submit();
  }

  Future<void> _submit() async {
    final text = _transcript.trim();
    if (text.isEmpty) {
      setState(() => _stage = _Stage.unclear);
      return;
    }
    setState(() => _stage = _Stage.processing);

    VoiceIntent intent;
    try {
      intent = await _service.parse(text);
    } on VoiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.message;
        _stage = _Stage.error;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Не удалось разобрать команду';
        _stage = _Stage.error;
      });
      return;
    }
    if (!mounted) return;

    switch (intent) {
      case VoiceAddIntent():
        Navigator.of(context).pop(
          Expense(
            id: const Uuid().v4(),
            amount: intent.amount,
            date: intent.date,
            category: intent.category,
            note: intent.note,
            currency: widget.currency,
            type: intent.type == VoiceRecordType.income
                ? TransactionType.income
                : TransactionType.expense,
          ),
        );
      case VoiceQueryIntent():
        final answer = answerVoiceQuery(
          widget.expenses,
          intent,
          currency: widget.currency,
        );
        setState(() {
          _answer = answer;
          _stage = _Stage.answered;
        });
        unawaited(_speak(answer.sentence));
      case VoiceUnclearIntent():
        setState(() => _stage = _Stage.unclear);
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.setLanguage('ru-RU');
      await _tts.speak(text);
    } catch (_) {
      // Best-effort only: the answer is already written on screen either
      // way, so a browser or device with no voices installed loses
      // nothing but the reading of it aloud.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Голосовой помощник')),
      body: AppBackgroundPattern(
        child: ReadableWidth(
          child: Center(child: _buildBody(context)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_stage) {
      case _Stage.initializing:
        return CircularProgressIndicator(
          backgroundColor: goldFor(context).withValues(alpha: 0.16),
          color: goldFor(context),
        );

      case _Stage.listening:
        return _Listening(
          pulse: _pulse,
          transcript: _transcript,
          onStop: _stopAndSubmit,
        );

      case _Stage.processing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              backgroundColor: goldFor(context).withValues(alpha: 0.16),
              color: goldFor(context),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '«$_transcript»',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: accentForeground(context).withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        );

      case _Stage.answered:
        return _AnswerView(
          answer: _answer!,
          onAskAgain: _start,
          onDone: () => Navigator.of(context).pop(),
        );

      case _Stage.unclear:
        return _MessageView(
          icon: Icons.help_outline_rounded,
          message: 'Не расслышал команду.\nПопробуйте сказать ещё раз',
          onRetry: _start,
        );

      case _Stage.error:
        return _MessageView(
          icon: Icons.error_outline_rounded,
          message: _errorText ?? 'Что-то пошло не так',
          onRetry: _start,
        );

      case _Stage.unsupported:
        return _MessageView(
          icon: Icons.mic_off_rounded,
          message: _errorText ?? 'Голосовой ввод недоступен',
          onRetry: null,
        );
    }
  }
}

class _Listening extends StatelessWidget {
  final AnimationController pulse;
  final String transcript;
  final VoidCallback onStop;

  const _Listening({
    required this.pulse,
    required this.transcript,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (context, child) =>
              Transform.scale(scale: 1.0 + pulse.value * 0.18, child: child),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: goldFor(context).withValues(alpha: 0.16),
              border:
                  Border.all(color: goldFor(context).withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.mic_rounded, size: 40, color: goldFor(context)),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            transcript.isEmpty ? 'Говорите…' : transcript,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: accentForeground(context)),
          ),
        ),
        const SizedBox(height: 24),
        TextButton(onPressed: onStop, child: const Text('Готово')),
      ],
    );
  }
}

class _AnswerView extends StatelessWidget {
  final VoiceAnswer answer;
  final VoidCallback onAskAgain;
  final VoidCallback onDone;

  const _AnswerView({
    required this.answer,
    required this.onAskAgain,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 40, color: goldFor(context)),
          const SizedBox(height: 18),
          Text(
            answer.sentence,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: accentForeground(context),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: onAskAgain,
                child: const Text('Спросить ещё'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: onDone, child: const Text('Готово')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const _MessageView({required this.icon, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: goldFor(context).withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: accentForeground(context).withValues(alpha: 0.75),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ],
      ),
    );
  }
}
