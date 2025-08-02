import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tinderprojecthub/sign.dart';
import 'Home/homepage.dart';

// import other necessary files

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Auth Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/signup',
      routes: {
        '/signup': (context) => SignupPage(),
        '/home': (context) => HomePage(),
        // Add other routes as needed
      },
    );
  }
}
