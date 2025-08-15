import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app.dart' show RefaHomePage;
import 'phone_auth.dart';
import 'welcome_splash.dart'; // <-- hoş geldiniz

// Oturum açık olsa bile login ekranını görmek için TRUE (testte işine yarar).
const bool kForceLoginPreview = true;

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        '/home': (_)     => const RefaHomePage(),
        '/login': (_)    => const PhoneAuthPage(),
        '/welcome': (_)=> const WelcomeSplash(), // <-- eklendi
      },
      home: kForceLoginPreview
          ? const PhoneAuthPage()
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!snap.hasData) return const PhoneAuthPage();
                return const RefaHomePage();
              },
            ),
    );
  }
}
