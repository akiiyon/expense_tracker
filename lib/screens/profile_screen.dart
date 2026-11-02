import 'package:expense_tracker/core/categories.dart';
import 'package:expense_tracker/core/config.dart';
import 'package:expense_tracker/core/format.dart';
import 'package:expense_tracker/core/theme.dart';
import 'package:expense_tracker/data/api_client.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/screens/auth_screen.dart';
import 'package:expense_tracker/screens/sms_review_screen.dart';
import 'package:expense_tracker/sms/sms_service.dart';
import 'package:expense_tracker/state/finance_provider.dart';
import 'package:expense_tracker/state/session_provider.dart';
import 'package:expense_tracker/state/settings_provider.dart';
import 'package:expense_tracker/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionProvider>().user;
    final finance = context.watch<FinanceProvider>();
    final settings = context.watch<SettingsProvider>();
    final sms = context.watch<SmsSync>();
    final txns = finance.transactions;
    final months = txns.isEmpty ? 0 : txns.map((t) => t.date.year * 12 + t.date.month).toSet().length;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 140),
        children: [
          Center(child: ProfileAvatar(name: user?.name ?? '', size: 86)),
          const SizedBox(height: 12),
          Center(child: Text(user?.name ?? '', style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          Center(child: Text(user?.email ?? '', style: context.text.bodyMedium?.copyWith(color: context.mutedText))),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _StatTile(value: '${txns.length}', label: 'Transactions')),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(value: '$months', label: months == 1 ? 'Month tracked' : 'Months tracked')),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(value: '${txns.where((t) => t.source != 'manual').length}', label: 'Auto-logged')),
            ],
          ),
          const SectionHeader('Budgets'),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _Row(
                  icon: Icons.flag_rounded,
                  color: AppColors.amber,
                  title: 'Monthly budget',
                  subtitle: (user?.monthlyBudget ?? 0) > 0 ? money(user!.monthlyBudget) : 'Not set',
                  onTap: () => editMonthlyBudget(context),
                ),
                _Row(
                  icon: Icons.donut_small_rounded,
                  color: AppColors.teal,
                  title: 'Category budgets',
                  subtitle: finance.budgets.isEmpty ? 'Cap what you spend per category' : '${finance.budgets.length} set',
                  onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const _CategoryBudgetSheet()),
                ),
              ],
            ),
          ),
          const SectionHeader('Smart features'),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                if (SmsSync.supported) ...[
                  _SwitchRow(
                    icon: Icons.sms_rounded,
                    color: AppColors.primary,
                    title: 'Detect payments from SMS',
                    subtitle: 'Reads bank & UPI messages on this phone',
                    value: settings.smsEnabled,
                    onChanged: (v) => _toggleSms(context, v),
                  ),
                  if (settings.smsEnabled) ...[
                    _SwitchRow(
                      icon: Icons.bolt_rounded,
                      color: AppColors.mint,
                      title: 'Add automatically',
                      subtitle: settings.smsAutoAdd ? 'Detected payments are added right away' : 'You review each one first',
                      value: settings.smsAutoAdd,
                      onChanged: settings.setSmsAutoAdd,
                    ),
                    _Row(
                      icon: Icons.fact_check_rounded,
                      color: AppColors.primary,
                      title: 'Review detected payments',
                      subtitle: sms.pending.isEmpty ? 'All caught up' : '${sms.pending.length} waiting',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SmsReviewScreen())),
                    ),
                  ],
                ],
                _SwitchRow(
                  icon: Icons.record_voice_over_rounded,
                  color: AppColors.teal,
                  title: 'xp speaks replies',
                  subtitle: 'Hear xp\'s answers out loud',
                  value: settings.xpVoice,
                  onChanged: settings.setXpVoice,
                ),
              ],
            ),
          ),
          const SectionHeader('Appearance'),
          SoftCard(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.brightness_auto_rounded)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: {settings.themeMode},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                side: BorderSide.none,
                selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.15),
                selectedForegroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
          ),
          const SectionHeader('Account'),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _Row(icon: Icons.edit_rounded, color: AppColors.primary, title: 'Edit name', onTap: () => _editName(context)),
                _Row(
                  icon: Icons.privacy_tip_rounded,
                  color: AppColors.mint,
                  title: 'Privacy policy',
                  subtitle: AppConfig.privacyPolicyUrl,
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: AppConfig.privacyPolicyUrl));
                    showToast(context, 'Link copied');
                  },
                ),
                _Row(icon: Icons.logout_rounded, color: AppColors.amber, title: 'Sign out', onTap: () => _signOut(context)),
                _Row(icon: Icons.delete_forever_rounded, color: AppColors.coral, title: 'Delete account', subtitle: 'Removes all your data', onTap: () => _deleteAccount(context)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(child: Text('${AppConfig.appName} · v1.0.0', style: context.text.bodySmall?.copyWith(color: context.mutedText))),
        ],
      ),
    );
  }

  Future<void> _toggleSms(BuildContext context, bool on) async {
    final settings = context.read<SettingsProvider>();
    final sms = context.read<SmsSync>();
    if (!on) {
      await settings.setSmsEnabled(false);
      await sms.stop();
      return;
    }
    final agreed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Let xp read payment SMS?'),
        content: const Text(
          'xp will look for bank, card and UPI messages (like "Rs 250 debited") on this phone and turn them into transactions.\n\n'
          'Only the amount, merchant and date are saved to your account. OTPs and personal messages are ignored and never leave your phone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), child: const Text('Allow')),
        ],
      ),
    );
    if (agreed != true || !context.mounted) return;
    if (!await sms.requestPermission()) {
      if (context.mounted) {
        showToast(context, 'SMS permission is needed for this', actionLabel: 'Settings', onAction: openAppSettings);
      }
      return;
    }
    await settings.setSmsEnabled(true);
    await sms.start();
    if (context.mounted) {
      final n = sms.takeLastAddedCount();
      showToast(context, n > 0 ? 'Found $n payments from the last 30 days' : sms.pending.isNotEmpty ? '${sms.pending.length} payments ready to review' : 'All set! New payments will show up automatically');
    }
  }

  Future<void> _editName(BuildContext context) async {
    final session = context.read<SessionProvider>();
    final name = await promptText(context, title: 'Your name', initial: session.user?.name ?? '');
    if (name == null || name.trim().length < 2) return;
    try {
      await session.updateProfile(name: name.trim());
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final session = context.read<SessionProvider>();
    final finance = context.read<FinanceProvider>();
    await session.signOut();
    finance.clear();
    if (context.mounted) Navigator.of(context).pushAndRemoveUntil(fadeRoute(const AuthScreen()), (_) => false);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text('This permanently deletes your account and every transaction. It can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), style: TextButton.styleFrom(foregroundColor: AppColors.coral), child: const Text('Delete forever')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final session = context.read<SessionProvider>();
    final finance = context.read<FinanceProvider>();
    try {
      await session.deleteAccount();
      finance.clear();
      if (context.mounted) Navigator.of(context).pushAndRemoveUntil(fadeRoute(const AuthScreen()), (_) => false);
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.name, this.size = 44});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.xpGradient),
      child: Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [
          Text(value, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, textAlign: TextAlign.center, style: context.text.bodySmall?.copyWith(color: context.mutedText)),
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.color, required this.title, this.subtitle, this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.mutedText)),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.color, required this.title, required this.subtitle, required this.value, required this.onChanged});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: TextStyle(color: context.mutedText)),
      );
}

