import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:io';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // EmailJS Configuration - ADD YOUR CREDENTIALS HERE
  static const String _emailJSServiceId = 'service_6jpqd4o';
  static const String _emailJSTemplateId = 'template_616umwo';
  static const String _emailJSPublicKey = 'wNjUSJo2BpWLhEDhs';
  static const String _emailJSApiUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email and password with improved error handling
  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          throw Exception('The password provided is too weak.');
        case 'email-already-in-use':
          throw Exception('An account already exists for this email.');
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        case 'operation-not-allowed':
          throw Exception('Email/password accounts are not enabled.');
        case 'network-request-failed':
          throw Exception('Network error. Please check your internet connection.');
        default:
          throw Exception('Failed to create account: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to create account: ${e.toString()}');
    }
  }

  // Sign in with email and password with improved error handling
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No user found for this email.');
        case 'wrong-password':
          throw Exception('Wrong password provided.');
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        case 'user-disabled':
          throw Exception('This user account has been disabled.');
        case 'too-many-requests':
          throw Exception('Too many failed login attempts. Please try again later.');
        case 'network-request-failed':
          throw Exception('Network error. Please check your internet connection.');
        default:
          throw Exception('Failed to sign in: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null; // User cancelled sign-in
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await saveUserToFirestore(userCredential.user!.uid, {
          'email': userCredential.user!.email,
          'displayName': userCredential.user!.displayName,
          'photoURL': userCredential.user!.photoURL,
          'provider': 'google',
          'createdAt': DateTime.now().toIso8601String(),
          'isEmailVerified': true,
        });
      }

      return userCredential;
    } catch (e) {
      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }

  // Apple Sign In (iOS only)
  Future<UserCredential?> signInWithApple() async {
    try {
      if (!Platform.isIOS) {
        throw Exception('Apple Sign In is only available on iOS devices');
      }

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);

      if (userCredential.additionalUserInfo?.isNewUser == true) {
        String? displayName;
        if (appleCredential.givenName != null || appleCredential.familyName != null) {
          displayName = '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
        }

        await saveUserToFirestore(userCredential.user!.uid, {
          'email': userCredential.user!.email,
          'displayName': displayName ?? userCredential.user!.displayName,
          'provider': 'apple',
          'createdAt': DateTime.now().toIso8601String(),
          'isEmailVerified': true,
        });
      }

      return userCredential;
    } catch (e) {
      throw Exception('Apple sign-in failed: ${e.toString()}');
    }
  }

  // Facebook Sign In
  Future<UserCredential?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        final OAuthCredential facebookAuthCredential =
        FacebookAuthProvider.credential(result.accessToken!.tokenString);

        final UserCredential userCredential = await _auth.signInWithCredential(facebookAuthCredential);

        if (userCredential.additionalUserInfo?.isNewUser == true) {
          await saveUserToFirestore(userCredential.user!.uid, {
            'email': userCredential.user!.email,
            'displayName': userCredential.user!.displayName,
            'photoURL': userCredential.user!.photoURL,
            'provider': 'facebook',
            'createdAt': DateTime.now().toIso8601String(),
            'isEmailVerified': true,
          });
        }

        return userCredential;
      } else if (result.status == LoginStatus.cancelled) {
        return null;
      } else {
        throw Exception('Facebook sign-in failed: ${result.message}');
      }
    } catch (e) {
      throw Exception('Facebook sign-in failed: ${e.toString()}');
    }
  }

  // Sign out from all providers
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      await FacebookAuth.instance.logOut();
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  // Generate random OTP (5-digit)
  String _generateOTP() {
    Random random = Random();
    return (10000 + random.nextInt(90000)).toString();
  }

  // NEW: Send OTP via EmailJS with detailed error logging
  Future<String> sendOTPViaEmailJS(String email, {String? userName}) async {
    try {
      String otp = _generateOTP();

      // Store OTP in Firestore first
      await storeTemporaryOTP(email, otp);

      final emailData = {
        'service_id': _emailJSServiceId,
        'template_id': _emailJSTemplateId,
        'user_id': _emailJSPublicKey,
        'template_params': {
          'to_email': email,
          'to_name': userName ?? email.split('@')[0],
          'otp_code': otp,
          'expiry_time': '10 minutes',
        },
      };

      print('Sending email with data: ${jsonEncode(emailData)}'); // Debug log

      final response = await http.post(
        Uri.parse(_emailJSApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(emailData),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Email sending timed out. Please try again.');
        },
      );

      print('EmailJS Response Status: ${response.statusCode}'); // Debug log
      print('EmailJS Response Body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        print('OTP email sent successfully to $email');
        return otp;
      } else {
        await deleteTemporaryOTP(email);

        String errorMessage = 'Failed to send email. Status: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage += ' - ${errorData['message']}';
          }
        } catch (e) {
          errorMessage += ' - ${response.body}';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      print('EmailJS Error: $e'); // Debug log

      try {
        await deleteTemporaryOTP(email);
      } catch (_) {}

      if (e.toString().contains('timeout')) {
        throw Exception('Email sending timed out. Please check your internet connection.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception('Failed to send OTP email: ${e.toString()}');
      }
    }
  }

  // Send OTP via Cloud Function (fallback)
  Future<String> sendOTPViaCloudFunction(String email) async {
    try {
      String otp = _generateOTP();
      await storeTemporaryOTP(email, otp);

      HttpsCallable callable = _functions.httpsCallable('sendOTPEmail');
      final result = await callable.call({'email': email, 'otp': otp});

      if (result.data['success']) {
        return otp;
      } else {
        throw Exception('Failed to send email: ${result.data['error'] ?? 'Unknown error'}');
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Cloud function error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to send OTP: ${e.toString()}');
    }
  }

  // Store temporary OTP
  Future<void> storeTemporaryOTP(String email, String otp) async {
    try {
      await _firestore.collection('temp_otps').doc(email).set({
        'otp': otp,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      });
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          throw Exception('Permission denied. Please check your Firestore security rules.');
        case 'unavailable':
          throw Exception('Firestore service is temporarily unavailable.');
        case 'deadline-exceeded':
          throw Exception('Request timed out. Please try again.');
        default:
          throw Exception('Failed to store OTP: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to store OTP: ${e.toString()}');
    }
  }

  // Verify OTP
  Future<bool> verifyOTP(String email, String enteredOTP) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('temp_otps').doc(email).get();

      if (!doc.exists) {
        throw Exception('No verification code found for this email');
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String storedOTP = data['otp'];
      int expiresAt = data['expiresAt'];

      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        await deleteTemporaryOTP(email);
        throw Exception('Verification code has expired');
      }

      return storedOTP == enteredOTP;
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          throw Exception('Permission denied. Please check your Firestore security rules.');
        case 'unavailable':
          throw Exception('Firestore service is temporarily unavailable.');
        case 'deadline-exceeded':
          throw Exception('Request timed out. Please try again.');
        default:
          throw Exception('Failed to verify OTP: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to verify OTP: ${e.toString()}');
    }
  }

  // Delete temporary OTP
  Future<void> deleteTemporaryOTP(String email) async {
    try {
      await _firestore.collection('temp_otps').doc(email).delete();
    } catch (e) {
      print('Warning: Failed to delete temporary OTP: $e');
    }
  }

  // Resend OTP
  Future<void> resendOTP(String email, {String? userName}) async {
    try {
      await sendOTPViaEmailJS(email, userName: userName);
      print('OTP resent successfully to $email');
    } catch (e) {
      throw Exception('Failed to resend OTP: ${e.toString()}');
    }
  }

  // Save user data
  Future<void> saveUserToFirestore(String uid, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('users').doc(uid).set(userData, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          throw Exception('Permission denied. Please check your Firestore security rules.');
        case 'unavailable':
          throw Exception('Firestore service is temporarily unavailable.');
        case 'deadline-exceeded':
          throw Exception('Request timed out. Please try again.');
        default:
          throw Exception('Failed to save user data: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to save user data: ${e.toString()}');
    }
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserFromFirestore(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user data: ${e.toString()}');
    }
  }

  // Update user data
  Future<void> updateUserInFirestore(String uid, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(uid).update(updates);
    } catch (e) {
      throw Exception('Failed to update user data: ${e.toString()}');
    }
  }

  // Check if email is registered
  Future<bool> isEmailRegistered(String email) async {
    try {
      List<String> signInMethods = await _auth.fetchSignInMethodsForEmail(email);
      return signInMethods.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Cleanup expired OTPs
  Future<void> cleanupExpiredOTPs() async {
    try {
      QuerySnapshot query = await _firestore
          .collection('temp_otps')
          .where('expiresAt', isLessThan: DateTime.now().millisecondsSinceEpoch)
          .get();

      if (query.docs.isEmpty) return;

      WriteBatch batch = _firestore.batch();
      for (QueryDocumentSnapshot doc in query.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('Cleaned up ${query.docs.length} expired OTPs');
    } catch (e) {
      print('Failed to cleanup expired OTPs: ${e.toString()}');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Failed to send reset email: ${e.toString()}');
    }
  }

  // Simple connectivity check
  Future<bool> hasNetworkConnection() async {
    try {
      await _firestore.doc('test/connection').get();
      return true;
    } catch (_) {
      return false;
    }
  }
}
