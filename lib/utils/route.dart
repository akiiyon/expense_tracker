import 'package:expense_tracker/screens/detail_screen.dart';
import 'package:expense_tracker/screens/signUp_screen.dart';
import 'package:expense_tracker/screens/signin_screen.dart';
import 'package:expense_tracker/screens/skeleton_screen.dart';
import 'package:flutter/material.dart';

class AppRoutes {
  static const String signin='/signIn';
  static const String signup='/signUp';
  static const String skeleton='/skeleton';
  static const String details='/details';

  Map<String,WidgetBuilder> routes={
    signin:(context)=> SigninScreen(),
    signup:(context)=> SignupScreen(),
    skeleton:(context)=> SkeletonScreen(),
    details:(context)=> DetailScreen(),
  };


}