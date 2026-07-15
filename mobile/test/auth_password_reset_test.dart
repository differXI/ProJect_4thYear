import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runna_mobile/core/runna_api.dart';
import 'package:runna_mobile/core/theme.dart';
import 'package:runna_mobile/features/auth/auth_controller.dart';
import 'package:runna_mobile/features/auth/auth_screen.dart';

void main() {
  Future<void> pumpAuthScreen(WidgetTester tester, http.Client client) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RunnaTheme.light(),
        home: Scaffold(
          body: AuthScreen(
            controller: AuthController(api: RunnaApi(client: client)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  MockClient successfulClient({
    void Function()? onForgot,
    void Function()? onReset,
  }) {
    return MockClient((request) async {
      if (request.url.path.endsWith('/health')) {
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }
      if (request.url.path.endsWith('/auth/forgot-password')) {
        onForgot?.call();
        return http.Response(
          jsonEncode({
            'message':
                'If an account exists for this email, a reset code has been sent.',
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/auth/reset-password')) {
        onReset?.call();
        return http.Response(
          jsonEncode({'message': 'Password reset successfully.'}),
          200,
        );
      }
      return http.Response('{}', 404);
    });
  }

  Future<void> openResetSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('forgot_password_button')));
    await tester.pumpAndSettle();
  }

  Future<void> requestCode(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('reset_email_field')),
      'runner@example.com',
    );
    await tester.tap(find.byKey(const Key('reset_submit_button')));
    await tester.pumpAndSettle();
  }

  testWidgets('forgot password action appears on sign in', (tester) async {
    await pumpAuthScreen(tester, successfulClient());
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('tapping forgot password opens reset UI', (tester) async {
    await pumpAuthScreen(tester, successfulClient());
    await openResetSheet(tester);
    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.byKey(const Key('reset_email_field')), findsOneWidget);
  });

  testWidgets('invalid reset email is rejected locally', (tester) async {
    var forgotRequests = 0;
    await pumpAuthScreen(
      tester,
      successfulClient(onForgot: () => forgotRequests++),
    );
    await openResetSheet(tester);
    await tester.enterText(
      find.byKey(const Key('reset_email_field')),
      'invalid',
    );
    await tester.tap(find.byKey(const Key('reset_submit_button')));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(forgotRequests, 0);
  });

  testWidgets('reset OTP must contain exactly six digits', (tester) async {
    await pumpAuthScreen(tester, successfulClient());
    await openResetSheet(tester);
    await requestCode(tester);
    await tester.enterText(find.byKey(const Key('reset_code_field')), '12345');
    await tester.enterText(
      find.byKey(const Key('reset_new_password_field')),
      'newpassword123',
    );
    await tester.enterText(
      find.byKey(const Key('reset_confirm_password_field')),
      'newpassword123',
    );
    await tester.tap(find.byKey(const Key('reset_submit_button')));
    await tester.pump();
    expect(find.text('Enter the 6-digit code'), findsOneWidget);
  });

  testWidgets('reset password confirmation mismatch is rejected', (
    tester,
  ) async {
    await pumpAuthScreen(tester, successfulClient());
    await openResetSheet(tester);
    await requestCode(tester);
    await tester.enterText(find.byKey(const Key('reset_code_field')), '123456');
    await tester.enterText(
      find.byKey(const Key('reset_new_password_field')),
      'newpassword123',
    );
    await tester.enterText(
      find.byKey(const Key('reset_confirm_password_field')),
      'differentpassword',
    );
    await tester.tap(find.byKey(const Key('reset_submit_button')));
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('duplicate forgot password submission is prevented while loading', (
    tester,
  ) async {
    final responseCompleter = Completer<http.Response>();
    var forgotRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/health')) {
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }
      if (request.url.path.endsWith('/auth/forgot-password')) {
        forgotRequests++;
        return responseCompleter.future;
      }
      return http.Response('{}', 404);
    });
    await pumpAuthScreen(tester, client);
    await openResetSheet(tester);
    await tester.enterText(
      find.byKey(const Key('reset_email_field')),
      'runner@example.com',
    );
    await tester.tap(find.byKey(const Key('reset_submit_button')));
    await tester.tap(find.byKey(const Key('reset_submit_button')));
    await tester.pump();
    expect(forgotRequests, 1);
    expect(find.text('Please wait...'), findsOneWidget);

    responseCompleter.complete(
      http.Response(
        jsonEncode({
          'message':
              'If an account exists for this email, a reset code has been sent.',
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('successful reset closes flow and returns to sign in', (
    tester,
  ) async {
    var resetRequests = 0;
    await pumpAuthScreen(
      tester,
      successfulClient(onReset: () => resetRequests++),
    );
    await openResetSheet(tester);
    await requestCode(tester);
    await tester.enterText(find.byKey(const Key('reset_code_field')), '123456');
    await tester.enterText(
      find.byKey(const Key('reset_new_password_field')),
      'newpassword123',
    );
    await tester.enterText(
      find.byKey(const Key('reset_confirm_password_field')),
      'newpassword123',
    );
    await tester.tap(find.byKey(const Key('reset_submit_button')));
    await tester.pumpAndSettle();
    expect(resetRequests, 1);
    expect(find.text('Password reset successfully.'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.byKey(const Key('reset_email_field')), findsNothing);
  });
}
