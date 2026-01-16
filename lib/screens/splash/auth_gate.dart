import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'welcome_screen.dart';
import '../profile/profile_setup_screen.dart';
import '../main/main_screen.dart';
import '../auth/phone_verify_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ Not logged in
        if (!snapshot.hasData) {
          return const WelcomeScreen();
        }

        // ✅ Logged in
        final user = snapshot.data!;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = profileSnapshot.data?.data() as Map<String, dynamic>?;

            // ❌ Phone not verified (Check this first if document exists or if phoneVerified is not true)
            if (data == null || data['phoneVerified'] != true) {
              return const PhoneVerifyScreen();
            }

            // ❌ Profile not completed
            if (data['name'] == null || data['district'] == null) {
              return const ProfileSetupScreen();
            }

            // ✅ Profile & Phone verified → HOME
            return const MainScreen();
          },
        );
      },
    );
  }
}
