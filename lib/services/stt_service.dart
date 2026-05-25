import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text in Brazilian Portuguese.
/// Parses free-form voice commands such as:
///   "estou na entrada do Caixa Cultural e quero ir até o banheiro"
class SttService {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;

  Future<bool> init() async {
    _available = await _stt.initialize(
      onStatus: (_) {},
      onError: (_) {},
    );
    return _available;
  }

  bool get isAvailable => _available;
  bool get isListening => _stt.isListening;

  Future<String?> listenOnce({int timeoutSeconds = 8}) async {
    if (!_available) return null;

    String? result;
    await _stt.listen(
      onResult: (r) {
        result = r.recognizedWords;
      },
      localeId: 'pt_BR',
      listenFor: Duration(seconds: timeoutSeconds),
      pauseFor: const Duration(seconds: 3),
    );

    // Wait until listening ends
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      return _stt.isListening;
    });

    return result;
  }

  void stop() => _stt.stop();

  /// Minimal NLP: extract origin and destination from command.
  /// Patterns:
  ///   "estou em/na/no <origin> e quero ir até/para <destination>"
  ///   "ir para <destination>"
  ///   "<destination>" (assume current position is origin)
  ({String? origin, String? destination}) parseCommand(String text) {
    final lower = text.toLowerCase();

    // Pattern: "estou ... <origin> ... quero ir ... <destination>"
    final fullRegex = RegExp(
      r'(?:estou\s+(?:em|na|no|n[ao])\s+)([\w\s]+?)'
      r'\s+(?:e\s+)?(?:quero\s+)?(?:ir|navegar|chegar)'
      r'\s+(?:até|para|ao|à|a)\s+([\w\s]+)',
    );
    final fullMatch = fullRegex.firstMatch(lower);
    if (fullMatch != null) {
      return (
        origin: _clean(fullMatch.group(1)),
        destination: _clean(fullMatch.group(2)),
      );
    }

    // Pattern: "ir para/até <destination>"
    final destRegex =
        RegExp(r'(?:ir|navegar|chegar)\s+(?:para|até|ao|à|a)\s+([\w\s]+)');
    final destMatch = destRegex.firstMatch(lower);
    if (destMatch != null) {
      return (origin: null, destination: _clean(destMatch.group(1)));
    }

    // Fallback: treat entire text as destination query
    return (origin: null, destination: _clean(lower));
  }

  String? _clean(String? s) {
    if (s == null) return null;
    return s.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
