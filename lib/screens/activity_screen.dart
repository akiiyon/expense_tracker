import 'package:expense_tracker/analytics/insights.dart';
import 'package:expense_tracker/core/categories.dart';
import 'package:expense_tracker/core/format.dart';
import 'package:expense_tracker/core/theme.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:expense_tracker/state/finance_provider.dart';
import 'package:expense_tracker/widgets/add_txn_sheet.dart';
import 'package:expense_tracker/widgets/common.dart';
import 'package:expense_tracker/widgets/txn_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Every transaction, month by month, with search and filters.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _monthOffset = 0;
  TxnType? _type;
  String? _category;
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final month = DateRange.month(DateTime.now(), _monthOffset);
    final q = _query.toLowerCase();
    final list = finance.transactions.where((t) {
      if (q.isEmpty && !month.contains(t.date)) return false;
      if (_type != null && t.type != _type) return false;
      if (_category != null && t.category != _category) return false;
      if (q.isNotEmpty && !'${t.title} ${t.category} ${t.note ?? ''} ${t.amount}'.toLowerCase().contains(q)) return false;
      return true;
    }).toList();

    // group by day, newest first
    final groups = <DateTime, List<Txn>>{};
    for (final t in list) {
      groups.putIfAbsent(dayOf(t.date), () => []).add(t);
    }

    final monthTxns = finance.transactions.where((t) => month.contains(t.date));
    final inTotal = sumOf(monthTxns.where((t) => t.isIncome));
    final outTotal = sumOf(monthTxns.where((t) => t.isExpense));

    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: FloatingActionButton(
          heroTag: 'add-activity',
          tooltip: 'Add transaction',
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onPressed: () => showTxnSheet(context),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: finance.load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: const Text('Activity'),
              backgroundColor: context.theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search all transactions',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _query = '';
                                }),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_query.isEmpty)
                      _MonthSwitcher(
                        month: month,
                        canGoForward: _monthOffset < 0,
                        inTotal: inTotal,
                        outTotal: outTotal,
                        onPrev: () => setState(() => _monthOffset--),
                        onNext: () => setState(() => _monthOffset++),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _FilterChip(label: 'All', selected: _type == null && _category == null, onTap: () => setState(() {
                          _type = null;
                          _category = null;
                        })),
                    _FilterChip(label: 'Expenses', selected: _type == TxnType.expense, onTap: () => setState(() => _type = _type == TxnType.expense ? null : TxnType.expense)),
                    _FilterChip(label: 'Income', selected: _type == TxnType.income, onTap: () => setState(() => _type = _type == TxnType.income ? null : TxnType.income)),
                    for (final c in expenseCategories)
                      _FilterChip(
                        label: c.name,
                        icon: c.icon,
                        color: c.color,
                        selected: _category == c.name,
                        onTap: () => setState(() => _category = _category == c.name ? null : c.name),
                      ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (groups.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: _query.isNotEmpty ? Icons.search_off_rounded : Icons.receipt_long_rounded,
                  title: _query.isNotEmpty ? 'No matches' : 'Nothing here yet',
                  message: _query.isNotEmpty ? 'Try a different word or amount.' : 'Transactions for ${DateFormat('MMMM').format(month.start)} will show up here.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                sliver: SliverList.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, i) {
                    final day = groups.keys.elementAt(i);
                    final items = groups[day]!;
                    final dayOut = sumOf(items.where((t) => t.isExpense));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                          child: Row(
                            children: [
                              Text(friendlyDay(day), style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                              const Spacer(),
                              if (dayOut > 0) Text('−${money(dayOut)}', style: context.text.labelLarge?.copyWith(color: context.mutedText, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        SoftCard(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Column(children: [for (final t in items) DismissibleTxnTile(t, showDate: _query.isNotEmpty)]),
                        ),
                      ],
                    ).animate().fadeIn(duration: 250.ms, delay: (i.clamp(0, 8) * 30).ms);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.month,
    required this.canGoForward,
    required this.inTotal,
    required this.outTotal,
    required this.onPrev,
    required this.onNext,
  });

  final DateRange month;
  final bool canGoForward;
  final double inTotal;
  final double outTotal;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Previous month'),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    DateFormat('MMMM yyyy').format(month.start),
                    key: ValueKey(month.start),
                    textAlign: TextAlign.center,
                    style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              IconButton(onPressed: canGoForward ? onNext : null, icon: const Icon(Icons.chevron_right_rounded), tooltip: 'Next month'),
            ],
          ),
          Row(
            children: [
              Expanded(child: _Stat(label: 'Money in', value: inTotal, color: AppColors.mint)),
              Container(width: 1, height: 32, color: context.theme.dividerTheme.color),
              Expanded(child: _Stat(label: 'Money out', value: outTotal, color: AppColors.coral)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: context.text.bodySmall?.copyWith(color: context.mutedText)),
        const SizedBox(height: 2),
        AnimatedMoney(value, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.icon, this.color});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c : context.cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: selected ? Colors.white : c), const SizedBox(width: 6)],
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : null)),
            ],
          ),
        ),
      ),
    );
  }
}
