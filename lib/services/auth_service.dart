import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'app_settings.dart';

enum AuthResultType {
  success,
  cancelled,
  setupRequired,
  unsupported,
  failed,
}

class AuthResult {
  const AuthResult({
    required this.type,
    this.details,
  });

  final AuthResultType type;
  final String? details;
}

class AuthService {
  AuthService._();

  static bool _initialized = false;
  static bool _firebaseAvailable = false;
  static FirebaseAnalytics? _analytics;

  static bool get isFirebaseAvailable => _firebaseAvailable;
  static FirebaseAnalytics? get analytics => _analytics;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
      _firebaseAvailable = true;
      _analytics = FirebaseAnalytics.instance;
      await syncAuthState();
    } catch (e) {
      _firebaseAvailable = false;
      debugPrint('Firebase initialization skipped: $e');
    }
  }

  static Future<void> syncAuthState() async {
    if (!_firebaseAvailable) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await AppSettings.signOut();
      return;
    }
    await _persistSignedInUser(user);
  }

  static Future<AuthResult> signInWithGoogle() async {
    if (!_firebaseAvailable) {
      return const AuthResult(type: AuthResultType.setupRequired);
    }
    try {
      final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
      if (googleUser == null) {
        return const AuthResult(type: AuthResultType.cancelled);
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return const AuthResult(type: AuthResultType.failed);
      }
      await _persistSignedInUser(user);
      return const AuthResult(type: AuthResultType.success);
    } on FirebaseAuthException catch (e) {
      return AuthResult(type: AuthResultType.failed, details: e.message);
    } catch (e) {
      return AuthResult(type: AuthResultType.failed, details: e.toString());
    }
  }

  static Future<AuthResult> signInWithApple() async {
    if (!_firebaseAvailable) {
      return const AuthResult(type: AuthResultType.setupRequired);
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final provider = AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        final userCredential =
            await FirebaseAuth.instance.signInWithProvider(provider);
        final user = userCredential.user;
        if (user == null) {
          return const AuthResult(type: AuthResultType.failed);
        }
        await _persistSignedInUser(user);
        return const AuthResult(type: AuthResultType.success);
      }

      final appleAvailable = await SignInWithApple.isAvailable();
      if (!appleAvailable) {
        return const AuthResult(type: AuthResultType.unsupported);
      }
      final rawNonce = _generateNonce();
      final nonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      final identityToken = appleCredential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        return const AuthResult(type: AuthResultType.failed);
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user == null) {
        return const AuthResult(type: AuthResultType.failed);
      }

      final appleDisplayName = _appleName(appleCredential);
      if (appleDisplayName.isNotEmpty && (user.displayName ?? '').isEmpty) {
        await user.updateDisplayName(appleDisplayName);
        await user.reload();
      }

      await _persistSignedInUser(FirebaseAuth.instance.currentUser ?? user);
      return const AuthResult(type: AuthResultType.success);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const AuthResult(type: AuthResultType.cancelled);
      }
      final details = 'apple_auth:${e.code.name}:${e.message}';
      if (_isAppleSetupIssue(details)) {
        return AuthResult(type: AuthResultType.setupRequired, details: details);
      }
      return AuthResult(type: AuthResultType.failed, details: details);
    } on FirebaseAuthException catch (e) {
      final details = 'firebase_auth:${e.code}:${e.message ?? ''}';
      if (_isAppleSetupIssue(details)) {
        return AuthResult(type: AuthResultType.setupRequired, details: details);
      }
      return AuthResult(type: AuthResultType.failed, details: details);
    } catch (e) {
      return AuthResult(type: AuthResultType.failed, details: e.toString());
    }
  }

  static Future<AuthResult> signOut() async {
    if (!_firebaseAvailable) {
      await AppSettings.signOut();
      return const AuthResult(type: AuthResultType.success);
    }
    try {
      await FirebaseAuth.instance.signOut();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      await AppSettings.signOut();
      return const AuthResult(type: AuthResultType.success);
    } catch (e) {
      return AuthResult(type: AuthResultType.failed, details: e.toString());
    }
  }

  static Future<void> _persistSignedInUser(User user) {
    final providerId = user.providerData
        .map((p) => p.providerId)
        .firstWhere(
          (id) => id == 'google.com' || id == 'apple.com',
          orElse: () => user.providerData.isNotEmpty
              ? user.providerData.first.providerId
              : 'unknown',
        );
    final provider = switch (providerId) {
      'google.com' => 'google',
      'apple.com' => 'apple',
      _ => providerId,
    };
    final displayName = (user.displayName ?? user.email ?? 'User').trim();
    return AppSettings.setLoggedInUser(
      provider: provider,
      displayName: displayName.isEmpty ? 'User' : displayName,
    );
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _appleName(AuthorizationCredentialAppleID credential) {
    final givenName = credential.givenName?.trim() ?? '';
    final familyName = credential.familyName?.trim() ?? '';
    return '$givenName $familyName'.trim();
  }

  static bool _isAppleSetupIssue(String details) {
    final lower = details.toLowerCase();
    return lower.contains('operation-not-allowed') ||
        lower.contains('invalid-credential') ||
        lower.contains('missing-or-invalid-nonce') ||
        lower.contains('service id') ||
        lower.contains('configuration') ||
        lower.contains('not configured') ||
        lower.contains('akauthenticationerror');
  }
}
