import 'package:expense_tracker/data/api_client.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:expense_tracker/state/finance_provider.dart';
import 'package:expense_tracker/state/session_provider.dart';
import 'package:expense_tracker/state/settings_provider.dart';
import 'package:expense_tracker/widgets/xp_orb.dart';
import 'package:expense_tracker/xp/xp_engine.dart';
import 'package:expense_tracker/xp/xp_voice.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class XpMessage {
  final bool fromUser;
  final String text;
  final List<XpCard> cards;
  final List<String> suggestions;
  final bool viaCloud;
  const XpMessage({required this.fromUser, required this.text, this.cards = const [], this.suggestions = const [], this.viaCloud = false});
}

/// Lets the engine read and write through the app's providers.
class _ProviderData implements XpData {
  _ProviderData(this.finance, this.session);
  final FinanceProvider finance;
  final SessionProvider session;

  @override
  String get userName => session.user?.name ?? '';
  @override
  List<Txn> get transactions => finance.transactions;
  @override
  double get balance => finance.balance;
  @override
  double get monthlyBudget => session.user?.monthlyBudget ?? 0;
  @override
  Map<String, double> get categoryBudgets => finance.budgets;
  @override
  Future<Txn> addTransaction(TxnDraft draft) => finance.add(draft);
  @override
  Future<void> removeTransaction(Txn txn) => finance.remove(txn);
}

/// One xp conversation: messages, voice and the orb's mood.
class XpController with ChangeNotifier {
  XpController({required this.finance, required this.session, required this.settings, XpVoice? voice})
      : voice = voice ?? XpVoice(),
        _engine = XpEngine(_ProviderData(finance, session)) {
    this.voice.onSpeakStart = () => _setMood(OrbMood.speaking);
    this.voice.onSpeakDone = () {
      if (_mood == OrbMood.speaking) _setMood(OrbMood.idle);
    };
  }

  final FinanceProvider finance;
  final SessionProvider session;
  final SettingsProvider settings;
  final XpVoice voice;
  final XpEngine _engine;

  final List<XpMessage> messages = [];
  OrbMood _mood = OrbMood.idle;
  String _liveWords = '';
  double _level = 0;
  bool _busy = false;
  bool _disposed = false;

  OrbMood get mood => _mood;
  String get liveWords => _liveWords;
  double get level => _level;
  bool get busy => _busy;
  bool get listening => _mood == OrbMood.listening;

  void greet() {
    if (messages.isNotEmpty) return;
    final name = session.user?.firstName ?? '';
    messages.add(XpMessage(
      fromUser: false,
      text: "Hey${name.isEmpty ? '' : ' $name'}! I'm xp 💜 Tell me what you spent, or ask me anything about your money. You can type or tap the mic.",
      suggestions: XpEngine.defaultSuggestions,
    ));
    notifyListeners();
  }

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    messages.add(XpMessage(fromUser: true, text: text));
    _busy = true;
    _setMood(OrbMood.thinking);

    XpMessage reply;
    try {
      final local = await _engine.respond(text);
      reply = local != null
          ? XpMessage(fromUser: false, text: local.text, cards: local.cards, suggestions: local.suggestions)
          : await _askCloud(text);
    } on ApiException catch (e) {
      reply = XpMessage(fromUser: false, text: "Oops, I couldn't save that: ${e.message}");
    } catch (e) {
      debugPrint('xp failed: $e');
      reply = const XpMessage(fromUser: false, text: 'Something went sideways on my end. Mind trying that again?');
    }

    if (_disposed) return;
    messages.add(reply);
    _busy = false;
    _setMood(OrbMood.idle);
    if (settings.xpVoice) await voice.speak(reply.text);
  }

  Future<XpMessage> _askCloud(String text) async {
    // last few turns so the cloud brain has context, without the message we just added
    final history = messages
        .take(messages.length - 1)
        .toList()
        .reversed
        .take(10)
        .toList()
        .reversed
        .map((m) => {'role': m.fromUser ? 'user' : 'xp', 'text': m.text})
        .toList();
    try {
      final r = await finance.api.xpChat(text, history);
      if (r.mutated) await finance.load();
      return XpMessage(fromUser: false, text: r.reply, viaCloud: true);
    } on ApiException {
      return const XpMessage(
        fromUser: false,
        text: "Hmm, I didn't quite catch that one. Try things like \"spent 200 on coffee\", \"how much did I spend last week?\" or \"how can I save more?\"",
        suggestions: XpEngine.defaultSuggestions,
      );
    }
  }

  /// Tap the mic: start listening, or stop and send what we heard.
  Future<String?> toggleListening() async {
    if (listening) {
      await voice.stopListening();
      return null;
    }
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      return status.isPermanentlyDenied ? 'Microphone access is off. Turn it on in Settings to talk to xp.' : 'xp needs the microphone to hear you.';
    }
    final ok = await voice.initListening(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && listening) _finishListening();
      },
      onError: (_) {
        if (listening) _finishListening();
      },
    );
    if (!ok) return "Speech recognition isn't available on this device.";

    _liveWords = '';
    _setMood(OrbMood.listening);
    await voice.listen(
      onWords: (words, isFinal) {
        _liveWords = words;
        notifyListeners();
        if (isFinal) _finishListening();
      },
      onLevel: (l) {
        _level = l;
        notifyListeners();
      },
    );
    return null;
  }

  void _finishListening() {
    if (_mood != OrbMood.listening) return;
    final words = _liveWords;
    _liveWords = '';
    _level = 0;
    _setMood(OrbMood.idle);
    if (words.trim().isNotEmpty) send(words);
  }

  Future<void> stopSpeaking() async {
    await voice.stopSpeaking();
    _setMood(OrbMood.idle);
  }

  void _setMood(OrbMood m) {
    if (_disposed) return;
    _mood = m;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    voice.dispose();
    super.dispose();
  }
}
