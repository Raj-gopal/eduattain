import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: "AIzaSyCrf_AzV43ny6JFDxaFys9gTPHbMYZ0UH8",
        authDomain: "eduattain-316cd.firebaseapp.com",
        projectId: "eduattain-316cd",
        storageBucket: "eduattain-316cd.firebasestorage.app",
        messagingSenderId: "678260640894",
        appId: "1:678260640894:web:a4140d30bfc0cc2326dc2f"
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OBE System',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
