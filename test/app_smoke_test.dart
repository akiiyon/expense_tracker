import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/screens/auth_screen.dart';
import 'package:expense_tracker/state/settings_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('splash plays, then shows sign in with validation', (tester) async {
    final settings = SettingsProvider();
    await settings.load();
    await tester.pumpWidget(ExpensifyApp(settings: settings));

    // splash animation runs ~2.3s, then routes to auth (no saved session)
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    // empty form shows validation errors instead of calling the server
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email'), findsOneWidget);

    // switch to sign up
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Your name'), findsOneWidget);
  });
}
