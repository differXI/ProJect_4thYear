import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runna_mobile/core/models.dart';
import 'package:runna_mobile/core/theme.dart';
import 'package:runna_mobile/features/auth/auth_controller.dart';
import 'package:runna_mobile/features/auth/auth_screen.dart';

void main() {
  testWidgets('Runna auth screen renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RunnaTheme.light(),
        home: Scaffold(body: AuthScreen(controller: _FakeAuthController())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Runna'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Register'), findsOneWidget);
  });
}

class _FakeAuthController extends AuthController {
  @override
  Future<HealthResponse> getHealth() async =>
      const HealthResponse(status: 'ok');
}
