import 'dart:math' as math;

import 'package:expense_tracker/core/config.dart';
import 'package:expense_tracker/core/theme.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/screens/auth_screen.dart';
import 'package:expense_tracker/screens/shell_screen.dart';
import 'package:expense_tracker/state/session_provider.dart';
import 'package:expense_tracker/widgets/logo_mark.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Animated logo intro. The logo assembles itself (tile pops in, coin ring draws,
/// bars grow, xp spark ignites), the name types in, and meanwhile the session is restored.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final session = context.read<SessionProvider>();
    await Future.wait([
      _intro.forward(),
      session.restore(),
    ]);
    if (!mounted) return;
    final next = session.status == SessionStatus.signedIn ? const ShellScreen() : const AuthScreen();
    Navigator.of(context).pushReplacement(fadeRoute(next));
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    super.dispose();
  }

  double _phase(double start, double end, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_intro.value - start) / (end - start)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoSize = math.min(size.width * 0.34, 140.0);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_intro, _ambient]),
        builder: (context, _) {
          final tile = _phase(0.0, 0.32, Curves.elasticOut);
          final glow = _phase(0.1, 0.6);
          return Stack(
            fit: StackFit.expand,
            children: [
              // drifting coloured light behind everything
              CustomPaint(painter: _AuroraPainter(_ambient.value, glow)),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: logoSize,
                      child: CustomPaint(
                        painter: LogoPainter(
                          tile: tile,
                          tileRotation: (1 - _phase(0.0, 0.32)) * -0.7,
                          ring: _phase(0.22, 0.52, Curves.easeInOutCubic),
                          bars: _phase(0.42, 0.66, Curves.linear),
                          spark: _phase(0.6, 0.78, Curves.linear),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _Wordmark(progress: _phase(0.6, 0.92, Curves.linear)),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: _phase(0.82, 1.0),
                      child: Text(
                        'Spend smart. Live better.',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 14, letterSpacing: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Letters rise and fade in one by one.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    const word = AppConfig.appName;
    final style = GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < word.length; i++)
          Builder(builder: (_) {
            final p = Curves.easeOutBack.transform(((progress * (word.length + 3) - i) / 4).clamp(0.0, 1.0));
            return Opacity(
              opacity: p.clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, (1 - p) * 18), child: Text(word[i], style: style)),
            );
          }),
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t, this.strength);
  final double t;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final a = t * 2 * math.pi;
    final blobs = [
      (const Color(0xFF22C55E), Offset(size.width * (0.3 + 0.1 * math.sin(a)), size.height * (0.38 + 0.05 * math.cos(a)))),
      (const Color(0xFF14B8A6), Offset(size.width * (0.72 + 0.08 * math.cos(a * 1.3)), size.height * (0.5 + 0.06 * math.sin(a)))),
      (const Color(0xFF00C896), Offset(size.width * (0.45 + 0.1 * math.cos(a)), size.height * (0.66 + 0.04 * math.sin(a * 0.7)))),
    ];
    for (final (color, center) in blobs) {
      final r = size.width * 0.6;
      canvas.drawCircle(
        center,
        r,
        Paint()..shader = RadialGradient(colors: [color.withValues(alpha: 0.28 * strength), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t || old.strength != strength;
}
