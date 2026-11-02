import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:expense_tracker/data/api_client.dart';
import 'package:expense_tracker/sms/sms_parser.dart';
import 'package:expense_tracker/state/finance_provider.dart';
import 'package:expense_tracker/state/settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads bank / UPI SMS (Android only) and turns them into transactions,
/// either straight away or into a review list, depending on the user's setting.
/// Payments whose SMS doesn't say what they were for wait in [awaitingDetails]
/// until the user names them.
class SmsSync with ChangeNotifier {
  SmsSync({required this.finance, required this.settings});

  final FinanceProvider finance;
  final SettingsProvider settings;

  static const _channel = MethodChannel('expensify/sms');
  static const _incoming = EventChannel('expensify/sms/incoming');
  static const _pendingKey = 'sms_pending_review';
  static const _awaitingKey = 'sms_awaiting_details';

  /// Only ask about payments this recent; older ones (first-time backfill) are added as they are.
  static const askWindow = Duration(hours: 24);

  /// SMS reading only exists on Android. iOS doesn't allow apps to read messages.
  static bool get supported => !kIsWeb && Platform.isAndroid;

  List<DetectedTxn> _pending = [];
  List<DetectedTxn> _awaiting = [];
  StreamSubscription<dynamic>? _live;
  bool _syncing = false;
  int _lastAddedCount = 0;

  /// Detected transactions waiting for the user to approve.
  List<DetectedTxn> get pending => _pending;

  /// Detected payments where we need the user to say what they were for.
  List<DetectedTxn> get awaitingDetails => _awaiting;

  bool get syncing => _syncing;

  /// How many were added automatically by the last sync (for the "3 new from SMS" toast).
  int takeLastAddedCount() {
    final n = _lastAddedCount;
    _lastAddedCount = 0;
    return n;
  }

  Future<void> init() async {
    if (!supported) return;
    final prefs = await SharedPreferences.getInstance();
    _pending = _load(prefs, _pendingKey);
    _awaiting = _load(prefs, _awaitingKey);
    // the native receiver uses these to decide whether the notification should ask "what was it for?"
    await prefs.setString('sms_category_words', categoryWordList().join('|'));
    notifyListeners();
    if (settings.smsEnabled) await start();
  }

  List<DetectedTxn> _load(SharedPreferences prefs, String key) =>
      (prefs.getStringList(key) ?? []).map((s) => DetectedTxn.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();

  /// Asks for SMS (+ notification) permission. Returns false if refused.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    final sms = await Permission.sms.request();
    await Permission.notification.request();
    return sms.isGranted;
  }

  Future<bool> get hasPermission async => supported && await Permission.sms.isGranted;

  /// Turns on detection: catch up on the inbox, then listen for new messages.
  Future<void> start() async {
    if (!supported || !await hasPermission) return;
    _live ??= _incoming.receiveBroadcastStream().listen((event) {
      if (event is Map) _handle([SmsMessage.fromMap(event)]);
    }, onError: (_) {});
    await sync();
  }

  Future<void> stop() async {
    await _live?.cancel();
    _live = null;
  }

  /// Scans messages since the last scan (first time: the last 30 days).
  Future<void> sync() async {
    if (!supported || _syncing || !settings.smsEnabled || !await hasPermission) return;
    _syncing = true;
    notifyListeners();
    try {
      final last = settings.smsLastScan;
      final since = last > 0 ? last : DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
      // queued first: those may carry the user's answer from the notification
      final queued = await _channel.invokeListMethod<Map<dynamic, dynamic>>('takePending') ?? [];
      final inbox = await _channel.invokeListMethod<Map<dynamic, dynamic>>('readInbox', {'since': since, 'limit': 500}) ?? [];
      final messages = [...queued, ...inbox].map(SmsMessage.fromMap).toList();
      await _handle(messages);
      if (messages.isNotEmpty) {
        final newest = messages.map((m) => m.date.millisecondsSinceEpoch).reduce((a, b) => a > b ? a : b);
        await settings.setSmsLastScan(newest > since ? newest : since);
      } else if (last == 0) {
        await settings.setSmsLastScan(DateTime.now().millisecondsSinceEpoch);
      }
    } on PlatformException catch (e) {
      debugPrint('sms sync failed: ${e.message}');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _handle(List<SmsMessage> messages) async {
    final seen = <String>{..._pending.map((p) => p.ref), ..._awaiting.map((p) => p.ref)};
    final ready = <DetectedTxn>[];
    final ask = <DetectedTxn>[];
    final now = DateTime.now();
    for (final m in messages) {
      final t = parseTransactionSms(m);
      if (t == null || !seen.add(t.ref)) continue;
      if (t.needsDetails && now.difference(t.date) < askWindow) {
        ask.add(t);
      } else {
        ready.add(t);
      }
    }

    if (ask.isNotEmpty) {
      _awaiting = [...ask, ..._awaiting]..sort((a, b) => b.date.compareTo(a.date));
      await _save(_awaitingKey, _awaiting);
      notifyListeners();
    }
    if (ready.isEmpty) return;

    if (settings.smsAutoAdd) {
      try {
        final added = await finance.addMany(ready.map((t) => t.toDraft()).toList());
        _lastAddedCount += added.length;
        notifyListeners();
      } on ApiException {
        // offline: keep them for review so nothing is lost
        await _addPending(ready);
      }
    } else {
      await _addPending(ready);
    }
  }

  Future<void> _addPending(List<DetectedTxn> items) async {
    _pending = [...items, ..._pending]..sort((a, b) => b.date.compareTo(a.date));
    await _save(_pendingKey, _pending);
    notifyListeners();
  }

  Future<void> approve(List<DetectedTxn> items) async {
    await finance.addMany(items.map((t) => t.toDraft()).toList());
    final refs = items.map((t) => t.ref).toSet();
    _pending = _pending.where((p) => !refs.contains(p.ref)).toList();
    await _save(_pendingKey, _pending);
    notifyListeners();
  }

  Future<void> dismiss(DetectedTxn item) async {
    _pending = _pending.where((p) => p.ref != item.ref).toList();
    await _save(_pendingKey, _pending);
    notifyListeners();
  }

  /// The user said what an unclear payment was. Adds it with their name and category.
  Future<void> saveDetails(DetectedTxn item, {required String title, required String category}) async {
    await finance.addMany([item.withDetails(title: title, category: category).toDraft()]);
    await _removeAwaiting(item);
  }

  /// The user didn't want to say. Adds it as detected.
  Future<void> skipDetails(DetectedTxn item) async {
    await finance.addMany([item.toDraft()]);
    await _removeAwaiting(item);
  }

  Future<void> _removeAwaiting(DetectedTxn item) async {
    _awaiting = _awaiting.where((p) => p.ref != item.ref).toList();
    await _save(_awaitingKey, _awaiting);
    notifyListeners();
  }

  Future<void> _save(String key, List<DetectedTxn> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, items.map((p) => jsonEncode(p.toJson())).toList());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }
}
