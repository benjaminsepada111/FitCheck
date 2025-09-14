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
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Save user data to Firestore if it's a new user
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

      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create OAuth credential
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);

      // Save user data to Firestore if it's a new user
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
      // Trigger the sign-in flow
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        // Create a credential from the access token
        final OAuthCredential facebookAuthCredential =
        FacebookAuthProvider.credential(result.accessToken!.tokenString);

        // Sign in to Firebase with the Facebook credential
        final UserCredential userCredential = await _auth.signInWithCredential(facebookAuthCredential);

        // Save user data to Firestore if it's a new user
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
        return null; // User cancelled
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
      // Sign out from Firebase
      await _auth.signOut();

      // Sign out from Google
      await _googleSignIn.signOut();

      // Sign out from Facebook
      await FacebookAuth.instance.logOut();

    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  // Generate random OTP
  String _generateOTP() {
    Random random = Random();
    return (10000 + random.nextInt(90000)).toString();
  }

  // Send OTP via Cloud Function (Recommended approach) - Fixed method
  Future<String> sendOTPViaCloudFunction(String email) async {
    try {
      String otp = _generateOTP();

      // Store OTP in Firestore first
      await storeTemporaryOTP(email, otp);

      // Call Cloud Function to send email
      HttpsCallable callable = _functions.httpsCallable('sendOTPEmail');
      final result = await callable.call({
        'email': email,
        'otp': otp,
      });

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

  // Alternative: Send OTP via HTTP endpoint - Fixed method
  Future<String> sendOTPViaHTTP(String email) async {
    try {
      String otp = _generateOTP();

      // Store OTP in Firestore first
      await storeTemporaryOTP(email, otp);

      // Replace with your actual Cloud Function URL
      const String functionUrl = 'https://your-region-your-project.cloudfunctions.net/sendOTP';

      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return otp;
        } else {
          throw Exception('API error: ${data['error'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to send OTP: ${e.toString()}');
    }
  }

  // Store temporary OTP in Firestore with improved error handling
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

  // Verify OTP with improved error handling
  Future<bool> verifyOTP(String email, String enteredOTP) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('temp_otps').doc(email).get();

      if (!doc.exists) {
        throw Exception('No verification code found for this email');
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String storedOTP = data['otp'];
      int expiresAt = data['expiresAt'];

      // Check if OTP has expired
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        // Clean up expired OTP
        await deleteTemporaryOTP(email);
        throw Exception('Verification code has expired');
      }

      // Verify OTP
      bool isValid = storedOTP == enteredOTP;

      // If valid, keep the OTP for account creation, otherwise clean up
      if (!isValid) {
        // Don't delete immediately on failure to prevent brute force
        // Consider implementing rate limiting here
      }

      return isValid;
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

  // Delete temporary OTP with error handling
  Future<void> deleteTemporaryOTP(String email) async {
    try {
      await _firestore.collection('temp_otps').doc(email).delete();
    } on FirebaseException catch (e) {
      // Don't throw error for delete operations in cleanup
      print('Warning: Failed to delete temporary OTP: ${e.message}');
    } catch (e) {
      print('Warning: Failed to delete temporary OTP: ${e.toString()}');
    }
  }

  // Fixed resend OTP method
  Future<void> resendOTP(String email) async {
    try {
      // Generate new OTP
      String newOTP = _generateOTP();

      // Store new OTP (this will overwrite the old one)
      await storeTemporaryOTP(email, newOTP);

      // In production, implement actual email sending here
      // For now, just simulate the process
      print('New OTP for $email: $newOTP'); // Remove in production

      // If you have Cloud Functions set up, use this instead:
      // await sendOTPViaCloudFunction(email);
    } catch (e) {
      throw Exception('Failed to resend OTP: ${e.toString()}');
    }
  }

  // Save user data to Firestore with improved error handling
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

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserFromFirestore(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } on FirebaseException catch (e) {
      throw Exception('Failed to get user data: ${e.message}');
    } catch (e) {
      throw Exception('Failed to get user data: ${e.toString()}');
    }
  }

  // Update user data in Firestore
  Future<void> updateUserInFirestore(String uid, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(uid).update(updates);
    } on FirebaseException catch (e) {
      throw Exception('Failed to update user data: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update user data: ${e.toString()}');
    }
  }

  // Check if email exists in Firebase Auth with improved error handling
  Future<bool> isEmailRegistered(String email) async {
    try {
      List<String> signInMethods = await _auth.fetchSignInMethodsForEmail(email);
      return signInMethods.isNotEmpty;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        case 'network-request-failed':
          throw Exception('Network error. Please check your internet connection.');
        default:
        // For other errors, assume email is not registered
          return false;
      }
    } catch (e) {
      // For unknown errors, assume email is not registered
      return false;
    }
  }

  // Clean up expired OTPs (call this periodically or on app start)
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

  // Reset password with improved error handling
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        case 'user-not-found':
          throw Exception('No user found for this email address.');
        case 'network-request-failed':
          throw Exception('Network error. Please check your internet connection.');
        default:
          throw Exception('Failed to send reset email: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to send reset email: ${e.toString()}');
    }
  }

  // Helper method to check network connectivity (you may want to implement this)
  Future<bool> hasNetworkConnection() async {
    try {
      // Simple connectivity check - you might want to use a connectivity package
      await _firestore.doc('test/connection').get();
      return true;
    } catch (e) {
      return false;
    }
  }
}