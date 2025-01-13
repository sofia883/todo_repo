// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:to_do_app/data/user_model.dart';

// class AuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final GoogleSignIn _googleSignIn = GoogleSignIn();

//   // Get current user
//   User? get currentUser => _auth.currentUser;

//   // Sign in with email and password
//   Future<UserCredential> signInWithEmail(String email, String password) async {
//     try {
//       UserCredential result = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       await _createUserDocument(result.user!);
//       return result;
//     } catch (e) {
//       throw e;
//     }
//   }

//   // Sign up with email and password
//   Future<UserCredential> signUpWithEmail(String email, String password, String name) async {
//     try {
//       UserCredential result = await _auth.createUserWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
      
//       // Create user document in Firestore
//       await _createUserDocument(result.user!, name: name);
//       return result;
//     } catch (e) {
//       throw e;
//     }
//   }

//   // Sign in with Google
//   Future<UserCredential> signInWithGoogle() async {
//     try {
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//       if (googleUser == null) throw 'Google Sign In cancelled';

//       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
//       final credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );

//       UserCredential result = await _auth.signInWithCredential(credential);
//       await _createUserDocument(result.user!);
//       return result;
//     } catch (e) {
//       throw e;
//     }
//   }

//   // Create user document in Firestore
//   Future<void> _createUserDocument(User user, {String? name}) async {
//     DocumentReference userDoc = _firestore.collection('users').doc(user.uid);
    
//     if (!(await userDoc.get()).exists) {
//       UserModel userData = UserModel(
//         uid: user.uid,
//         email: user.email!,
//         name: name ?? user.displayName,
//         photoUrl: user.photoURL,
//       );
//       await userDoc.set(userData.toMap());
//     }
//   }

//   // Sign out
//   Future<void> signOut() async {
//     await _googleSignIn.signOut();
//     await _auth.signOut();
//   }
// }