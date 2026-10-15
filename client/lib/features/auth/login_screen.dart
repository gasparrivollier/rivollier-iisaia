import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/api/api_client.dart';
import 'auth_controller.dart';
import 'auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  Map<String, String> _fieldErrors = const {};
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      // On success the router's redirect moves to the Diary.
      await auth.login(email: _email.text.trim(), password: _password.text);
    } on ApiException catch (e) {
      if (mounted) {
        final r = splitAuthError(e, {'email', 'password'});
        setState(() {
          _error = r.general;
          _fieldErrors = r.fields;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearFieldError(String field) {
    if (_fieldErrors.containsKey(field)) setState(() => _fieldErrors = {..._fieldErrors}..remove(field));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Sign in',
      titleId: 'login-title',
      subtitle: 'Open your field journal',
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                identifier: 'login-email',
                child: TextFormField(
                  key: const Key('loginEmail'),
                  forceErrorText: _fieldErrors['email'],
                  onChanged: (_) => _clearFieldError('email'),
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                identifier: 'login-password',
                child: TextFormField(
                  key: const Key('loginPassword'),
                  forceErrorText: _fieldErrors['password'],
                  onChanged: (_) => _clearFieldError('password'),
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (_error != null) AuthErrorText(id: 'login-error', message: _error!),
              Semantics(
                identifier: 'login-submit',
                child: FilledButton(
                  key: const Key('loginSubmit'),
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
                  child: const Text('Sign in'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                identifier: 'go-to-register',
                child: TextButton(
                  key: const Key('goToRegister'),
                  onPressed: () => context.go('/register'),
                  child: const Text('New here? Create an account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
