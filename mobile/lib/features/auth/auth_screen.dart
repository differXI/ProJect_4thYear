import 'package:flutter/material.dart';

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

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
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
                Text(user.fullName, style: Theme.of(context).textTheme.headlineSmall),
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
        const SectionTitle('Welcome to Runna', subtitle: 'Sign in or create a member account'),
        const SizedBox(height: 16),
        RunnaCard(
          child: Row(
            children: [
              Icon(
                _health?.status == 'ok' ? Icons.check_circle_outline : Icons.cloud_off_outlined,
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
          tabs: const [Tab(text: 'Sign in'), Tab(text: 'Register')],
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
                  _Field(controller: _loginIdentifierController, label: 'Username or email'),
                  _Field(controller: _loginPasswordController, label: 'Password', obscure: true),
                ],
                buttonLabel: _isLoading ? 'Signing in...' : 'Sign in',
                onSubmit: _isLoading ? null : _handleLogin,
              ),
              _AuthForm(
                formKey: _registerFormKey,
                title: 'Create account',
                fields: [
                  _Field(controller: _registerFirstNameController, label: 'First name'),
                  _Field(controller: _registerLastNameController, label: 'Last name'),
                  _Field(controller: _registerUsernameController, label: 'Username'),
                  _Field(controller: _registerEmailController, label: 'Email'),
                  _Field(controller: _registerPasswordController, label: 'Password', obscure: true),
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
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final List<Widget> fields;
  final String buttonLabel;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return RunnaCard(
      child: Form(
        key: formKey,
        child: SingleChildScrollView( //  เพิ่มตัวนี้เข้าไปครอบแทน Column หรือครอบใน Form
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ...fields.expand((field) => [field, const SizedBox(height: 12)]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: onSubmit, child: Text(buttonLabel)),
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
      validator: (value) => value == null || value.trim().isEmpty ? '$label is required' : null,
      decoration: InputDecoration(labelText: label),
    );
  }
}
