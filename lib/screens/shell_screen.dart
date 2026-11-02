import 'package:expense_tracker/core/theme.dart';
import 'package:expense_tracker/screens/activity_screen.dart';
import 'package:expense_tracker/screens/home_screen.dart';
import 'package:expense_tracker/screens/insights_screen.dart';
import 'package:expense_tracker/screens/profile_screen.dart';
import 'package:expense_tracker/screens/xp_screen.dart';
import 'package:expense_tracker/sms/sms_service.dart';
import 'package:expense_tracker/state/finance_provider.dart';
import 'package:expense_tracker/state/session_provider.dart';
import 'package:expense_tracker/widgets/common.dart';
import 'package:expense_tracker/widgets/sms_details_sheet.dart';
import 'package:expense_tracker/widgets/xp_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Bottom navigation with xp's orb in the middle.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  /// Lets any screen switch tabs (e.g. "See all" on Home).
  static void goTo(BuildContext context, int tab) => context.findAncestorStateOfType<_ShellScreenState>()?._select(tab);

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> with WidgetsBindingObserver {
  int _tab = 0;
  final _visited = <int>{0};
  late final SmsSync _sms = context.read<SmsSync>();

  /// Payments the user closed the "what was it for?" sheet on. Not asked again this session.
  final _snoozed = <String>{};
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sms.addListener(_askForDetails);
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sms.removeListener(_askForDetails);
    super.dispose();
  }

  Future<void> _boot() async {
    final finance = context.read<FinanceProvider>();
    await finance.load();
    await _sms.init();
    _announceSms();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sms.sync().then((_) => _announceSms());
      context.read<SessionProvider>().refreshUser();
    }
  }

  /// Pops up the details sheet for an SMS payment we couldn't make sense of,
  /// one at a time, only when the user is on the main screens.
  Future<void> _askForDetails() async {
    if (_asking || !mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final next = _sms.awaitingDetails.where((t) => !_snoozed.contains(t.ref)).firstOrNull;
    if (next == null) return;
    _asking = true;
    HapticFeedback.mediumImpact();
    final done = await showSmsDetailsSheet(context, next);
    if (done != true) _snoozed.add(next.ref);
    _asking = false;
    if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _askForDetails());
  }

  void _announceSms() {
    if (!mounted) return;
    final n = context.read<SmsSync>().takeLastAddedCount();
    if (n > 0) showToast(context, 'xp added $n ${n == 1 ? 'transaction' : 'transactions'} from your SMS');
  }

  void _select(int tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  @override
  Widget build(BuildContext context) {
    // build tabs lazily, then keep them alive
    final pages = [const HomeScreen(), const ActivityScreen(), const InsightsScreen(), const ProfileScreen()];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [for (var i = 0; i < pages.length; i++) _visited.contains(i) ? pages[i] : const SizedBox.shrink()],
      ),
      bottomNavigationBar: _NavBar(current: _tab, onSelect: _select),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.current, required this.onSelect});
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 12),
      child: SizedBox(
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              height: 66,
              decoration: BoxDecoration(
                color: context.isDark ? AppColors.darkCard.withValues(alpha: 0.96) : Colors.white.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.08), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Row(
                children: [
                  _NavItem(icon: Icons.home_rounded, label: 'Home', selected: current == 0, onTap: () => onSelect(0)),
                  _NavItem(icon: Icons.receipt_long_rounded, label: 'Activity', selected: current == 1, onTap: () => onSelect(1)),
                  const SizedBox(width: 76),
                  _NavItem(icon: Icons.insights_rounded, label: 'Insights', selected: current == 2, onTap: () => onSelect(2)),
                  _NavItem(icon: Icons.person_rounded, label: 'Profile', selected: current == 3, onTap: () => onSelect(3)),
                ],
              ),
            ),
            Positioned(
              top: -22,
              child: Semantics(
                button: true,
                label: 'Talk to xp',
                child: Pressable(
                  onTap: () => openXp(context),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.isDark ? AppColors.darkBg : AppColors.lightBg,
                    ),
                    padding: const EdgeInsets.all(5),
                    child: const XpOrb(size: 60),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : context.mutedText;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.12 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: color),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens xp, optionally asking a question straight away.
Future<void> openXp(BuildContext context, {String? ask}) {
  return Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 500),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, __, ___) => XpScreen(initialQuestion: ask),
    transitionsBuilder: (_, a, __, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      // grows out of the orb at the bottom
      return FadeTransition(
        opacity: c,
        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(c), alignment: Alignment.bottomCenter, child: child),
      );
    },
  ));
}
