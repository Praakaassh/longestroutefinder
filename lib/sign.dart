import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nameController = TextEditingController();

  bool isLoading = false;

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
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Signup Successful!")),
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
                  Text("Signup", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  SizedBox(height: 30),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: "Name", border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? "Enter your name" : null,
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? "Enter your email" : null,
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                    validator: (value) => value!.length < 6 ? "Password must be at least 6 chars" : null,
                  ),
                  SizedBox(height: 30),
                  isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: signup,
                    style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                    child: Text("Sign Up"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
