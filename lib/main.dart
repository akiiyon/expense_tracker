import 'package:expense_tracker/model/expense_provider.dart';
import 'package:expense_tracker/model/user_provider.dart';
import 'package:expense_tracker/screens/signUp_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'utils/route.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: "Expense Tracker",
        // home: SignupScreen(),
        initialRoute: AppRoutes.signup,
        routes: AppRoutes().routes,
      ),
    );
  }
}
