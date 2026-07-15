import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models.dart';
import '../../core/runna_api.dart';
import '../../core/theme.dart';
import 'auth_controller.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _loginIdentifierController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerFirstNameController = TextEditingController();
  final _registerLastNameController = TextEditingController();
  final _registerUsernameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();

  HealthResponse? _health;
  String? _message;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHealth();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _registerFirstNameController.dispose();
    _registerLastNameController.dispose();
    _registerUsernameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadHealth() async {
    try {
      final health = await widget.controller.getHealth();
      if (!mounted) return;
      setState(() => _health = health);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Backend offline: $error');
    }
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await widget.controller.login(
        usernameOrEmail: _loginIdentifierController.text.trim(),
        password: _loginPasswordController.text,
      );
      if (!mounted) return;
      setState(() => _message = 'Signed in successfully.');
    } on RunnaApiException catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await widget.controller.register(
        firstName: _registerFirstNameController.text.trim(),
        lastName: _registerLastNameController.text.trim(),
        username: _registerUsernameController.text.trim(),
        email: _registerEmailController.text.trim(),
        password: _registerPasswordController.text,
      );
      if (!mounted) return;
      setState(() => _message = 'Account created. You can sign in now.');
      _tabController.animateTo(0);
    } on RunnaApiException catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPassword() async {
    final emailController = TextEditingController(
      text: _loginIdentifierController.text.contains('@')
          ? _loginIdentifierController.text.trim()
          : '',
    );
    final codeController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var codeRequested = false;
    var loading = false;
    String? error;
    String? notice;

    final resetSucceeded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> submit() async {
            if (loading || !formKey.currentState!.validate()) return;
            setSheetState(() {
              loading = true;
              error = null;
              notice = null;
            });
            try {
              if (!codeRequested) {
                final message = await widget.controller.forgotPassword(
                  email: emailController.text.trim(),
                );
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  codeRequested = true;
                  notice = message;
                });
              } else {
                await widget.controller.resetPassword(
                  email: emailController.text.trim(),
                  code: codeController.text,
                  newPassword: passwordController.text,
                  confirmPassword: confirmController.text,
                );
                if (sheetContext.mounted) Navigator.pop(sheetContext, true);
              }
            } on RunnaApiException catch (exception) {
              if (sheetContext.mounted) {
                setSheetState(() => error = exception.message);
              }
            } finally {
              if (sheetContext.mounted) setSheetState(() => loading = false);
            }
          }

          return _DisposeOnUnmount(
            onDispose: () {
              emailController.dispose();
              codeController.dispose();
              passwordController.dispose();
              confirmController.dispose();
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        codeRequested ? 'Enter reset code' : 'Forgot password',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('reset_email_field'),
                        controller: emailController,
                        enabled: !codeRequested && !loading,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          return RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(email)
                              ? null
                              : 'Enter a valid email address';
                        },
                      ),
                      if (codeRequested) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('reset_code_field'),
                          controller: codeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: const InputDecoration(
                            labelText: '6-digit code',
                          ),
                          validator: (value) =>
                              RegExp(r'^\d{6}$').hasMatch(value ?? '')
                              ? null
                              : 'Enter the 6-digit code',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('reset_new_password_field'),
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New password',
                          ),
                          validator: (value) => (value?.length ?? 0) >= 8
                              ? null
                              : 'Password must be at least 8 characters',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('reset_confirm_password_field'),
                          controller: confirmController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                          ),
                          validator: (value) => value == passwordController.text
                              ? null
                              : 'Passwords do not match',
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: const TextStyle(color: RunnaColors.danger),
                        ),
                      ],
                      if (notice != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          notice!,
                          style: const TextStyle(
                            color: RunnaColors.primaryDark,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('reset_submit_button'),
                          onPressed: loading ? null : submit,
                          child: Text(
                            loading
                                ? 'Please wait...'
                                : codeRequested
                                ? 'Reset password'
                                : 'Send reset code',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (resetSucceeded == true && mounted) {
      _loginIdentifierController.text = emailController.text.trim();
      _tabController.animateTo(0);
      setState(() => _message = 'Password reset successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser;

    if (user != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionTitle('Account', subtitle: 'Your Runna member profile'),
          const SizedBox(height: 16),
          RunnaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text('@${user.username} • ${user.email}'),
                const SizedBox(height: 8),
                Chip(
                  label: Text(user.roleName.toUpperCase()),
                  backgroundColor: RunnaColors.accent.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: widget.controller.logout,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle(
          'Welcome to Runna',
          subtitle: 'Sign in or create a member account',
        ),
        const SizedBox(height: 16),
        RunnaCard(
          child: Row(
            children: [
              Icon(
                _health?.status == 'ok'
                    ? Icons.check_circle_outline
                    : Icons.cloud_off_outlined,
                color: RunnaColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _health?.status == 'ok'
                      ? 'Backend connected'
                      : _message ?? 'Checking backend...',
                ),
              ),
              TextButton(onPressed: _loadHealth, child: const Text('Retry')),
            ],
          ),
        ),
        if (_message != null && user == null) ...[
          const SizedBox(height: 12),
          Text(_message!, style: const TextStyle(color: RunnaColors.danger)),
        ],
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          labelColor: RunnaColors.primaryDark,
          tabs: const [
            Tab(text: 'Sign in'),
            Tab(text: 'Register'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 500,
          child: TabBarView(
            controller: _tabController,
            children: [
              _AuthForm(
                formKey: _loginFormKey,
                title: 'Sign in',
                fields: [
                  _Field(
                    controller: _loginIdentifierController,
                    label: 'Username or email',
                  ),
                  _Field(
                    controller: _loginPasswordController,
                    label: 'Password',
                    obscure: true,
                  ),
                ],
                secondaryAction: TextButton(
                  key: const Key('forgot_password_button'),
                  onPressed: _isLoading ? null : _showForgotPassword,
                  child: const Text('Forgot password?'),
                ),
                buttonLabel: _isLoading ? 'Signing in...' : 'Sign in',
                onSubmit: _isLoading ? null : _handleLogin,
              ),
              _AuthForm(
                formKey: _registerFormKey,
                title: 'Create account',
                fields: [
                  _Field(
                    controller: _registerFirstNameController,
                    label: 'First name',
                  ),
                  _Field(
                    controller: _registerLastNameController,
                    label: 'Last name',
                  ),
                  _Field(
                    controller: _registerUsernameController,
                    label: 'Username',
                  ),
                  _Field(controller: _registerEmailController, label: 'Email'),
                  _Field(
                    controller: _registerPasswordController,
                    label: 'Password',
                    obscure: true,
                  ),
                ],
                buttonLabel: _isLoading ? 'Creating...' : 'Create account',
                onSubmit: _isLoading ? null : _handleRegister,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const RunnaCard(
          child: Text(
            'Guests can browse the map and hazard pins without signing in. '
            'Create an account to save routes, track runs, and receive AI insights.',
          ),
        ),
      ],
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.formKey,
    required this.title,
    required this.fields,
    required this.buttonLabel,
    required this.onSubmit,
    this.secondaryAction,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final List<Widget> fields;
  final String buttonLabel;
  final VoidCallback? onSubmit;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return RunnaCard(
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          //  เพิ่มตัวนี้เข้าไปครอบแทน Column หรือครอบใน Form
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ...fields.expand((field) => [field, const SizedBox(height: 12)]),
              if (secondaryAction != null)
                Align(alignment: Alignment.centerRight, child: secondaryAction),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSubmit,
                  child: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: (value) =>
          value == null || value.trim().isEmpty ? '$label is required' : null,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _DisposeOnUnmount extends StatefulWidget {
  const _DisposeOnUnmount({required this.onDispose, required this.child});

  final VoidCallback onDispose;
  final Widget child;

  @override
  State<_DisposeOnUnmount> createState() => _DisposeOnUnmountState();
}

class _DisposeOnUnmountState extends State<_DisposeOnUnmount> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
