import 'package:flutter/material.dart';

abstract class Mainthemes {

  static final  ThemeData greenBackgroundTheme = ThemeData(
    scaffoldBackgroundColor: const Color.fromARGB(255, 34, 75, 68),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color.fromARGB(255, 34, 75, 68),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: const Color.fromARGB(255, 34, 75, 68),
      onPrimary:  Colors.white,
      secondary: Colors.white,
      onSecondary: const Color.fromARGB(255, 34, 75, 68),
      error: Colors.pink,
      onError: Colors.red,
      surface: const Color.fromARGB(255, 34, 75, 68),
      onSurface: Colors.white,
    ),
  );

  static final ThemeData blueBackgroundTheme = ThemeData(
    scaffoldBackgroundColor: const Color.fromARGB(255, 35, 68, 116),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color.fromARGB(255, 35, 68, 116),
      foregroundColor: Colors.white,
      elevation: 0,
    ),

    colorScheme: const ColorScheme(
      brightness: Brightness.dark,

      primary: Color.fromARGB(255, 35, 68, 116),
      onPrimary: Colors.white,

      secondary: Color(0xFF46D1C0), // teal
      onSecondary: Color.fromARGB(255, 35, 68, 116),

      error: Color(0xFF996AFF), // purple
      onError: Colors.white,

      surface: Color.fromARGB(255, 35, 68, 116),
      onSurface: Colors.white,
    ),
  );

  static final ThemeData whiteBackgroundTheme = ThemeData(
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color.fromARGB(255, 34, 75, 68),
      elevation: 0,
    ),
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: Colors.white,
      onPrimary:  Color.fromARGB(255, 34, 75, 68),
      secondary: const Color.fromARGB(255, 34, 75, 68),
      onSecondary: Colors.white,
      error: Colors.pink,
      onError: Colors.red,
      surface: Colors.white30,
      onSurface: const Color.fromARGB(255, 34, 75, 68),
    ),
  );
}