import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_scaffold.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/recipe_detail_page.dart';
import 'screens/add_edit_recipe_page.dart';

class Config {
  static String get supabaseUrl => 'https://htwnocisxgarrpzxravc.supabase.co';
  static String get supabaseAnonKey => 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh0d25vY2lzeGdhcnJwenhyYXZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg0MTA3MzgsImV4cCI6MjA3Mzk4NjczOH0.SgqKYl1m5qJ8DYTupgp4BlsJkWsp2NY1zHP-2VPw0oU';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: Config.supabaseUrl,
    anonKey: Config.supabaseAnonKey,
  );

  // Check if the user is already logged in using SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recipe App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: isLoggedIn ? '/' : '/login',
      routes: {
        '/': (context) => MainScaffold(),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/recipe_detail': (context) => RecipeDetailPage(),
        '/edit_recipe': (context) => AddEditRecipePage(),
      },
    );
  }
}
