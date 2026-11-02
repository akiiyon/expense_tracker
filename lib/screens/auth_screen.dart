import 'package:expense_tracker/core/config.dart';
import 'package:expense_tracker/core/theme.dart';
import 'package:expense_tracker/data/api_client.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/screens/shell_screen.dart';
import 'package:expense_tracker/state/session_provider.dart';
import 'package:expense_tracker/widgets/logo_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

/// Sign in and sign up on one screen.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<SessionProvider>();
    try {
      if (_signUp) {
        await session.signUp(_name.text, _email.text, _password.text);
      } else {
        await session.signIn(_email.text, _password.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(const ShellScreen()), (_) => false);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // hero
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(28, top + 36, 28, 40),
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LogoMark(size: 56).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 26),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _signUp ? 'Let\'s get you\nstarted ✨' : 'Welcome\nback 👋',
                      key: ValueKey(_signUp),
                      style: context.text.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.1),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _signUp ? 'Track every rupee and meet xp, your AI money buddy.' : 'Your money story is waiting for you.',
                    style: context.text.bodyLarge?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Container(
              transform: Matrix4.translationValues(0, -24, 0),
              decoration: BoxDecoration(
                color: context.theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Form(
                key: _form,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_signUp) ...[
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(hintText: 'Your name', prefixIcon: Icon(Icons.person_outline_rounded)),
                          validator: (v) => (v ?? '').trim().length < 2 ? 'Please enter your name' : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                        validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        textInputAction: _signUp ? TextInputAction.next : TextInputAction.done,
                        autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                        onFieldSubmitted: (_) => _signUp ? null : _submit(),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        validator: (v) => (v ?? '').length < 6 ? 'At least 6 characters' : null,
                      ),
                      if (_signUp) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirm,
                          obscureText: !_showPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(hintText: 'Confirm password', prefixIcon: Icon(Icons.lock_reset_rounded)),
                          validator: (v) => v != _password.text ? 'Passwords don\'t match' : null,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.coral, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ).animate().shakeX(hz: 4, amount: 4, duration: 400.ms),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Text(_signUp ? 'Create account' : 'Sign in'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_signUp ? 'Already have an account?' : 'New to ${AppConfig.appName}?', style: TextStyle(color: context.mutedText)),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _signUp = !_signUp;
                                      _error = null;
                                    }),
                            child: Text(_signUp ? 'Sign in' : 'Create account', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}
