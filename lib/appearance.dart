import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'desktop_bridge.dart';

class Appearance extends ChangeNotifier {
  ThemeMode mode = ThemeMode.light;
  Future<void> load() async {
    try {
      final saved = isWindowsDesktop
          ? await desktopRequest('getTheme')
          : (await SharedPreferences.getInstance()).getString('appearance');
      mode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (_) {
      /* Keep a usable light theme if preferences cannot be read. */
    }
  }

  Future<void> setMode(ThemeMode value) async {
    final previous = mode;
    mode = value;
    notifyListeners();
    try {
      if (isWindowsDesktop) {
        await desktopRequest('setTheme', value.name);
      } else if (!await (await SharedPreferences.getInstance()).setString(
        'appearance',
        value.name,
      )) {
        throw StateError('Could not save appearance');
      }
    } catch (_) {
      mode = previous;
      notifyListeners();
      rethrow;
    }
  }
}

final appearance = Appearance();

class AppPalette {
  final bool dark;
  AppPalette(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;
  Color get background =>
      dark ? const Color(0xFF121A19) : const Color(0xFFF8F9FC);
  Color get surface => dark ? const Color(0xFF1B2523) : Colors.white;
  Color get raised => dark ? const Color(0xFF22312C) : const Color(0xFFF0F6F2);
  Color get text => dark ? const Color(0xFFE5EDE8) : const Color(0xFF252735);
  Color get muted => dark ? const Color(0xFFA0B0A8) : const Color(0xFF92939F);
  Color get border => dark ? const Color(0xFF32423B) : const Color(0xFFEEEFF3);
  Color get accent => dark ? const Color(0xFF7AD5B0) : const Color(0xFF32816A);
  Color get selected =>
      dark ? const Color(0xFF2B4439) : const Color(0xFFEAF3EE);
}

ThemeData trackVerseTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF32816A),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFF7AD5B0) : const Color(0xFF32816A),
        onPrimary: dark ? const Color(0xFF142A20) : Colors.white,
        surface: dark ? const Color(0xFF1B2523) : Colors.white,
        onSurface: dark ? const Color(0xFFE5EDE8) : const Color(0xFF252735),
      );
  final border = dark ? const Color(0xFF32423B) : const Color(0xFFEEEFF3);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Segoe UI',
    scaffoldBackgroundColor: dark
        ? const Color(0xFF121A19)
        : const Color(0xFFF8F9FC),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: scheme.onSurface, fontSize: 13),
      bodySmall: TextStyle(
        color: dark ? const Color(0xFFA0B0A8) : const Color(0xFF92939F),
        fontSize: 12,
      ),
    ),
    dividerColor: border,
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border),
      ),
      textStyle: TextStyle(color: scheme.onSurface, fontSize: 13),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF34493F) : const Color(0xFF263D32),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(color: Color(0xFFF0F6F2), fontSize: 11),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: dark ? const Color(0xFF2B4439) : const Color(0xFFEAF3EE),
      labelStyle: TextStyle(color: scheme.onSurface),
      side: BorderSide(color: border),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF15201C) : const Color(0xFFF8F9FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
    ),
  );
}
