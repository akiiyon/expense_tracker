import 'package:expense_tracker/utils/route.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.signin);
        },
        child: const Text("ProfileScreen"),
      ),
    );
  }
}
