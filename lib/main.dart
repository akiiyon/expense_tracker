import 'package:expense_tracker/model/expense_provider.dart';
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
    return ChangeNotifierProvider(
      create: (context) => ExpenseProvider(),
      child: MaterialApp(
        title: "Expense Tracker",
        // home: SignupScreen(),
        initialRoute: AppRoutes.signin,
        routes: AppRoutes().routes,
      ),
    );
  }
}
