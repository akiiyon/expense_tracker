import 'dart:math' as math;

import 'package:expense_tracker/analytics/insights.dart';
import 'package:expense_tracker/core/categories.dart';
import 'package:expense_tracker/core/format.dart';
import 'package:expense_tracker/core/theme.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:expense_tracker/screens/shell_screen.dart';
import 'package:expense_tracker/state/finance_provider.dart';
import 'package:expense_tracker/state/session_provider.dart';
import 'package:expense_tracker/widgets/common.dart';
import 'package:expense_tracker/widgets/txn_tile.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum _Period { week, month, year }

/// Interactive spending story: tap the donut, scrub the bars, swipe through patterns.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  _Period _period = _Period.month;
  int _offset = 0;
  String? _focusCategory;

  DateRange _range(DateTime now) => switch (_period) {
        _Period.week => DateRange.week(now, _offset),
        _Period.month => DateRange.month(now, _offset),
        _Period.year => DateRange.year(now, _offset),
      };

  String _rangeTitle(DateRange r) => switch (_period) {
        _Period.week => _offset == 0 ? 'This week' : _offset == -1 ? 'Last week' : '${DateFormat('d MMM').format(r.start)} – ${DateFormat('d MMM').format(r.end.subtract(const Duration(days: 1)))}',
        _Period.month => _offset == 0 ? 'This month' : DateFormat('MMMM yyyy').format(r.start),
        _Period.year => _offset == 0 ? 'This year' : '${r.start.year}',
      };

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final user = context.watch<SessionProvider>().user;
    final txns = finance.transactions;
    final now = DateTime.now();
    final range = _range(now);
    var previous = switch (_period) {
      _Period.week => DateRange.week(now, _offset - 1),
      _Period.month => DateRange.month(now, _offset - 1),
      _Period.year => DateRange.year(now, _offset - 1),
    };
    // a period still in progress is compared with the same stretch of the one before
    if (range.end.isAfter(now)) {
      final soFar = now.difference(range.start);
      previous = DateRange(previous.start, previous.start.add(soFar), previous.label);
    }
    final total = spent(txns, range);
    final before = spent(txns, previous);
    final cats = byCategory(txns, range);
    final patterns = detectPatterns(txns, monthlyBudget: user?.monthlyBudget ?? 0, categoryBudgets: finance.budgets);
    final elapsedDays = range.end.isAfter(now) ? math.max(1, dayOf(now).difference(range.start).inDays + 1) : range.days;

    var i = 0;
    Widget enter(Widget w) => w.animate(delay: (70 * i++).ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Insights'),
            backgroundColor: context.theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                tooltip: 'Ask xp',
                icon: ShaderMask(shaderCallback: (r) => AppColors.xpGradient.createShader(r), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white)),
                onPressed: () => openXp(context, ask: 'How can I save more?'),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
            sliver: SliverList.list(
              children: [
                _PeriodPicker(
                  period: _period,
                  onChanged: (p) => setState(() {
                    _period = p;
                    _offset = 0;
                    _focusCategory = null;
                  }),
                ),
                const SizedBox(height: 14),
                enter(_SummaryCard(
                  title: _rangeTitle(range),
                  total: total,
                  before: before,
                  perDay: total / elapsedDays,
                  canGoForward: _offset < 0,
                  onPrev: () => setState(() {
                    _offset--;
                    _focusCategory = null;
                  }),
                  onNext: () => setState(() {
                    _offset++;
                    _focusCategory = null;
                  }),
                )),
                const SizedBox(height: 14),
                if (total == 0)
                  const SoftCard(
                    child: EmptyState(icon: Icons.donut_large_rounded, title: 'No spending here', message: 'Nothing was spent in this period. Try another one!'),
                  )
                else ...[
                  enter(_DonutCard(
                    cats: cats,
                    total: total,
                    focus: _focusCategory,
                    onFocus: (c) => setState(() => _focusCategory = c == _focusCategory ? null : c),
                  )),
                  if (_focusCategory != null) ...[
                    const SizedBox(height: 14),
                    _CategoryDrilldown(category: _focusCategory!, txns: inRange(txns, range, type: TxnType.expense, category: _focusCategory).toList()),
                  ],
                  const SizedBox(height: 14),
                  enter(_BarsCard(period: _period, range: range, txns: txns, now: now)),
                ],
                const SizedBox(height: 14),
                enter(_TrendCard(txns: txns, now: now)),
                if (patterns.isNotEmpty) ...[
                  const SectionHeader('xp noticed'),
                  enter(_PatternCarousel(patterns: patterns)),
                ],
                if (finance.budgets.isNotEmpty) ...[
                  const SectionHeader('Category budgets'),
                  enter(_CategoryBudgets(txns: txns, budgets: finance.budgets)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.period, required this.onChanged});
  final _Period period;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / 3;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              left: w * period.index,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(12))),
            ),
            Row(
              children: [
                for (final p in _Period.values)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onChanged(p);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800, color: p == period ? Colors.white : context.mutedText),
                          child: Text(switch (p) { _Period.week => 'Week', _Period.month => 'Month', _Period.year => 'Year' }),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.total,
    required this.before,
    required this.perDay,
    required this.canGoForward,
    required this.onPrev,
    required this.onNext,
  });

  final String title;
  final double total;
  final double before;
  final double perDay;
  final bool canGoForward;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final change = before > 0 ? (total - before) / before * 100 : null;
    final down = change != null && change < 0;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 18),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Previous'),
              Expanded(child: Text(title, textAlign: TextAlign.center, style: context.text.titleSmall?.copyWith(color: context.mutedText, fontWeight: FontWeight.w700))),
              IconButton(onPressed: canGoForward ? onNext : null, icon: const Icon(Icons.chevron_right_rounded), tooltip: 'Next'),
            ],
          ),
          AnimatedMoney(total, style: context.text.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (change != null && change.abs() >= 1)
                _Pill(
                  icon: down ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                  text: '${change.abs().round()}% vs before',
                  color: down ? AppColors.mint : AppColors.coral,
                ),
              _Pill(icon: Icons.calendar_today_rounded, text: '${money(perDay.roundToDouble())} / day', color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );
}

