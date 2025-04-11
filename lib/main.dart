import 'package:flutter/material.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'signup_page.dart';
import 'internship_page.dart';
import 'jobs_page.dart'; // Import Jobs Page
import 'discussion_board_page.dart'; // Import Discussion Board Page
import 'placement_record_page.dart'; // Import Placement Records Page
import 'company_jobs_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Placement Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Color(0xFF2196F3),
        secondaryHeaderColor: Color(0xFF1976D2),
        scaffoldBackgroundColor: Colors.grey[100],
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
      home: AuthenticationWrapper(),
      routes: {
        '/welcome': (context) => WelcomePage(),
        '/login': (context) => LoginPage(),
        '/home': (context) => HomePage(),
        '/signup': (context) => SignUpPage(),
        '/internships': (context) => InternshipPage(),
        '/jobs': (context) => JobListingPage(), // Add Jobs Page route
        '/discussion-board': (context) =>
            DiscussionBoardPage(), // Add Discussion Board route
        '/placement-records': (context) =>
            PlacementRecordsPage(), // Add Placement Records route
       '/company-page': (context) {
  final auth = FirebaseAuth.instance.currentUser;
  if (auth != null) {
    return CompanyJobsPage(companyId: auth.uid);
  } else {
    return LoginPage(); // Redirect to login if not authenticated
  }
},
      },
     
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        // If the snapshot has user data, then they're already signed in
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              // Check if the user document exists and has user type data
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                final userType = userData?['userType'] as String?;
                
                print('User type in AuthWrapper: $userType'); // Add this for debugging
                
                if (userType == 'Company') {
                  return CompanyJobsPage(companyId: 'default_company_id');


                } else {
                  return HomePage();
                }
              }
              
              // Default to HomePage if no specific user type found
              return HomePage();
            },
          );
        }
        
        // If the user is not signed in, show the welcome page
        return WelcomePage();
      },
    );
  }
}

class WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[400]!, Colors.blue[800]!],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.school,
                    size: 80,
                    color: Colors.white,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Welcome to\nPlacement Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your Gateway to Career Opportunities',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue[800],
                      minimumSize: Size(250, 50),
                    ),
                    child: Text(
                      'Get Started',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Already have an account? Sign In',
                      style: TextStyle(fontSize: 16),
                    ),
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