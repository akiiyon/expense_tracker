import 'dart:math' as math;

import 'package:expense_tracker/analytics/insights.dart';
import 'package:expense_tracker/core/format.dart';
import 'package:expense_tracker/core/theme.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:expense_tracker/screens/profile_screen.dart';
import 'package:expense_tracker/screens/shell_screen.dart';
import 'package:expense_tracker/screens/sms_review_screen.dart';
import 'package:expense_tracker/sms/sms_service.dart';
import 'package:expense_tracker/state/finance_provider.dart';
import 'package:expense_tracker/state/session_provider.dart';
import 'package:expense_tracker/widgets/add_txn_sheet.dart';
import 'package:expense_tracker/widgets/common.dart';
import 'package:expense_tracker/widgets/txn_tile.dart';
import 'package:expense_tracker/widgets/xp_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final user = context.watch<SessionProvider>().user;
    final sms = context.watch<SmsSync>();
    final pendingSms = sms.pending.length + sms.awaitingDetails.length;
    final unnamed = sms.awaitingDetails.length;
    final txns = finance.transactions;
    final now = DateTime.now();
    final month = DateRange.month(now);
    final insights = detectPatterns(txns, monthlyBudget: user?.monthlyBudget ?? 0, categoryBudgets: finance.budgets);

    var i = 0;
    Widget enter(Widget w) => w.animate(delay: (60 * i++).ms).fadeIn(duration: 380.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic);

    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton(
          heroTag: 'add-home',
          tooltip: 'Add transaction',
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onPressed: () => showTxnSheet(context),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await finance.load();
          if (context.mounted) await context.read<SmsSync>().sync();
        },
        child: CustomScrollView(
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
                sliver: SliverList.list(
                  children: [
                    enter(_Header(name: user?.firstName ?? '')),
                    const SizedBox(height: 18),
                    enter(_BalanceCard(
                      balance: finance.balance,
                      monthIn: earned(txns, month),
                      monthOut: spent(txns, month),
                      loading: finance.loading && !finance.loaded,
                    )),
                    if (finance.error != null && !finance.loaded) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: finance.error!, onRetry: finance.load),
                    ],
                    if (pendingSms > 0) ...[
                      const SizedBox(height: 14),
                      enter(_SmsBanner(count: pendingSms, unnamed: unnamed)),
                    ],
                    const SizedBox(height: 14),
                    enter(Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _BudgetCard(spent: spent(txns, month), budget: user?.monthlyBudget ?? 0)),
                        const SizedBox(width: 14),
                        Expanded(child: _TodayCard(today: spent(txns, DateRange.today(now)), avg: _dailyAverage(txns, now))),
                      ],
                    )),
                    const SizedBox(height: 14),
                    enter(_XpNudge(insight: insights.isEmpty ? null : insights.first, hasData: txns.isNotEmpty)),
                    const SizedBox(height: 14),
                    enter(_WeekStrip(txns: txns)),
                    const SizedBox(height: 10),
                    SectionHeader('Recent activity', action: txns.isEmpty ? null : 'See all', onAction: () => ShellScreen.goTo(context, 1)),
                    if (txns.isEmpty && finance.loaded)
                      EmptyState(
                        icon: Icons.savings_rounded,
                        title: 'A fresh start!',
                        message: 'Add your first expense, or just tell xp "spent 120 on chai".',
                        action: FilledButton.tonal(onPressed: () => showTxnSheet(context), child: const Text('Add expense')),
                      )
                    else
                      SoftCard(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Column(children: [for (final t in txns.take(6)) TxnTile(t, showDate: true)]),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _dailyAverage(List<Txn> txns, DateTime now) {
    final r = DateRange.lastDays(30, now);
    return spent(txns, r) / 30;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${greeting()},', style: context.text.bodyLarge?.copyWith(color: context.mutedText)),
              Text(name.isEmpty ? 'there' : name, style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Pressable(
          onTap: () => ShellScreen.goTo(context, 3),
          child: ProfileAvatar(name: name, size: 46),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.monthIn, required this.monthOut, required this.loading});
  final double balance;
  final double monthIn;
  final double monthOut;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: Stack(
        children: [
          // decorative coins
          Positioned(right: -40, top: -50, child: _Bubble(size: 170, opacity: 0.12)),
          Positioned(right: 40, bottom: -70, child: _Bubble(size: 130, opacity: 0.08)),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text('Wallet balance', style: context.text.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Pressable(
                      onTap: () => showTxnSheet(context, type: TxnType.income),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('Add money', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                loading
                    ? Container(height: 44, width: 180, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(duration: 1200.ms)
                    : AnimatedMoney(balance, style: context.text.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _FlowPill(icon: Icons.south_west_rounded, label: 'In this month', value: monthIn, color: AppColors.mint)),
                    const SizedBox(width: 10),
                    Expanded(child: _FlowPill(icon: Icons.north_east_rounded, label: 'Out this month', value: monthOut, color: const Color(0xFFFF9A9A))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: opacity), width: 22)),
      );
}

class _FlowPill extends StatelessWidget {
  const _FlowPill({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.25), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedMoney(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.spent, required this.budget});
  final double spent;
  final double budget;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysLeft = DateRange.month(now).end.difference(dayOf(now)).inDays;
    if (budget <= 0) {
      return SoftCard(
        onTap: () => editMonthlyBudget(context),
        child: SizedBox(
          height: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(radius: 18, backgroundColor: Color(0x22FFB547), child: Icon(Icons.flag_rounded, color: AppColors.amber, size: 20)),
              const Spacer(),
              Text('Set a budget', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text('xp will keep you on track', style: context.text.bodySmall?.copyWith(color: context.mutedText)),
            ],
          ),
        ),
      );
    }
    final used = (spent / budget).clamp(0.0, 1.0);
    final over = spent > budget;
    final color = over ? AppColors.coral : (used > 0.8 ? AppColors.amber : AppColors.mint);
    return SoftCard(
      onTap: () => editMonthlyBudget(context),
      child: SizedBox(
        height: 120,
        child: Row(
          children: [
            SizedBox.square(
              dimension: 62,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: used),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => CustomPaint(
                  painter: _RingPainter(v, color, context.isDark ? Colors.white10 : const Color(0xFFE3EEE6)),
                  child: Center(child: Text('${(v * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(over ? 'Over by' : 'Left', style: context.text.bodySmall?.copyWith(color: context.mutedText)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(money((budget - spent).abs()), style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: over ? AppColors.coral : null)),
                  ),
                  Text('$daysLeft days to go', style: context.text.bodySmall?.copyWith(color: context.mutedText)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track);
  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(4), 0, 2 * math.pi, false, stroke..color = track);
    canvas.drawArc(rect.deflate(4), -math.pi / 2, 2 * math.pi * value, false, stroke..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today, required this.avg});
  final double today;
  final double avg;

  @override
  Widget build(BuildContext context) {
    final String mood;
    if (today == 0) {
      mood = 'No spend day so far 🌱';
    } else if (avg > 0 && today > avg * 1.5) {
      mood = 'Busier than usual';
    } else if (avg > 0 && today < avg * 0.6) {
      mood = 'Lighter than usual';
    } else {
      mood = 'About your usual';
    }
    return SoftCard(
      child: SizedBox(
        height: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(radius: 18, backgroundColor: Color(0x2216A34A), child: Icon(Icons.today_rounded, color: AppColors.primary, size: 20)),
            const Spacer(),
            Text('Today', style: context.text.bodySmall?.copyWith(color: context.mutedText)),
            FittedBox(fit: BoxFit.scaleDown, child: AnimatedMoney(today, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            Text(mood, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: context.mutedText)),
          ],
        ),
      ),
    );
  }
}

class _XpNudge extends StatelessWidget {
  const _XpNudge({required this.insight, required this.hasData});
  final Insight? insight;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final title = insight?.title ?? (hasData ? 'Ask me anything' : 'Hi, I\'m xp!');
    final body = insight?.body ??
        (hasData ? 'Try "how much did I spend on food this month?"' : 'Just tell me what you spent. Typing or talking, both work.');
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: AppColors.xpGradient),
      padding: const EdgeInsets.all(1.6),
      child: SoftCard(
        onTap: () => openXp(context, ask: insight == null ? null : 'Tell me more about my spending patterns'),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const XpOrb(size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (r) => AppColors.xpGradient.createShader(r),
                        child: const Text('xp', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13)),
                      ),
                      const SizedBox(width: 6),
                      Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: context.mutedText, height: 1.35)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends StatefulWidget {
  const _WeekStrip({required this.txns});
  final List<Txn> txns;

  @override
  State<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<_WeekStrip> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final days = byDay(widget.txns, DateRange.lastDays(7));
    final maxV = days.map((d) => d.value).fold(0.0, math.max);
    final selected = _selected ?? days.length - 1;
    final pick = days[selected];

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Last 7 days', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  '${friendlyDay(pick.key)} · ${money(pick.value)}',
                  key: ValueKey(selected),
                  style: context.text.bodySmall?.copyWith(color: context.mutedText, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selected = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: maxV == 0 ? 0.04 : math.max(days[i].value / maxV, 0.04)),
                            duration: Duration(milliseconds: 600 + i * 70),
                            curve: Curves.easeOutBack,
                            builder: (context, v, _) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 80 * v.clamp(0.0, 1.1),
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: i == selected ? AppColors.xpGradient : null,
                                color: i == selected ? null : AppColors.primary.withValues(alpha: context.isDark ? 0.3 : 0.15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat.E().format(days[i].key).substring(0, 1),
                            style: TextStyle(fontSize: 12, fontWeight: i == selected ? FontWeight.w800 : FontWeight.w600, color: i == selected ? null : context.mutedText),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmsBanner extends StatelessWidget {
  const _SmsBanner({required this.count, required this.unnamed});
  final int count;
  final int unnamed;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.primary.withValues(alpha: 0.1),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SmsReviewScreen())),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.sms_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              unnamed > 0
                  ? '$unnamed ${unnamed == 1 ? 'payment needs' : 'payments need'} a name'
                  : '$count ${count == 1 ? 'payment' : 'payments'} found in your SMS',
              style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Text('Review', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.coral.withValues(alpha: 0.1),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.coral),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
