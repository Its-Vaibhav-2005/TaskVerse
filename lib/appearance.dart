import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'desktop_bridge.dart';
import 'theme_catalog.dart';
export 'theme_catalog.dart';

class Appearance extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;
  String presetName = 'TrackVerse';
  ThemePreset get preset => themePresets.firstWhere(
    (t) => t.name == presetName,
    orElse: () => themePresets.first,
  );
  Future<void> setPreset(String name) async {
    if (!themePresets.any((t) => t.name == name)) {
      throw ArgumentError('Unknown theme');
    }
    final previous = presetName;
    presetName = name;
    notifyListeners();
    try {
      if (isWindowsDesktop) {
        await desktopRequest('setThemePreset', name);
      } else {
        await (await SharedPreferences.getInstance()).setString(
          'themePreset',
          name,
        );
      }
    } catch (_) {
      presetName = previous;
      notifyListeners();
      rethrow;
    }
  }

  int fontStep = 0;
  String fontFamily = 'Inter';
  static const fonts = ['Inter', 'Lora', 'JetBrains Mono'];
  int _typographyRevision = 0;
  Future<void> _typographySave = Future.value();
  Future<void> setTypography({int? step, String? family}) async {
    final oldStep = fontStep, oldFont = fontFamily;
    final revision = ++_typographyRevision;
    fontStep = (step ?? fontStep).clamp(-2, 4);
    fontFamily = fonts.contains(family) ? family! : fontFamily;
    final value = jsonEncode({'step': fontStep, 'family': fontFamily});
    notifyListeners();
    try {
      // Keep rapid adjustments responsive while persisting in order.
      final save = _typographySave.then((_) async {
        if (isWindowsDesktop) {
          await desktopRequest('setTypography', value);
        } else if (!await (await SharedPreferences.getInstance()).setString(
          'typography',
          value,
        )) {
          throw StateError('Could not save typography');
        }
      });
      _typographySave = save.catchError((_) {});
      await save;
    } catch (_) {
      if (revision == _typographyRevision) {
        fontStep = oldStep;
        fontFamily = oldFont;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> load() async {
    try {
      final saved = isWindowsDesktop
          ? await desktopRequest('getTheme')
          : (await SharedPreferences.getInstance()).getString('appearance');
      mode = saved == 'dark'
          ? ThemeMode.dark
          : saved == 'light'
          ? ThemeMode.light
          : ThemeMode.system;
      final savedPreset = isWindowsDesktop
          ? await desktopRequest('getThemePreset')
          : (await SharedPreferences.getInstance()).getString('themePreset');
      presetName = themePresets.any((t) => t.name == savedPreset)
          ? savedPreset!
          : 'TrackVerse';
      final raw = isWindowsDesktop
          ? await desktopRequest('getTypography')
          : (await SharedPreferences.getInstance()).getString('typography');
      if (raw != null) {
        final type = jsonDecode(raw) as Map;
        fontStep = ((type['step'] as num?)?.toInt() ?? 0).clamp(-2, 4);
        if (fonts.contains(type['family'])) {
          fontFamily = type['family'] as String;
        }
      }
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
  Map<String, Color> get palette =>
      appearance.preset.palette(dark ? Brightness.dark : Brightness.light);
  Color get background => palette['background']!;
  Color get surface => palette['surface']!;
  Color get raised => palette['raised']!;
  Color get text => palette['text']!;
  Color get muted => palette['muted']!;
  Color get border => palette['border']!;
  Color get accent => palette['accent']!;
  Color get selected => palette['selected']!;
}

ThemeData trackVerseTheme(Brightness brightness) {
  final p = appearance.preset.palette(brightness);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: p['accent']!,
        brightness: brightness,
      ).copyWith(
        primary: p['accent'],
        onPrimary: p['onAccent'],
        surface: p['surface'],
        onSurface: p['text'],
        onSurfaceVariant: p['muted'],
        outline: p['border'],
      );
  final border = p['border']!;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: appearance.fontFamily,
    scaffoldBackgroundColor: p['background'],
    textTheme: TextTheme(
      bodyMedium: TextStyle(
        color: scheme.onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(
        color: p['muted'],
        fontWeight: FontWeight.w500,
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
      textStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 13,
        fontFamily: appearance.fontFamily,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p['text'],
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(
        color: p['surface'],
        fontSize: 11,
        fontFamily: appearance.fontFamily,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: p['selected'],
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontFamily: appearance.fontFamily,
      ),
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
      fillColor: p['background'],
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
