import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:placement/company_jobs_page.dart';
import 'dart:math'; // Adjust import as needed

class CaptchaWidget extends StatefulWidget {
  final Function(bool) onValidationChanged;

  const CaptchaWidget({Key? key, required this.onValidationChanged})
      : super(key: key);

  @override
  _CaptchaWidgetState createState() => _CaptchaWidgetState();
}

class _CaptchaWidgetState extends State<CaptchaWidget> {
  late String _captchaText;
  final _captchaController = TextEditingController();
  String? _captchaError;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _generateCaptcha();
  }

  void _generateCaptcha() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    _captchaText =
        List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
    _captchaController.clear();
    _captchaError = null;
    _isValid = false;
    widget.onValidationChanged(false);
  }

  void _validateCaptcha(String value) {
    if (_isValid != (value.toUpperCase() == _captchaText)) {
      _isValid = value.toUpperCase() == _captchaText;
      widget.onValidationChanged(_isValid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _captchaText,
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _captchaController,
                decoration: InputDecoration(
                  labelText: 'Enter Captcha',
                  hintText: 'Enter the text above',
                  prefixIcon: Icon(Icons.security),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  errorText: _captchaError,
                ),
                onChanged: _validateCaptcha,
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _generateCaptcha();
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _captchaController.dispose();
    super.dispose();
  }
}

class LoginPage extends StatefulWidget {
  final String? userType;

  const LoginPage({Key? key, this.userType}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _firebaseError;
  bool _isCaptchaValid = false;
  String userId = '';

  // Firebase auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    if (widget.userType != null) {
      print('User type received from signup: ${widget.userType}');
      // You can use the userType here if needed
    }
  }

  bool _validateEmail(String email) {
    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required');
      return false;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _emailError = 'Please enter a valid email address');
      return false;
    }
    setState(() => _emailError = null);
    return true;
  }

  bool _validatePassword(String password) {
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      return false;
    }
    if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      return false;
    }
    setState(() => _passwordError = null);
    return true;
  }

  void _handleCaptchaValidation(bool isValid) {
    if (_isCaptchaValid != isValid) {
      setState(() {
        _isCaptchaValid = isValid;
      });
    }
  }

  Future<void> _loginUser() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validate all fields
    final isEmailValid = _validateEmail(email);
    final isPasswordValid = _validatePassword(password);

    if (!isEmailValid || !isPasswordValid || !_isCaptchaValid) {
      if (!_isCaptchaValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please complete the captcha correctly')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _firebaseError = null;
    });

    try {
      // Show loading indicator with message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Signing in...'),
            ],
          ),
          duration: Duration(seconds: 60), // Long duration as we'll dismiss it manually
        ),
      );

      // Sign in with email and password
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Get the user ID
      String userId = userCredential.user!.uid;
      
      // Fetch user data from Firestore to get the user type
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      // Dismiss the loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        final userType = userData?['userType'] as String? ?? 'Student';
        
        print('User type from Firestore: $userType');
        
        // Navigate based on user type
        if (userType == 'Company') {
          print('Company user detected, navigating to company page');
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/company-page',
            (route) => false,
          );
        } else {
          print('Student user, navigating to home page');
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
        }
      } else {
        // If user document doesn't exist, fallback to email check
        if (email.toLowerCase() == "tcs@gmail.com") {
          print('TCS email detected, navigating to company page');
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/company-page',
            (route) => false,
          );
        } else {
          print('Standard user, navigating to home page');
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      // Hide any loading snackbars
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      String errorMessage = 'An error occurred. Please try again.';

      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please provide a valid email address.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        errorMessage =
            'Too many failed login attempts. Please try again later.';
      }

      setState(() {
        _firebaseError = errorMessage;
        _isLoading = false;
      });
    } catch (e) {
      // Hide any loading snackbars
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      setState(() {
        _firebaseError = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _navigateToSignUp() {
    Navigator.pushNamed(context, '/signup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue[400]!, Colors.blue[800]!],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(height: 32),
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  if (widget.userType != null) ...[
                    SizedBox(height: 8),
                    Text(
                      'You signed up as a ${widget.userType}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                  SizedBox(height: 48),
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            errorText: _emailError,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) {
                            if (_emailError != null) {
                              setState(() => _emailError = null);
                            }
                          },
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            errorText: _passwordError,
                          ),
                          obscureText: true,
                          onChanged: (value) {
                            if (_passwordError != null) {
                              setState(() => _passwordError = null);
                            }
                          },
                        ),
                        SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              // Handle forgot password
                              _showForgotPasswordDialog();
                            },
                            child: Text('Forgot Password?'),
                          ),
                        ),
                        SizedBox(height: 16),
                        CaptchaWidget(
                          onValidationChanged: _handleCaptchaValidation,
                        ),
                        if (_firebaseError != null) ...[
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _firebaseError!,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: 24),
                        _isLoading
                            ? CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: _isCaptchaValid ? _loginUser : null,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size(double.infinity, 50),
                                  backgroundColor: _isCaptchaValid
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey,
                                ),
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                      ],
                    ),
                  ),
                  Spacer(),
                  Center(
                    child: TextButton(
                      onPressed: _navigateToSignUp,
                      child: Text(
                        'Don\'t have an account? Sign up',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
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

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Enter your email address to receive a password reset link.'),
              SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  try {
                    await FirebaseAuth.instance
                        .sendPasswordResetEmail(email: email);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Password reset email sent')),
                    );
                  } on FirebaseAuthException catch (e) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message ?? 'An error occurred')),
                    );
                  }
                }
              },
              child: Text('Send Link'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