/// Asks for a single line of text. Returns null when cancelled.
Future<String?> promptText(BuildContext context, {required String title, String initial = '', bool number = false, String? hint}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}(\.\d{0,2})?'))] : null,
        decoration: InputDecoration(hintText: hint, prefixText: number ? '₹ ' : null),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Save')),
      ],
    ),
  );
}

Future<void> editMonthlyBudget(BuildContext context) async {
  final session = context.read<SessionProvider>();
  final current = session.user?.monthlyBudget ?? 0;
  final value = await promptText(
    context,
    title: 'Monthly budget',
    initial: current > 0 ? current.toStringAsFixed(0) : '',
    number: true,
    hint: 'e.g. 25000 (0 to remove)',
  );
  if (value == null) return;
  final amount = double.tryParse(value) ?? 0;
  try {
    await session.updateProfile(monthlyBudget: amount);
    if (context.mounted) showToast(context, amount > 0 ? 'Budget set to ${money(amount)}. xp has your back!' : 'Budget removed');
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message);
  }
}

class _CategoryBudgetSheet extends StatelessWidget {
  const _CategoryBudgetSheet();

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Text('Category budgets', style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          for (final c in expenseCategories)
            ListTile(
              leading: CategoryAvatar(c.name, size: 38),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: Text(
                finance.budgets[c.name] == null ? 'Set' : money(finance.budgets[c.name]!),
                style: TextStyle(fontWeight: FontWeight.w800, color: finance.budgets[c.name] == null ? AppColors.primary : null),
              ),
              onTap: () async {
                final v = await promptText(
                  context,
                  title: '${c.name} budget',
                  initial: finance.budgets[c.name]?.toStringAsFixed(0) ?? '',
                  number: true,
                  hint: 'Monthly limit (0 to remove)',
                );
                if (v == null) return;
                try {
                  await finance.setBudget(c.name, double.tryParse(v) ?? 0);
                } on ApiException catch (e) {
                  if (context.mounted) showToast(context, e.message);
                }
              },
            ),
        ],
      ),
    );
  }
}
