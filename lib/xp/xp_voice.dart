import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// xp's ears (speech-to-text) and voice (text-to-speech).
class XpVoice {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  bool _ttsReady = false;
  bool _sttReady = false;

  void Function()? onSpeakStart;
  void Function()? onSpeakDone;

  /// Female voices, best first. Android (Google TTS) ids and iOS voice names.
  static const _preferredVoices = [
    'en-in-x-ahp', 'en-in-x-cxx', 'en-in-x-ena', 'en-us-x-tpf', 'en-us-x-sfg', 'en-us-x-tpc', 'en-gb-x-gba', 'en-gb-x-gbc',
    'isha', 'veena', 'samantha', 'karen', 'tessa', 'moira', 'serena', 'kate', 'zira', 'heera',
  ];
  static const _maleVoiceHints = ['male', 'rishi', 'daniel', 'alex', 'fred', 'en-in-x-end', 'en-us-x-iom', 'en-us-x-iol', 'en-us-x-tpd'];

  Future<void> _initTts() async {
    if (_ttsReady) return;
    _ttsReady = true;
    try {
      if (!kIsWeb && Platform.isIOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [IosTextToSpeechAudioCategoryOptions.mixWithOthers]);
      }
      await _tts.setLanguage('en-IN');
      await _pickFemaleVoice();
      // a touch brighter and slower than default: warm and clear
      await _tts.setPitch(1.12);
      await _tts.setSpeechRate(!kIsWeb && Platform.isIOS ? 0.5 : 0.47);
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() => onSpeakStart?.call());
      _tts.setCompletionHandler(() => onSpeakDone?.call());
      _tts.setCancelHandler(() => onSpeakDone?.call());
      _tts.setErrorHandler((_) => onSpeakDone?.call());
    } catch (e) {
      debugPrint('xp tts init failed: $e');
    }
  }

  Future<void> _pickFemaleVoice() async {
    final raw = await _tts.getVoices;
    if (raw is! List) return;
    final voices = raw
        .whereType<Map>()
        .map((v) => {'name': '${v['name'] ?? ''}', 'locale': '${v['locale'] ?? ''}'})
        .where((v) => v['locale']!.toLowerCase().startsWith('en'))
        .toList();
    if (voices.isEmpty) return;

    int score(Map<String, String> v) {
      final name = v['name']!.toLowerCase();
      final locale = v['locale']!.toLowerCase().replaceAll('_', '-');
      if (_maleVoiceHints.any(name.contains)) return -100;
      var s = 0;
      final i = _preferredVoices.indexWhere(name.contains);
      if (i >= 0) s += 100 - i;
      if (name.contains('female')) s += 80;
      if (locale == 'en-in') s += 20;
      if (name.contains('local')) s += 5; // works offline
      return s;
    }

    voices.sort((a, b) => score(b).compareTo(score(a)));
    if (score(voices.first) > 0) await _tts.setVoice(voices.first);
  }

  Future<void> speak(String text) async {
    await _initTts();
    await _tts.stop();
    final clean = forSpeech(text);
    if (clean.isNotEmpty) await _tts.speak(clean);
  }

  Future<void> stopSpeaking() async {
    if (_ttsReady) await _tts.stop();
  }

  /// Turns chat text into something that sounds natural out loud.
  static String forSpeech(String text) {
    return text
        .replaceAllMapped(RegExp(r'₹\s?([\d,]+(?:\.\d+)?)'), (m) => '${m.group(1)} rupees')
        .replaceAll('•', '')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true), '')
        .replaceAll(RegExp(r'\bxp\b'), 'X P')
        .replaceAll(RegExp(r'\s*\n\s*'), '. ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<bool> initListening({void Function(String status)? onStatus, void Function(String error)? onError}) async {
    if (_sttReady) return true;
    _sttReady = await _stt.initialize(
      onStatus: (s) => onStatus?.call(s),
      onError: (e) => onError?.call(e.errorMsg),
    );
    return _sttReady;
  }

  bool get isListening => _stt.isListening;

  Future<void> listen({required void Function(String words, bool isFinal) onWords, required void Function(double level) onLevel}) async {
    await stopSpeaking();
    String? locale;
    try {
      final locales = await _stt.locales();
      final ids = locales.map((l) => l.localeId).toList();
      locale = ids.contains('en_IN') ? 'en_IN' : ids.firstWhere((id) => id.startsWith('en'), orElse: () => ids.isEmpty ? 'en_US' : ids.first);
    } catch (_) {}
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) => onWords(r.recognizedWords, r.finalResult),
      // Android reports roughly -2..10 dB; map to 0..1
      onSoundLevelChange: (level) => onLevel(((level + 2) / 12).clamp(0.0, 1.0)),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        localeId: locale,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> stopListening() => _stt.stop();

  Future<void> dispose() async {
    await _stt.cancel();
    if (_ttsReady) await _tts.stop();
  }
}
