import 'package:expense_tracker/core/categories.dart';
import 'package:expense_tracker/core/format.dart';
import 'package:expense_tracker/core/theme.dart';
import 'package:expense_tracker/state/finance_provider.dart';
import 'package:expense_tracker/state/session_provider.dart';
import 'package:expense_tracker/state/settings_provider.dart';
import 'package:expense_tracker/widgets/common.dart';
import 'package:expense_tracker/widgets/txn_tile.dart';
import 'package:expense_tracker/widgets/xp_orb.dart';
import 'package:expense_tracker/xp/xp_controller.dart';
import 'package:expense_tracker/xp/xp_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

/// Chat with xp by typing or talking.
class XpScreen extends StatefulWidget {
  const XpScreen({super.key, this.initialQuestion});
  final String? initialQuestion;

  @override
  State<XpScreen> createState() => _XpScreenState();
}

class _XpScreenState extends State<XpScreen> {
  late final XpController _xp = XpController(
    finance: context.read<FinanceProvider>(),
    session: context.read<SessionProvider>(),
    settings: context.read<SettingsProvider>(),
  );
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _xp.addListener(_onChange);
    _xp.greet();
    if (widget.initialQuestion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _xp.send(widget.initialQuestion!));
    }
  }

  void _onChange() {
    if (_xp.messages.length != _lastCount) {
      _lastCount = _xp.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      });
    }
  }

  @override
  void dispose() {
    _xp.removeListener(_onChange);
    _xp.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final t = text ?? _input.text;
    if (t.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    _input.clear();
    _xp.send(t);
  }

  Future<void> _mic() async {
    HapticFeedback.mediumImpact();
    final problem = await _xp.toggleListening();
    if (problem != null && mounted) showToast(context, problem);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Theme(
      // xp always lives in the dark aurora, whatever the app theme
      data: AppThemeDark.of(context),
      child: Builder(builder: (context) {
        return Scaffold(
          backgroundColor: AppColors.darkBg,
          body: ListenableBuilder(
            listenable: _xp,
            builder: (context, _) {
              final messages = _xp.messages.reversed.toList();
              final last = _xp.messages.isEmpty ? null : _xp.messages.last;
              final suggestions = !_xp.busy && last != null && !last.fromUser ? last.suggestions : const <String>[];
              return Stack(
                children: [
                  const Positioned.fill(child: _AuroraBackground()),
                  SafeArea(
                    child: Column(
                      children: [
                        _TopBar(
                          mood: _xp.mood,
                          level: _xp.level,
                          voiceOn: settings.xpVoice,
                          onVoice: () {
                            final mute = settings.xpVoice;
                            settings.setXpVoice(!mute);
                            if (mute) _xp.stopSpeaking();
                          },
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount: messages.length + (_xp.busy ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (_xp.busy && i == 0) return const _Typing();
                              final m = messages[_xp.busy ? i - 1 : i];
                              return _Bubble(message: m).animate().fadeIn(duration: 250.ms).slideY(begin: 0.15, curve: Curves.easeOutCubic);
                            },
                          ),
                        ),
                        if (_xp.listening)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Text(
                              _xp.liveWords.isEmpty ? 'Listening…' : _xp.liveWords,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                          ),
                        if (suggestions.isNotEmpty && !_xp.listening)
                          SizedBox(
                            height: 44,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                for (final s in suggestions)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Pressable(
                                      onTap: () => _send(s),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                        ),
                                        child: Text(s, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        _InputBar(controller: _input, listening: _xp.listening, onSend: _send, onMic: _mic),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }),
    );
  }
}

/// Dark theme for the xp screen regardless of app setting.
class AppThemeDark {
  static ThemeData of(BuildContext context) => context.isDark ? Theme.of(context) : AppTheme.dark();
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.mood, required this.level, required this.voiceOn, required this.onVoice});
  final OrbMood mood;
  final double level;
  final bool voiceOn;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final status = switch (mood) {
      OrbMood.listening => 'Listening',
      OrbMood.thinking => 'Thinking',
      OrbMood.speaking => 'Speaking',
      OrbMood.idle => 'Your money buddy',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30), tooltip: 'Close'),
          const Spacer(),
          Column(
            children: [
              XpOrb(size: 76, mood: mood, level: level),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (r) => AppColors.xpGradient.createShader(r),
                child: const Text('xp', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(status, key: ValueKey(status), style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onVoice,
            tooltip: voiceOn ? 'Mute xp' : 'Let xp speak',
            icon: Icon(voiceOn ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final XpMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            gradient: user ? AppColors.heroGradient : null,
            color: user ? null : Colors.white.withValues(alpha: 0.08),
            border: user ? null : Border.all(color: Colors.white.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(user ? 22 : 6),
              bottomRight: Radius.circular(user ? 6 : 22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(message.text, style: const TextStyle(color: Colors.white, height: 1.4, fontSize: 15)),
              for (final card in message.cards) ...[const SizedBox(height: 10), _XpCardView(card)],
              if (message.viaCloud)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_rounded, size: 12, color: Colors.white38),
                    SizedBox(width: 4),
                    Text('cloud brain', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _XpCardView extends StatelessWidget {
  const _XpCardView(this.card);
  final XpCard card;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(16));
    return switch (card) {
      XpTxnCard(:final txn) => Container(decoration: decoration, padding: const EdgeInsets.symmetric(horizontal: 4), child: TxnTile(txn, showDate: true, dense: true)),
      XpTxnListCard(:final txns) => Container(
          decoration: decoration,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(children: [for (final t in txns) TxnTile(t, showDate: true, dense: true)]),
        ),
      XpBreakdownCard(:final title, :final rows, :final total, :final categories) => Container(
          decoration: decoration,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 8),
              for (final r in rows.take(8)) _BarRow(row: r, max: rows.map((e) => e.value).fold(0.0, (a, b) => a > b ? a : b), total: total, category: categories),
            ],
          ),
        ),
    };
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.row, required this.max, required this.total, required this.category});
  final MapEntry<String, double> row;
  final double max;
  final double total;
  final bool category;

  @override
  Widget build(BuildContext context) {
    final color = category ? categoryInfo(row.key).color : AppColors.primary;
    final ratio = max <= 0 ? 0.0 : row.value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 82, child: Text(row.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: v.clamp(0.02, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: category ? null : AppColors.xpGradient,
                      color: category ? color : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(moneyCompact(row.value), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(22)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle),
              ).animate(onPlay: (c) => c.repeat()).fadeOut(duration: 500.ms, delay: (i * 150).ms).then().fadeIn(duration: 500.ms),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.listening, required this.onSend, required this.onMic});
  final TextEditingController controller;
  final bool listening;
  final void Function([String?]) onSend;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white),
              minLines: 1,
              maxLines: 4,
              // plain text keyboard so Enter sends instead of adding a new line
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Ask or tell xp anything…',
                hintStyle: const TextStyle(color: Colors.white38),
                fillColor: Colors.white.withValues(alpha: 0.08),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, v, _) => v.text.trim().isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(onPressed: onSend, icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white), tooltip: 'Send'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: listening ? 'Stop listening' : 'Talk to xp',
            child: Pressable(
              onTap: onMic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: listening ? null : AppColors.xpGradient,
                  color: listening ? AppColors.coral : null,
                  boxShadow: [BoxShadow(color: (listening ? AppColors.coral : AppColors.teal).withValues(alpha: 0.45), blurRadius: 18)],
                ),
                child: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraBackground extends StatefulWidget {
  const _AuroraBackground();

  @override
  State<_AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<_AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.8 + 1.6 * t, -1.1),
              radius: 1.3,
              colors: [const Color(0xFF22C55E).withValues(alpha: 0.35), const Color(0xFF14B8A6).withValues(alpha: 0.12), AppColors.darkBg],
              stops: const [0, 0.45, 1],
            ),
          ),
        );
      },
    );
  }
}
