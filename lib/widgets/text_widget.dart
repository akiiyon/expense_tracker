import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MainTextWidget extends StatelessWidget {
  final String inputText;
  final double x;
  MainTextWidget({ required this.inputText, required this.x});

  @override
  Widget build(BuildContext context) {
    return Text(
      inputText,
      style: TextStyle(
        fontFamily: GoogleFonts.montserrat().fontFamily,
        color: Colors.green,
        fontSize: x,
        fontWeight: FontWeight.bold,
        ),
      );
  }
}

class SubTextWidget extends StatelessWidget {
  final String inputText;
  final double x;
  SubTextWidget({ required this.inputText, required this.x});

  @override
  Widget build(BuildContext context) {
    return Text(
      inputText,
      style: TextStyle(
        
        fontFamily: GoogleFonts.inter().fontFamily,
        color: Colors.grey.shade700,
        fontSize: x,
        
        ),
      );
  }
}