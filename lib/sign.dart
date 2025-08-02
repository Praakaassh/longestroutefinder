import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'Home/homepage.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nameController = TextEditingController();

  bool isLoading = false;
  bool isGoogleLoading = false;

  Future<void> signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);

      try {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'createdAt': DateTime.now(),
          'signInMethod': 'email',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Signup Successful!")),
        );

        // Navigate to home page after successful signup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );

      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Signup failed")),
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> signUpWithGoogle() async {
    setState(() => isGoogleLoading = true);

    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': userCredential.user!.displayName ?? 'Google User',
          'email': userCredential.user!.email ?? '',
          'photoURL': userCredential.user!.photoURL ?? '',
          'createdAt': DateTime.now(),
          'signInMethod': 'google',
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-Up Successful!")),
      );

      // Navigate to home page after successful Google signin
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );

    } on PlatformException catch (e) {
      print('PlatformException: ${e.code} - ${e.message}');
      String errorMessage = 'Google sign-in failed';

      switch (e.code) {
        case 'sign_in_failed':
          errorMessage = 'Google sign-in configuration error. Please check your setup.';
          break;
        case 'network_error':
          errorMessage = 'Network error. Please check your connection.';
          break;
        default:
          errorMessage = e.message ?? 'Google sign-in failed';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Authentication failed")),
      );
    } catch (e) {
      print('General Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An unexpected error occurred")),
      );
    } finally {
      setState(() => isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Create Account",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 30),

                  // Google Sign Up Button
                  isGoogleLoading
                      ? CircularProgressIndicator()
                      : OutlinedButton.icon(
                    onPressed: signUpWithGoogle,
                    icon: Icon(Icons.login, color: Colors.red),
                    label: Text("Continue with Google"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      side: BorderSide(color: Colors.grey),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(thickness: 1)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text("OR", style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider(thickness: 1)),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Email Form Fields
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Name",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => value!.isEmpty ? "Enter your name" : null,
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value!.isEmpty) return "Enter your email";
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return "Enter a valid email";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) => value!.length < 6
                        ? "Password must be at least 6 characters" : null,
                  ),
                  SizedBox(height: 30),

                  // Email Sign Up Button
                  isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: signup,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text("Sign Up with Email"),
                  ),

                  SizedBox(height: 20),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account? "),
                      TextButton(
                        onPressed: () {
                          // Navigate to login page
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: Text("Login here"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }
}