import 'package:expense_tracker/core/categories.dart';
import 'package:expense_tracker/core/format.dart';
import 'package:expense_tracker/core/theme.dart';
import 'package:expense_tracker/data/api_client.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:expense_tracker/sms/sms_parser.dart';
import 'package:expense_tracker/sms/sms_service.dart';
import 'package:expense_tracker/widgets/add_txn_sheet.dart';
import 'package:expense_tracker/widgets/xp_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Asks what an SMS-detected payment was for. Returns true when it was saved or skipped,
/// null when the sheet was just closed (it stays in the "needs details" list).
Future<bool?> showSmsDetailsSheet(BuildContext context, DetectedTxn txn) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SmsDetailsSheet(txn: txn),
  );
}

class SmsDetailsSheet extends StatefulWidget {
  const SmsDetailsSheet({super.key, required this.txn});
  final DetectedTxn txn;

  @override
  State<SmsDetailsSheet> createState() => _SmsDetailsSheetState();
}

class _SmsDetailsSheetState extends State<SmsDetailsSheet> {
  late final _name = TextEditingController(text: genericMerchants.contains(widget.txn.merchant) ? '' : widget.txn.merchant);
  late String? _category = widget.txn.category == 'Other' ? null : widget.txn.category;
  bool _picked = false;
  bool _saving = false;

  bool get _income => widget.txn.type == TxnType.income;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {
          if (_picked) return;
          final guess = guessCategory(_name.text, income: _income);
          if (guess != null) _category = guess;
        }));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool skip}) async {
    final sms = context.read<SmsSync>();
    setState(() => _saving = true);
    try {
      if (skip) {
        await sms.skipDetails(widget.txn);
      } else {
        final title = _name.text.trim();
        await sms.saveDetails(
          widget.txn,
          title: title.isEmpty ? (_category ?? widget.txn.merchant) : title[0].toUpperCase() + title.substring(1),
          category: _category ?? 'Other',
        );
      }
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.txn;
    final accent = _income ? AppColors.mint : AppColors.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const XpOrb(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_income ? 'Money came in!' : 'New payment spotted', style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text('Your SMS didn\'t say what this was for. Help me out?', style: context.text.bodySmall?.copyWith(color: context.mutedText)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                '${_income ? '+' : '−'}${money(t.amount)}',
                style: context.text.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: accent),
              ),
            ),
            Center(
              child: Text(
                '${genericMerchants.contains(t.merchant) ? (_income ? 'Received' : 'Paid') : '${_income ? 'From' : 'To'} ${t.merchant}'} · ${friendlyDay(t.date)}, ${DateFormat.jm().format(t.date)}',
                style: context.text.bodyMedium?.copyWith(color: context.mutedText),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
              child: Text(t.rawBody, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: context.mutedText)),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              autofocus: _name.text.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _income ? 'What was it? e.g. Rent share from Rahul' : 'What was it for? e.g. Lunch, Medicines',
                prefixIcon: const Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Text('Category', style: context.text.labelLarge?.copyWith(color: context.mutedText, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _income ? incomeCategories : expenseCategories)
                  CategoryChip(
                    info: c,
                    selected: _category == c.name,
                    onTap: () => setState(() {
                      _category = c.name;
                      _picked = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent),
              onPressed: _saving || (_category == null && _name.text.trim().isEmpty) ? null : () => _finish(skip: false),
              child: _saving
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Save'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _saving ? null : () => _finish(skip: true),
              child: Text('Skip, add as "${t.merchant}"', style: TextStyle(color: context.mutedText)),
            ),
          ],
        ),
      ),
    );
  }
}
