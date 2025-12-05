import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'dart:io';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

  // Check if email is registered (using safer approach)
  Future<bool> isEmailRegistered(String email) async {
    try {
      // Try to create a temporary user - if email exists, it will throw email-already-in-use
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: 'temp_password_for_check'
      );
      // If we get here, email is not registered, delete the temp user
      await _auth.currentUser?.delete();
      return false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return true;
      }
      return false;
    } catch (_) {
      return false;
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