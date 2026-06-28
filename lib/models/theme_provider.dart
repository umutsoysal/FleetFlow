import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  day,
  night,
  redNight;

  static const _key = 'app_theme_mode';

  String get label {
    switch (this) {
      case day:
        return 'Day';
      case night:
        return 'Night';
      case redNight:
        return 'Red Night';
    }
  }

  IconData get icon {
    switch (this) {
      case day:
        return Icons.wb_sunny;
      case night:
        return Icons.dark_mode;
      case redNight:
        return Icons.nightlight;
    }
  }

  AppThemeMode get next {
    switch (this) {
      case day:
        return night;
      case night:
        return redNight;
      case redNight:
        return day;
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _mode;

  ThemeProvider({SharedPreferences? prefs})
      : _mode = AppThemeMode.values[prefs?.getInt(AppThemeMode._key) ?? 1];

  AppThemeMode get mode => _mode;

  set mode(AppThemeMode value) {
    _mode = value;
    notifyListeners();
    _save();
  }

  void cycle() {
    mode = _mode.next;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppThemeMode._key, _mode.index);
  }

  ThemeData get theme {
    switch (_mode) {
      case AppThemeMode.day:
        return _dayTheme;
      case AppThemeMode.night:
        return _nightTheme;
      case AppThemeMode.redNight:
        return _redNightTheme;
    }
  }

  // ── Day: high contrast for sunlight ────────────────────────────────────

  static final _dayTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF0D47A1),
      onPrimary: Colors.white,
      secondary: Color(0xFFE65100),
      surface: Color(0xFFF5F5F5),
      onSurface: Color(0xFF1A1A1A),
      surfaceContainerHighest: Color(0xFFE0E0E0),
      primaryContainer: Color(0xFFBBDEFB),
      onPrimaryContainer: Color(0xFF0D47A1),
      error: Color(0xFFC62828),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0D47A1),
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFBDBDBD), width: 0.5),
      ),
    ),
    textTheme: const TextTheme(
      titleSmall: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
      titleMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
      bodyMedium: TextStyle(color: Color(0xFF333333)),
      labelSmall: TextStyle(color: Color(0xFF616161)),
    ),
    dividerColor: const Color(0xFFBDBDBD),
  );

  // ── Night: current dark theme ──────────────────────────────────────────

  static final _nightTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0D47A1),
      brightness: Brightness.dark,
    ),
  );

  // ── Red Night: preserves night vision ──────────────────────────────────

  static final _redNightTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFCC3333),
      onPrimary: Color(0xFF1A0000),
      secondary: Color(0xFF992222),
      surface: Color(0xFF0A0000),
      onSurface: Color(0xFFCC4444),
      surfaceContainerHighest: Color(0xFF1A0505),
      primaryContainer: Color(0xFF330000),
      onPrimaryContainer: Color(0xFFCC4444),
      error: Color(0xFFFF4444),
    ),
    scaffoldBackgroundColor: const Color(0xFF050000),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF100000),
      foregroundColor: Color(0xFFCC4444),
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF0F0000),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF331111), width: 0.5),
      ),
    ),
    textTheme: const TextTheme(
      titleSmall: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCC4444)),
      titleMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCC4444)),
      bodyMedium: TextStyle(color: Color(0xFF993333)),
      labelSmall: TextStyle(color: Color(0xFF772222)),
    ),
    iconTheme: const IconThemeData(color: Color(0xFFCC3333)),
    dividerColor: const Color(0xFF331111),
  );
}
