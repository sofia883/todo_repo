import 'package:to_do_app/common_imports.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await LocalStorageService.init(); // Make sure this method exists

  // Enable offline persistence
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Check if user is authenticated
          if (snapshot.hasData) {
            // Check if it's a first-time login
            return FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (context, prefsSnapshot) {
                if (prefsSnapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final hasSeenWelcome =
                    prefsSnapshot.data?.getBool('has_seen_welcome') ?? false;
                if (!hasSeenWelcome) {
                  // First time login, show welcome page
                  prefsSnapshot.data?.setBool('has_seen_welcome', true);
                  return WelcomePage();
                } else {
                  // Returning user, show home page
                  return HomePage();
                }
              },
            );
          }

          // User is not authenticated, show login page
          return LoginPage();
        },
      ),
      routes: {
        '/login': (context) => LoginPage(),
        '/welcome': (context) => WelcomePage(),
        '/register': (context) => SignupPage(),
        '/home': (context) => HomePage(),
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
}
