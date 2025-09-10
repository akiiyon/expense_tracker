import 'package:expense_tracker/screens/profile_screen.dart';
import 'package:expense_tracker/screens/report_screen.dart';
import 'package:expense_tracker/screens/transaction_screen.dart';
import 'package:flutter/material.dart';

class SkeletonScreen extends StatefulWidget {
  @override
  State<SkeletonScreen> createState() => _SkeletonScreenState();
}

class _SkeletonScreenState extends State<SkeletonScreen> {
  //selectedScreenIndex
  int _selectedScreen=0;

  //list of all screens
  List<Widget> _screens=[TransactionScreen(),ReportScreen(),ProfileScreen()];

  void onTapped(int presentScreenIndex){
    setState(() {
      _selectedScreen=presentScreenIndex;
    });
    
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //body changes as per selectedScreen
      body: _screens.elementAt(_selectedScreen),
      //bottom navigation
      bottomNavigationBar: BottomNavigationBar(
        //navigation bar items will represent our screens, they switch the body of our app on tap! 
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home),label: "home"),
          BottomNavigationBarItem(icon: Icon(Icons.report),label:"report"),
          BottomNavigationBarItem(icon: Icon(Icons.people),label: "profile"),
        ],
        currentIndex: _selectedScreen,
        selectedItemColor: Colors.green,
        onTap: onTapped,),
      

    );

  }
}