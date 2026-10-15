import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/api/api_client.dart';

/// Mirrors the backend's RegisterRequest rules (min 8 chars, max 72 bytes for bcrypt).
const int kMinPasswordChars = 8;
const int kMaxPasswordBytes = 72;

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  return ok ? null : 'Enter a valid email';
}

String? validateNewPassword(String? value) {
  final v = value ?? '';
  if (v.length < kMinPasswordChars) return 'At least $kMinPasswordChars characters';
  if (utf8.encode(v).length > kMaxPasswordBytes) {
    return 'At most $kMaxPasswordBytes bytes (shorter, or fewer accented characters)';
  }
  return null;
}

String? validateDisplayName(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your name';
  if (v.length > 100) return 'At most 100 characters';
  return null;
}

String authErrorMessage(ApiException e) => switch (e.statusCode) {
      0 => "Can't reach the Yvoty server. Try again in a moment.",
      401 => 'Wrong email or password.',
      409 => 'That email is already registered. Sign in instead.',
      422 => 'Please check the fields and try again.',
      _ => 'Something went wrong (${e.statusCode}). Try again.',
    };

/// Centered, narrow card layout shared by the login and register screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.titleId,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String titleId;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Yvoty',
                    textAlign: TextAlign.center,
                    style: context.yvotyType.serifStyle(fontSize: 30),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Semantics(
                    identifier: titleId,
                    child: Text(title, style: context.yvotyType.serifStyle(fontSize: 21)),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.inkFaint)),
                  const SizedBox(height: AppSpacing.xxl),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error line under a form; announced to e2e via [id].
class AuthErrorText extends StatelessWidget {
  const AuthErrorText({super.key, required this.id, required this.message});

  final String id;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Semantics(
          identifier: id,
          liveRegion: true,
          child: Text(message, style: const TextStyle(color: AppColors.terracotta)),
        ),
      );
}
