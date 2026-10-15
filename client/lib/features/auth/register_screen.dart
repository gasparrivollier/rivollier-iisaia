import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/api/api_client.dart';
import 'auth_controller.dart';
import 'auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  Map<String, String> _fieldErrors = const {};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
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
      await auth.register(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _name.text.trim(),
      );
    } on ApiException catch (e) {
      if (mounted) {
        final r = splitAuthError(e, {'display_name', 'email', 'password'});
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
      title: 'Create an account',
      titleId: 'register-title',
      subtitle: 'Start your own plant diary',
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                identifier: 'register-display-name',
                child: TextFormField(
                  key: const Key('registerDisplayName'),
                  forceErrorText: _fieldErrors['display_name'],
                  onChanged: (_) => _clearFieldError('display_name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  validator: validateDisplayName,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                identifier: 'register-email',
                child: TextFormField(
                  key: const Key('registerEmail'),
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
                identifier: 'register-password',
                child: TextFormField(
                  key: const Key('registerPassword'),
                  forceErrorText: _fieldErrors['password'],
                  onChanged: (_) => _clearFieldError('password'),
                  controller: _password,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText: 'At least 8 characters',
                  ),
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: validateNewPassword,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (_error != null) AuthErrorText(id: 'register-error', message: _error!),
              Semantics(
                identifier: 'register-submit',
                child: FilledButton(
                  key: const Key('registerSubmit'),
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
                  child: const Text('Create account'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                identifier: 'go-to-login',
                child: TextButton(
                  key: const Key('goToLogin'),
                  onPressed: () => context.go('/login'),
                  child: const Text('Already have an account? Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
