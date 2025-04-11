import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _firebaseError;
  String _userType = 'Student'; // Default selection

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _validateName(String name) {
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return false;
    }
    if (name.length < 2) {
      setState(() => _nameError = 'Name must be at least 2 characters');
      return false;
    }
    setState(() => _nameError = null);
    return true;
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

  bool _validateConfirmPassword(String confirmPassword) {
    if (confirmPassword.isEmpty) {
      setState(() => _confirmPasswordError = 'Please confirm your password');
      return false;
    }
    if (confirmPassword != _passwordController.text) {
      setState(() => _confirmPasswordError = 'Passwords do not match');
      return false;
    }
    setState(() => _confirmPasswordError = null);
    return true;
  }

 Future<void> _signUpUser() async {
  final name = _nameController.text.trim();
  final email = _emailController.text.trim();
  final password = _passwordController.text;
  final confirmPassword = _confirmPasswordController.text;

  // Validate all fields
  final isNameValid = _validateName(name);
  final isEmailValid = _validateEmail(email);
  final isPasswordValid = _validatePassword(password);
  final isConfirmPasswordValid = _validateConfirmPassword(confirmPassword);

  if (!isNameValid || !isEmailValid || !isPasswordValid || !isConfirmPasswordValid) {
    return;
  }

  setState(() {
    _isLoading = true;
    _firebaseError = null;
  });

  try {
    // Show loading indicator
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
            Text('Creating account...'),
          ],
        ),
        duration: Duration(seconds: 60), // Long duration as we'll dismiss it manually
      ),
    );

    // Create user with email and password
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Store additional user information in Firestore
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'name': name,
      'email': email,
      'userType': _userType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update display name in Firebase Auth
    await userCredential.user!.updateDisplayName(name);
    
    // Dismiss the loading snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Account created successfully!'),
        duration: Duration(seconds: 2),
      ),
    );
    
    // Add a small delay to ensure Firestore write is complete
    await Future.delayed(Duration(seconds: 1));
    
    // Navigate based on user type with a print statement for debugging
    print('Navigating user with type: $_userType');
    
    if (_userType == 'Company') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/company-page',
        (route) => false,
      );
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
      );
    }
  } on FirebaseAuthException catch (e) {
    // Dismiss the loading snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    String errorMessage = 'An error occurred. Please try again.';
    
    if (e.code == 'weak-password') {
      errorMessage = 'The password provided is too weak.';
    } else if (e.code == 'email-already-in-use') {
      errorMessage = 'An account already exists for that email.';
    } else if (e.code == 'invalid-email') {
      errorMessage = 'Please provide a valid email address.';
    }
    
    setState(() {
      _firebaseError = errorMessage;
    });
  } catch (e) {
    // Dismiss the loading snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    print('Error during signup: $e'); // Add this for debugging
    
    setState(() {
      _firebaseError = 'An error occurred. Please try again.';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  Widget _buildUserTypeSelector() {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _userType = 'Student'),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _userType == 'Student' ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school,
                      color: _userType == 'Student' ? Colors.white : Colors.grey,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Student',
                      style: TextStyle(
                        color: _userType == 'Student' ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _userType = 'Company'),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _userType == 'Company' ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.business,
                      color: _userType == 'Company' ? Colors.white : Colors.grey,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Company',
                      style: TextStyle(
                        color: _userType == 'Company' ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Rest of the code remains the same
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
                    'Create Account',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sign up to get started',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
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
                        _buildUserTypeSelector(),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: _userType == 'Company' ? 'Company Name' : 'Full Name',
                            hintText: _userType == 'Company' ? 'Enter company name' : 'Enter your full name',
                            prefixIcon: Icon(_userType == 'Company' ? Icons.business : Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            errorText: _nameError,
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                          ),
                          onChanged: (value) {
                            if (_nameError != null) {
                              setState(() => _nameError = null);
                            }
                          },
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: _userType == 'Company' ? 'Enter company email' : 'Enter your email',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            errorText: _emailError,
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red),
                            ),
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
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                          ),
                          obscureText: true,
                          onChanged: (value) {
                            if (_passwordError != null) {
                              setState(() => _passwordError = null);
                            }
                          },
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            hintText: 'Confirm your password',
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            errorText: _confirmPasswordError,
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                          ),
                          obscureText: true,
                          onChanged: (value) {
                            if (_confirmPasswordError != null) {
                              setState(() => _confirmPasswordError = null);
                            }
                          },
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
                                onPressed: _signUpUser,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size(double.infinity, 50),
                                ),
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                      ],
                    ),
                  ),
                  Spacer(),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login',arguments:_userType);
                      },
                      child: Text(
                        'Already have an account? Sign in',
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}