class _DonutCard extends StatelessWidget {
  const _DonutCard({required this.cats, required this.total, required this.focus, required this.onFocus});
  final List<MapEntry<String, double>> cats;
  final double total;
  final String? focus;
  final ValueChanged<String> onFocus;

  @override
  Widget build(BuildContext context) {
    final focused = focus == null ? null : cats.where((c) => c.key == focus).firstOrNull;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where it went', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          Text('Tap a slice or a category to dig in', style: context.text.bodySmall?.copyWith(color: context.mutedText)),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, grow, _) => PieChart(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 62,
                      startDegreeOffset: -90 + (1 - grow) * -120,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (event is FlTapUpEvent) {
                            final i = response?.touchedSection?.touchedSectionIndex ?? -1;
                            if (i >= 0 && i < cats.length) {
                              HapticFeedback.selectionClick();
                              onFocus(cats[i].key);
                            }
                          }
                        },
                      ),
                      sections: [
                        for (final c in cats)
                          PieChartSectionData(
                            value: c.value,
                            color: categoryInfo(c.key).color.withValues(alpha: focus == null || focus == c.key ? 1 : 0.25),
                            radius: (focus == c.key ? 40 : 30) * grow,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey(focus),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (focused != null) Icon(categoryInfo(focused.key).icon, color: categoryInfo(focused.key).color),
                      Text(focused?.key ?? 'Total', style: context.text.bodySmall?.copyWith(color: context.mutedText, fontWeight: FontWeight.w700)),
                      SizedBox(
                        width: 104,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(money(focused?.value ?? total), style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      if (focused != null) Text('${(focused.value / total * 100).round()}%', style: context.text.bodySmall?.copyWith(color: context.mutedText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final c in cats.take(6))
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onFocus(c.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                child: Row(
                  children: [
                    CategoryAvatar(c.key, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(c.key, style: TextStyle(fontWeight: focus == c.key ? FontWeight.w800 : FontWeight.w600))),
                              Text(money(c.value), style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: c.value / cats.first.value),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) => LinearProgressIndicator(
                                value: v,
                                minHeight: 6,
                                color: categoryInfo(c.key).color,
                                backgroundColor: categoryInfo(c.key).color.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryDrilldown extends StatelessWidget {
  const _CategoryDrilldown({required this.category, required this.txns});
  final String category;
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    final top = [...txns]..sort((a, b) => b.amount.compareTo(a.amount));
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('Biggest in $category', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          for (final t in top.take(4)) TxnTile(t, showDate: true, dense: true),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.05);
  }
}

class _BarsCard extends StatefulWidget {
  const _BarsCard({required this.period, required this.range, required this.txns, required this.now});
  final _Period period;
  final DateRange range;
  final List<Txn> txns;
  final DateTime now;

  @override
  State<_BarsCard> createState() => _BarsCardState();
}

class _BarsCardState extends State<_BarsCard> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, double>> bars;
    final String title;
    if (widget.period == _Period.year) {
      title = 'Month by month';
      bars = [
        for (var m = 0; m < 12; m++)
          MapEntry(DateFormat.MMM().format(DateTime(widget.range.start.year, m + 1)).substring(0, 1),
              spent(widget.txns, DateRange.month(DateTime(widget.range.start.year, m + 1)))),
      ];
    } else {
      title = 'Day by day';
      bars = [
        for (final d in byDay(widget.txns, widget.range))
          MapEntry(widget.period == _Period.week ? DateFormat.E().format(d.key).substring(0, 2) : '${d.key.day}', d.value),
      ];
    }
    final maxV = bars.fold(0.0, (m, b) => math.max(m, b.value));
    final avg = bars.isEmpty ? 0.0 : bars.fold(0.0, (s, b) => s + b.value) / bars.length;
    final showEvery = bars.length > 14 ? 5 : 1;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('avg ${moneyCompact(avg)}', style: context.text.bodySmall?.copyWith(color: context.mutedText, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: BarChart(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              BarChartData(
                maxY: maxV == 0 ? 1 : maxV * 1.15,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxV == 0 ? 1 : maxV / 3,
                  getDrawingHorizontalLine: (_) => FlLine(color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  if (avg > 0) HorizontalLine(y: avg, color: AppColors.amber.withValues(alpha: 0.8), strokeWidth: 1.5, dashArray: [6, 4]),
                ]),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: maxV == 0 ? 1 : maxV / 3,
                      getTitlesWidget: (v, meta) => v == meta.max ? const SizedBox.shrink() : Text(moneyCompact(v), style: TextStyle(fontSize: 10, color: context.mutedText)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= bars.length || (i % showEvery != 0 && i != bars.length - 1)) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(bars[i].key, style: TextStyle(fontSize: 11, color: context.mutedText, fontWeight: i == _touched ? FontWeight.w800 : FontWeight.w500)),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchCallback: (event, response) {
                    final i = response?.spot?.touchedBarGroupIndex;
                    if (event.isInterestedForInteractions && i != null && i != _touched) {
                      HapticFeedback.selectionClick();
                      setState(() => _touched = i);
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.ink,
                    tooltipBorderRadius: BorderRadius.circular(10),
                    getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(money(rod.toY), const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < bars.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: bars[i].value,
                        width: bars.length > 20 ? 6 : 16,
                        borderRadius: BorderRadius.circular(6),
                        gradient: i == _touched || bars[i].value > avg * 1.5
                            ? const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF14B8A6), Color(0xFFFFB547)])
                            : const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF16A34A), Color(0xFF4ADE80)]),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.txns, required this.now});
  final List<Txn> txns;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final out = byMonth(txns, count: 6, now: now);
    final inc = byMonth(txns, count: 6, now: now, type: TxnType.income);
    final maxV = [...out, ...inc].fold(0.0, (m, e) => math.max(m, e.value));
    if (maxV == 0) return const SizedBox.shrink();

    LineChartBarData line(List<MapEntry<DateTime, double>> data, List<Color> colors) => LineChartBarData(
          spots: [for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i].value)],
          isCurved: true,
          preventCurveOverShooting: true,
          barWidth: 3.5,
          gradient: LinearGradient(colors: colors),
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(radius: 3.5, color: colors.last, strokeWidth: 2, strokeColor: context.cardColor),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.last.withValues(alpha: 0.25), colors.last.withValues(alpha: 0)],
            ),
          ),
        );

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('6 month trend', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              const _Legend(color: AppColors.coral, label: 'Spent'),
              const SizedBox(width: 12),
              const _Legend(color: AppColors.mint, label: 'Earned'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 170,
            child: LineChart(
              duration: const Duration(milliseconds: 600),
              LineChartData(
                minY: 0,
                maxY: maxV * 1.15,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(DateFormat.MMM().format(out[v.toInt()].key), style: TextStyle(fontSize: 11, color: context.mutedText)),
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.ink,
                    tooltipBorderRadius: BorderRadius.circular(10),
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem('${s.barIndex == 0 ? 'Spent' : 'Earned'} ${moneyCompact(s.y)}',
                            TextStyle(color: s.barIndex == 0 ? const Color(0xFFFF9A9A) : AppColors.mint, fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                ),
                lineBarsData: [
                  line(out, const [Color(0xFFFFB547), AppColors.coral]),
                  line(inc, const [Color(0xFF00BBF9), AppColors.mint]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: context.mutedText, fontWeight: FontWeight.w600)),
      ]);
}

class _PatternCarousel extends StatefulWidget {
  const _PatternCarousel({required this.patterns});
  final List<Insight> patterns;

  @override
  State<_PatternCarousel> createState() => _PatternCarouselState();
}

class _PatternCarouselState extends State<_PatternCarousel> {
  final _controller = PageController(viewportFraction: 0.88);
  int _page = 0;

  static const _gradients = [
    [Color(0xFF22C55E), Color(0xFF16A34A)],
    [Color(0xFF14B8A6), Color(0xFFFF8A4C)],
    [Color(0xFF00C896), Color(0xFF00BBF9)],
    [Color(0xFFFFB547), Color(0xFFFF6B6B)],
  ];

  static IconData _icon(InsightKind k) => switch (k) {
        InsightKind.weekend => Icons.weekend_rounded,
        InsightKind.payday => Icons.payments_rounded,
        InsightKind.peakDay => Icons.event_rounded,
        InsightKind.topCategory => Icons.emoji_events_rounded,
        InsightKind.rising => Icons.trending_up_rounded,
        InsightKind.smallSpends => Icons.coffee_rounded,
        InsightKind.lateNight => Icons.nightlight_round,
        InsightKind.subscriptions => Icons.autorenew_rounded,
        InsightKind.budgetPace => Icons.speed_rounded,
        InsightKind.budgetCategory => Icons.flag_rounded,
        InsightKind.saving => Icons.savings_rounded,
      };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.patterns.take(6).toList();
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: items.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (context, i) {
              final p = items[i];
              final g = p.positive ? _gradients[2] : _gradients[i % _gradients.length];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Pressable(
                  scale: 0.97,
                  onTap: () => openXp(context, ask: 'Tell me more about my spending patterns'),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                              child: Icon(_icon(p.kind), color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(p.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(p.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, height: 1.35)),
                        const Spacer(),
                        if (p.tip != null)
                          Text('💡 ${p.tip}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(color: i == _page ? AppColors.primary : AppColors.primary.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(3)),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryBudgets extends StatelessWidget {
  const _CategoryBudgets({required this.txns, required this.budgets});
  final List<Txn> txns;
  final Map<String, double> budgets;

  @override
  Widget build(BuildContext context) {
    final month = DateRange.month(DateTime.now());
    return SoftCard(
      child: Column(
        children: [
          for (final e in budgets.entries)
            Builder(builder: (context) {
              final used = spent(txns, month, category: e.key);
              final ratio = e.value <= 0 ? 0.0 : used / e.value;
              final color = ratio > 1 ? AppColors.coral : ratio > 0.8 ? AppColors.amber : AppColors.mint;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CategoryAvatar(e.key, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700))),
                            Text('${money(used)} / ${money(e.value)}', style: TextStyle(fontSize: 12, color: context.mutedText, fontWeight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: ratio.clamp(0, 1), minHeight: 7, color: color, backgroundColor: color.withValues(alpha: 0.15)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
