// lib/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'phone_auth.dart';
import 'welcome_splash.dart';

// DEMO: her açılışta login ekranını zorla görmek için true yap.
// Canlıda false yap.
const bool kForceLoginPreview = true;

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Demo zorlaması: her açılışta login
    if (kForceLoginPreview) {
      return const PhoneAuthPage();
    }

    // Normal akış: Firebase oturum değişimlerini dinle
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final u = snap.data;

        // Oturum yoksa (veya anonimse) → Login
        if (u == null || u.isAnonymous) {
          return const PhoneAuthPage();
        }

        // Oturum varsa → Welcome (TTS söyle, sonra /home’a yönlendirir)
        return const WelcomeSplash();
      },
    );
  }
}
