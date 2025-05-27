import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin_screen.dart';

import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  // Initialize Supabase
  await Supabase.initialize(
    url: StorageService.supabaseUrl,
    anonKey: StorageService.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Auth Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize auth state
    Future.microtask(
        () => Provider.of<AuthProvider>(context, listen: false).initialize());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        // Role-based routing
        final userRole = auth.user?['role'] as String?;
        if (userRole == 'admin') {
          return const AdminScreen();
        } else {
          return const HomeScreen();
        }
      },
    );
  }
}


// static const String SUPABASE_URL = 'https://qhouwszsjarppmdvgcof.supabase.co';
// static const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFob3V3c3pzamFycHBtZHZnY29mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4NTYyMTksImV4cCI6MjA2MzQzMjIxOX0._be1TC983Bcpwlu_mAnEeDV2GlxYLeLsfRL7YKG4CdM';
// static const String ml = 'ml';
// API_URI => 'http://192.168.3.189:5000/api';