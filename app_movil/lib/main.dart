import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_services//auth_provider.dart';
import 'screens/auth_screens//login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mi Aplicación',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
