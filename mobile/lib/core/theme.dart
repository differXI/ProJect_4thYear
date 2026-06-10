import 'package:flutter/material.dart';

class RunnaColors {
  static const primary = Color(0xFF1F6B43);
  static const primaryDark = Color(0xFF164D31);
  static const accent = Color(0xFF7BC896);
  static const background = Color(0xFFF3F7F4);
  static const surface = Color(0xFFFFFFFF);
  static const muted = Color(0xFF6B7C72);
  static const danger = Color(0xFFC45C4A);
  static const warning = Color(0xFFE3A008);
}

class RunnaTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: RunnaColors.primary,
      primary: RunnaColors.primary,
      secondary: RunnaColors.accent,
      surface: RunnaColors.surface,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: RunnaColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: RunnaColors.primaryDark,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: RunnaColors.surface,
        indicatorColor: RunnaColors.accent.withValues(alpha: 0.35),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: RunnaColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RunnaColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: RunnaColors.muted.withValues(alpha: 0.25)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: RunnaColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class RunnaCard extends StatelessWidget {
  const RunnaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: RunnaColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RunnaColors.muted.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: TextStyle(color: RunnaColors.muted)),
        ],
      ],
    );
  }
}
