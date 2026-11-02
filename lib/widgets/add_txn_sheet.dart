import 'package:expense_tracker/core/categories.dart';
import 'package:expense_tracker/core/format.dart';
import 'package:expense_tracker/core/theme.dart';
import 'package:expense_tracker/data/api_client.dart';
import 'package:expense_tracker/data/models.dart';
import 'package:expense_tracker/state/finance_provider.dart';
import 'package:expense_tracker/widgets/common.dart';
import 'package:expense_tracker/widgets/txn_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Opens the add / edit transaction sheet. Returns true when something was saved.
Future<bool?> showTxnSheet(BuildContext context, {Txn? existing, TxnType type = TxnType.expense}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddTxnSheet(existing: existing, initialType: existing?.type ?? type),
  );
}

class AddTxnSheet extends StatefulWidget {
  const AddTxnSheet({super.key, this.existing, this.initialType = TxnType.expense});
  final Txn? existing;
  final TxnType initialType;

  @override
  State<AddTxnSheet> createState() => _AddTxnSheetState();
}

class _AddTxnSheetState extends State<AddTxnSheet> {
  late TxnType _type = widget.initialType;
  late final _amount = TextEditingController(text: widget.existing == null ? '' : _plain(widget.existing!.amount));
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String? _category = widget.existing?.category;
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  bool _categoryPicked = false;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;
  List<CategoryInfo> get _categories => _type == TxnType.income ? incomeCategories : expenseCategories;

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _categoryPicked = _category != null;
    _title.addListener(_suggestCategory);
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _suggestCategory() {
    if (_categoryPicked) return;
    final guess = guessCategory(_title.text, income: _type == TxnType.income);
    if (guess != null && guess != _category) setState(() => _category = guess);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = sameDay(picked, DateTime.now()) ? DateTime.now() : DateTime(picked.year, picked.month, picked.day, 12));
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    final category = _category ?? 'Other';
    final title = _title.text.trim().isEmpty ? category : _title.text.trim();
    final draft = TxnDraft(
      type: _type,
      amount: amount,
      category: category,
      title: title,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      date: _date,
      source: widget.existing?.source ?? 'manual',
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    final finance = context.read<FinanceProvider>();
    try {
      if (_editing) {
        await finance.update(widget.existing!, draft);
      } else {
        await finance.add(draft);
      }
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _type == TxnType.income ? AppColors.mint : AppColors.primary;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_editing ? 'Edit transaction' : 'New transaction', style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if (_editing)
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.coral),
                    onPressed: () {
                      // grabs the provider and messenger before the sheet closes
                      deleteWithUndo(context, widget.existing!);
                      Navigator.pop(context, true);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<TxnType>(
              segments: const [
                ButtonSegment(value: TxnType.expense, label: Text('Expense'), icon: Icon(Icons.north_east_rounded)),
                ButtonSegment(value: TxnType.income, label: Text('Income'), icon: Icon(Icons.south_west_rounded)),
              ],
              selected: {_type},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: accent.withValues(alpha: 0.15),
                selectedForegroundColor: accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _category = null;
                _categoryPicked = false;
                _suggestCategory();
              }),
            ),
            const SizedBox(height: 20),
            // big amount input
            Center(
              child: IntrinsicWidth(
                child: TextField(
                  controller: _amount,
                  autofocus: !_editing,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}(\.\d{0,2})?'))],
                  style: context.text.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: accent),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: context.text.headlineSmall?.copyWith(color: accent, fontWeight: FontWeight.w700),
                    hintText: '0',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _type == TxnType.income ? 'What was it? e.g. Salary' : 'What was it for? e.g. Lunch with team',
                prefixIcon: const Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 18),
            Text('Category', style: context.text.labelLarge?.copyWith(color: context.mutedText, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _categories)
                  CategoryChip(
                    info: c,
                    selected: _category == c.name,
                    onTap: () => setState(() {
                      _category = c.name;
                      _categoryPicked = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _DateChip(label: 'Today', selected: sameDay(_date, DateTime.now()), onTap: () => setState(() => _date = DateTime.now())),
                const SizedBox(width: 8),
                _DateChip(
                  label: 'Yesterday',
                  selected: sameDay(_date, DateTime.now().subtract(const Duration(days: 1))),
                  onTap: () {
                    final y = DateTime.now().subtract(const Duration(days: 1));
                    setState(() => _date = DateTime(y.year, y.month, y.day, 12));
                  },
                ),
                const SizedBox(width: 8),
                _DateChip(
                  icon: Icons.calendar_month_rounded,
                  label: sameDay(_date, DateTime.now()) || sameDay(_date, DateTime.now().subtract(const Duration(days: 1)))
                      ? 'Pick date'
                      : DateFormat('d MMM').format(_date),
                  selected: !sameDay(_date, DateTime.now()) && !sameDay(_date, DateTime.now().subtract(const Duration(days: 1))),
                  onTap: _pickDate,
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(hintText: 'Note (optional)', prefixIcon: Icon(Icons.sticky_note_2_outlined)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(_editing ? 'Save changes' : (_type == TxnType.income ? 'Add income' : 'Add expense')),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.info, required this.selected, required this.onTap});
  final CategoryInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? info.color : info.color.withValues(alpha: context.isDark ? 0.16 : 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(info.icon, size: 18, color: selected ? Colors.white : info.color),
            const SizedBox(width: 6),
            Text(info.name, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : null)),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : (context.isDark ? AppColors.darkCard : const Color(0xFFEBF3ED)),
          borderRadius: BorderRadius.circular(12),
          border: selected && context.isDark ? Border.all(color: AppColors.primary) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: selected ? Colors.white : null), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : null)),
          ],
        ),
      ),
    );
  }
}
