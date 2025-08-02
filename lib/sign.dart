import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'Home/homepage.dart';
import 'login.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance; // Firestore instance
  final _formKey = GlobalKey<FormState>();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nameController = TextEditingController();

  bool isLoading = false;
  bool isGoogleLoading = false;

  // Custom toast method matching your app's theme
  void showToast(String message, {bool isSuccess = true}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.TOP,
      timeInSecForIosWeb: 3,
      backgroundColor: isSuccess ? Color(0xFFD4FF47) : Colors.red,
      textColor: isSuccess ? Color(0xFF1A1A1A) : Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> signup() async {
    print("Signup button pressed"); // Debug print

    if (_formKey.currentState!.validate()) {
      print("Form validation passed"); // Debug print
      setState(() => isLoading = true);

      try {
        print("Attempting to create user with email: ${emailController.text.trim()}"); // Debug print

        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        User? user = userCredential.user;
        if (user != null) {
          print("User created successfully: ${user.uid}"); // Debug print

          // Update the user's display name in Firebase Auth (optional)
          await user.updateDisplayName(nameController.text.trim());

          // Store user details in Firestore
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'name': nameController.text.trim(),
            'email': emailController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(), // Timestamp of creation
          });
          print("User data stored in Firestore for email signup.");
        }


        showToast("Account created successfully! Welcome aboard", isSuccess: true);

        print("About to navigate to HomePage"); // Debug print

        // Navigate to homepage after successful signup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );

        print("Navigation completed"); // Debug print

      } on FirebaseAuthException catch (e) {
        print("FirebaseAuthException: ${e.code} - ${e.message}"); // Debug print
        String errorMessage = "Signup failed";
        switch (e.code) {
          case 'weak-password':
            errorMessage = "Password is too weak";
            break;
          case 'email-already-in-use':
            errorMessage = "Email is already registered";
            break;
          case 'invalid-email':
            errorMessage = "Invalid email address";
            break;
          default:
            errorMessage = e.message ?? "Signup failed";
        }
        showToast(errorMessage, isSuccess: false);
      } on PlatformException catch (e) { // Added PlatformException handling
        print("PlatformException: ${e.code} - ${e.message}"); // Debug print
        String errorMessage = 'An unexpected platform error occurred.';
        switch (e.code) {
          case 'network_request_failed':
            errorMessage = 'Network error. Please check your internet connection.';
            break;
          case 'ERROR_CANCELED_BY_USER': // Common for some auth flows if user cancels system prompt
            errorMessage = 'Sign-up cancelled.';
            break;
          default:
            errorMessage = e.message ?? 'An unexpected error occurred.';
        }
        showToast(errorMessage, isSuccess: false);
      }
      catch (e) {
        print("General Exception: $e"); // Debug print
        showToast("An unexpected error occurred: ${e.toString()}", isSuccess: false);
      } finally {
        setState(() => isLoading = false);
      }
    } else {
      print("Form validation failed"); // Debug print
      showToast("Please fill all fields correctly", isSuccess: false);
    }
  }


  Future<void> signUpWithGoogle() async {
    setState(() => isGoogleLoading = true);
    try {
      await _googleSignIn.signOut(); // Ensure a clean sign-in
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => isGoogleLoading = false);
        return; // User cancelled the Google sign-in
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // Store user details in Firestore. Use `set` with `merge: true`
        // to update if the document already exists (e.g., user signed up with email first)
        // or create if it's a new user.
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? googleUser.displayName, // Prefer Firebase Auth display name, fallback to GoogleSignInAccount
          'email': user.email ?? googleUser.email, // Prefer Firebase Auth email, fallback to GoogleSignInAccount
          'photoURL': user.photoURL, // Store Google profile picture URL
          'createdAt': FieldValue.serverTimestamp(), // Timestamp of creation/first sign-in
        }, SetOptions(merge: true)); // Use merge to avoid overwriting existing data if user already exists
        print("User data stored/updated in Firestore for Google signup.");
      }

      showToast("Google Sign-Up Successful! Welcome", isSuccess: true);

      // Navigate to homepage after successful Google signup
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Google sign-up failed";
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = "Account already exists with different sign-in method";
          break;
        case 'invalid-credential':
          errorMessage = "Invalid Google credentials";
          break;
        default:
          errorMessage = e.message ?? "Authentication failed";
      }
      showToast(errorMessage, isSuccess: false);
    } on PlatformException catch (e) {
      String errorMessage = 'Google sign-up failed';
      switch (e.code) {
        case 'sign_in_failed':
          errorMessage = 'Google sign-up configuration error';
          break;
        case 'network_error':
          errorMessage = 'Network error. Please check connection';
          break;
        default:
          errorMessage = e.message ?? 'Google sign-up failed';
      }
      showToast(errorMessage, isSuccess: false);
    } catch (e) {
      showToast("An unexpected error occurred", isSuccess: false);
    } finally {
      setState(() => isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A1A1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 40),

                // Header
                Center(
                  child: Column(
                    children: [
                      Text(
                        "Create Account",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Join us and start your journey",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 50),

                // Google Sign Up Button
                Container(
                  width: double.infinity,
                  height: 56,
                  child: isGoogleLoading
                      ? Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4FF47)),
                        ),
                      ),
                    ),
                  )
                      : ElevatedButton.icon(
                    onPressed: signUpWithGoogle,
                    icon: Icon(Icons.login, color: Colors.white, size: 20),
                    label: Text(
                      "Continue with Google",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2A2A2A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Color(0xFF3A3A3A), width: 1),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 30),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Color(0xFF3A3A3A),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "OR",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Color(0xFF3A3A3A),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 30),

                // Name Field
                _buildInputField(
                  controller: nameController,
                  label: "Name",
                  icon: Icons.person_outline,
                  validator: (value) => value!.isEmpty ? "Enter your name" : null,
                ),

                SizedBox(height: 20),

                // Email Field
                _buildInputField(
                  controller: emailController,
                  label: "Email",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value!.isEmpty) return "Enter your email";
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return "Enter a valid email";
                    }
                    return null;
                  },
                ),

                SizedBox(height: 20),

                // Password Field
                _buildInputField(
                  controller: passwordController,
                  label: "Password",
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: (value) => value!.length < 6
                      ? "Password must be at least 6 characters"
                      : null,
                ),

                SizedBox(height: 40),

                // Sign Up Button
                Container(
                  width: double.infinity,
                  height: 56,
                  child: isLoading
                      ? Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFD4FF47),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
                        ),
                      ),
                    ),
                  )
                      : ElevatedButton(
                    onPressed: signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFD4FF47),
                      foregroundColor: Color(0xFF1A1A1A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 30),

                // Login Link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => LoginPage()),
                          );
                        },
                        child: Text(
                          "Login here",
                          style: TextStyle(
                            color: Color(0xFFD4FF47),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF3A3A3A), width: 1),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.grey[400],
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
        cursorColor: Color(0xFFD4FF47),
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