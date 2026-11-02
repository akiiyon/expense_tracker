import 'package:expense_tracker/core/format.dart';
import 'package:expense_tracker/core/theme.dart';
import 'package:expense_tracker/data/api_client.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:expense_tracker/state/finance_provider.dart';
import 'package:expense_tracker/widgets/add_txn_sheet.dart';
import 'package:expense_tracker/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TxnTile extends StatelessWidget {
  const TxnTile(this.txn, {super.key, this.showDate = false, this.dense = false});
  final Txn txn;
  final bool showDate;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      txn.category,
      if (showDate) friendlyDay(txn.date) else DateFormat.jm().format(txn.date),
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showTxnSheet(context, existing: txn),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 6 : 10),
        child: Row(
          children: [
            CategoryAvatar(txn.category, income: txn.isIncome, size: dense ? 38 : 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(txn.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      if (txn.source != 'manual') ...[const SizedBox(width: 6), _SourceBadge(txn.source)],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.text.bodySmall?.copyWith(color: context.mutedText)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${txn.isIncome ? '+' : '−'}${money(txn.amount)}',
              style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: txn.isIncome ? AppColors.mint : null),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge(this.source);
  final String source;

  @override
  Widget build(BuildContext context) {
    final sms = source == 'sms';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: sms ? null : AppColors.xpGradient,
        color: sms ? AppColors.primary.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(sms ? 'SMS' : 'xp', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: sms ? AppColors.primary : Colors.white)),
    );
  }
}

/// A transaction row you can swipe away, with undo.
class DismissibleTxnTile extends StatelessWidget {
  const DismissibleTxnTile(this.txn, {super.key, this.showDate = false});
  final Txn txn;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('txn-${txn.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.coral),
      ),
      onDismissed: (_) => deleteWithUndo(context, txn),
      child: TxnTile(txn, showDate: showDate),
    );
  }
}

Future<void> deleteWithUndo(BuildContext context, Txn txn) async {
  final finance = context.read<FinanceProvider>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await finance.remove(txn);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('Deleted ${txn.title}'),
      action: SnackBarAction(
        label: 'Undo',
        textColor: AppColors.amber,
        onPressed: () => finance.add(TxnDraft(
          type: txn.type,
          amount: txn.amount,
          category: txn.category,
          title: txn.title,
          note: txn.note,
          date: txn.date,
          source: txn.source,
        )),
      ),
    ));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
