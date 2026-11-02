import 'package:expense_tracker/core/format.dart';
import 'package:expense_tracker/core/theme.dart';
import 'package:expense_tracker/data/api_client.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:expense_tracker/sms/sms_parser.dart';
import 'package:expense_tracker/sms/sms_service.dart';
import 'package:expense_tracker/widgets/common.dart';
import 'package:expense_tracker/widgets/sms_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Payments found in SMS that are waiting for the user's OK.
class SmsReviewScreen extends StatelessWidget {
  const SmsReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sms = context.watch<SmsSync>();
    final items = sms.pending;
    final unnamed = sms.awaitingDetails;

    Future<void> approve(List<DetectedTxn> list) async {
      try {
        await sms.approve(list);
        if (context.mounted) showToast(context, 'Added ${list.length} ${list.length == 1 ? 'transaction' : 'transactions'}');
      } on ApiException catch (e) {
        if (context.mounted) showToast(context, e.message);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detected payments'),
        actions: [
          IconButton(
            tooltip: 'Scan again',
            onPressed: sms.syncing ? null : sms.sync,
            icon: sms.syncing ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton.icon(
                onPressed: () => approve(items),
                icon: const Icon(Icons.done_all_rounded),
                label: Text('Add all ${items.length}'),
              ),
            ),
      body: items.isEmpty && unnamed.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.mark_email_read_rounded,
                title: 'All caught up',
                message: 'New bank and UPI payments will appear here for you to confirm.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              itemCount: items.length + unnamed.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i < unnamed.length) return _NeedsDetailsTile(txn: unnamed[i]);
                final t = items[i - unnamed.length];
                return Dismissible(
                  key: ValueKey(t.ref),
                  onDismissed: (_) => sms.dismiss(t),
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 24),
                    decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(24)),
                    child: const Icon(Icons.close_rounded, color: AppColors.coral),
                  ),
                  child: SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CategoryAvatar(t.category, income: t.type == TxnType.income, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.merchant, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('${t.category} · ${friendlyDay(t.date)}, ${DateFormat.jm().format(t.date)}',
                                      style: TextStyle(color: context.mutedText, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text(
                              '${t.type == TxnType.income ? '+' : '−'}${money(t.amount)}',
                              style: TextStyle(fontWeight: FontWeight.w800, color: t.type == TxnType.income ? AppColors.mint : null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(t.rawBody, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.mutedText)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => sms.dismiss(t), child: const Text('Ignore')),
                            const SizedBox(width: 4),
                            FilledButton.tonal(
                              onPressed: () => approve([t]),
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _NeedsDetailsTile extends StatelessWidget {
  const _NeedsDetailsTile({required this.txn});
  final DetectedTxn txn;

  @override
  Widget build(BuildContext context) {
    final income = txn.type == TxnType.income;
    return SoftCard(
      onTap: () => showSmsDetailsSheet(context, txn),
      color: AppColors.amber.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const CircleAvatar(radius: 20, backgroundColor: Color(0x33FFB547), child: Icon(Icons.help_outline_rounded, color: AppColors.amber)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What was this for?', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('${txn.merchant} · ${friendlyDay(txn.date)}', style: TextStyle(color: context.mutedText, fontSize: 12)),
              ],
            ),
          ),
          Text('${income ? '+' : '−'}${money(txn.amount)}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
