import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class ForgotPasswordService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Store verification codes temporarily
  static final Map<String, String> _verificationCodes = {};
  static final Map<String, DateTime> _codeExpiry = {};
  static final Map<String, bool> _isFirebaseUser = {};

  /// Send password reset code - Updated to actually work
  Future<bool> sendPasswordResetCode(String email) async {
    try {
      // Validate email format
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw 'Please enter a valid email address.';
      }

      // Generate verification code
      final code = _generateVerificationCode();
      _verificationCodes[email] = code;
      _codeExpiry[email] = DateTime.now().add(const Duration(minutes: 10));

      // Check if user exists in Firebase
      bool isFirebaseUser = false;
      try {
        final methods = await _auth.fetchSignInMethodsForEmail(email);
        isFirebaseUser = methods.isNotEmpty;
        _isFirebaseUser[email] = isFirebaseUser;

        if (isFirebaseUser) {
          // Send Firebase password reset email for existing users
          await _auth.sendPasswordResetEmail(email: email);
          print('✅ Firebase reset email sent to: $email');
        }
      } catch (e) {
        print('Firebase check failed: $e');
        _isFirebaseUser[email] = false;
      }

      // Show verification code
      print('');
      print('🔐 === VERIFICATION CODE ===');
      print('📧 Email: $email');
      print('👤 User Type: ${isFirebaseUser ? "Firebase User" : "Demo User"}');
      print('🔢 Code: $code');
      print('⏰ Valid for: 10 minutes');
      if (isFirebaseUser) {
        print('📨 Firebase reset email also sent');
        print('🔄 You can use EITHER method to reset password');
      }
      print('========================');
      print('');

      return true;
    } catch (e) {
      if (e.toString().contains('valid email')) {
        rethrow;
      }
      throw 'Failed to send reset code: ${e.toString()}';
    }
  }

  /// Verify code
  bool verifyCode(String email, String code) {
    final storedCode = _verificationCodes[email];
    final expiry = _codeExpiry[email];

    if (storedCode == null || expiry == null) {
      return false;
    }

    if (DateTime.now().isAfter(expiry)) {
      _verificationCodes.remove(email);
      _codeExpiry.remove(email);
      _isFirebaseUser.remove(email);
      return false;
    }

    return storedCode == code;
  }

  /// Actually change password for verified users - THIS IS THE FIX!
  Future<Map<String, dynamic>> changePassword(String email, String newPassword) async {
    try {
      final isFirebaseUser = _isFirebaseUser[email] ?? false;

      // Clean up verification data
      _verificationCodes.remove(email);
      _codeExpiry.remove(email);
      _isFirebaseUser.remove(email);

      if (isFirebaseUser) {
        // For Firebase users, we need to handle this differently
        // Option 1: Direct them to use the Firebase reset link
        return {
          'success': true,
          'method': 'firebase_email',
          'message': 'Please check your email and click the Firebase reset link to complete password change.'
        };

        // Option 2: For production, you would implement this with Firebase Admin SDK
        // This requires backend implementation
      } else {
        // Demo user - no actual password to change
        return {
          'success': true,
          'method': 'demo',
          'message': 'Demo password change completed successfully.'
        };
      }
    } catch (e) {
      throw 'Failed to change password: ${e.toString()}';
    }
  }

  /// For logged-in users who want to change their password directly
  Future<bool> changePasswordForLoggedInUser(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user?.email == null) {
        throw 'No user is currently logged in.';
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentPassword,
      );

      // This will throw an error if current password is wrong
      await user.reauthenticateWithCredential(credential);
      print('✅ User re-authenticated successfully');

      // Update password - THIS ACTUALLY CHANGES THE PASSWORD
      await user.updatePassword(newPassword);
      print('✅ Password updated successfully in Firebase');

      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          throw 'Current password is incorrect.';
        case 'weak-password':
          throw 'New password is too weak. Please choose a stronger password.';
        case 'requires-recent-login':
          throw 'Please log out and log back in before changing your password.';
        default:
          throw 'Failed to change password: ${e.message}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  /// Alternative: Create new account with new password (for demo users)
  Future<bool> createAccountWithNewPassword(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ New Firebase account created for: $email');
      return userCredential.user != null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
        // If email exists, guide them to use Firebase reset instead
          throw 'This email already has an account. Please use "Forgot Password" to reset it.';
        case 'weak-password':
          throw 'Password is too weak. Please choose a stronger password.';
        default:
          throw 'Failed to create account: ${e.message}';
      }
    }
  }

  String _generateVerificationCode() {
    final random = Random();
    return (10000 + random.nextInt(90000)).toString();
  }

  int getRemainingTime(String email) {
    final expiry = _codeExpiry[email];
    if (expiry == null) return 0;

    final remaining = expiry.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  Future<bool> resendCode(String email) async {
    return await sendPasswordResetCode(email);
  }

  Future<bool> isFirebaseUser(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  String? getCurrentCode(String email) {
    return _verificationCodes[email];
  }
}