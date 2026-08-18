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

/// Shared spacing and touch-target sizes used across the app.
class RunnaSpacing {
  static const page = 16.0;
  static const card = 14.0;
  static const section = 20.0;
  static const item = 10.0;
  static const buttonHeight = 40.0;
  static const inputHeight = 40.0;
}

class RunnaTheme {
  static const _buttonTextStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const _buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);
  static const _buttonMinSize = Size(0, RunnaSpacing.buttonHeight);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: RunnaColors.primary,
      primary: RunnaColors.primary,
      secondary: RunnaColors.accent,
      surface: RunnaColors.surface,
      brightness: Brightness.light,
    );

    final borderRadius = BorderRadius.circular(14);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: RunnaColors.background,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: RunnaColors.primaryDark,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        toolbarHeight: 52,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: RunnaColors.surface,
        height: 64,
        indicatorColor: RunnaColors.accent.withValues(alpha: 0.35),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? RunnaColors.primaryDark : RunnaColors.muted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? RunnaColors.primaryDark : RunnaColors.muted,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: RunnaColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: RunnaColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(borderRadius: borderRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: RunnaColors.muted.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: const BorderSide(color: RunnaColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(fontSize: 13),
        hintStyle: TextStyle(fontSize: 13, color: RunnaColors.muted.withValues(alpha: 0.75)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: RunnaColors.primary,
          foregroundColor: Colors.white,
          padding: _buttonPadding,
          minimumSize: _buttonMinSize,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: _buttonTextStyle,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RunnaColors.primaryDark,
          padding: _buttonPadding,
          minimumSize: _buttonMinSize,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: _buttonTextStyle,
          side: BorderSide(color: RunnaColors.muted.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RunnaColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(36, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      chipTheme: const ChipThemeData(
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      ),
      tabBarTheme: const TabBarThemeData(
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.label,
      ),
      listTileTheme: const ListTileThemeData(
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        minVerticalPadding: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        smallSizeConstraints: const BoxConstraints.tightFor(width: 40, height: 40),
        sizeConstraints: const BoxConstraints.tightFor(width: 48, height: 48),
      ),
    );
  }
}

class RunnaCard extends StatelessWidget {
  const RunnaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(RunnaSpacing.card),
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
        borderRadius: BorderRadius.circular(18),
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
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: const TextStyle(color: RunnaColors.muted, fontSize: 13),
          ),
        ],
      ],
    );
  }
}
