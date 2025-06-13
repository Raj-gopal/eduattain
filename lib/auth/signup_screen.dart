import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Assuming your LoginScreen is in the same 'auth' folder
import 'package:eduattain/auth/login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); // For "Name Store"
  String _selectedRole = 'student'; // Default role
  bool _isLoading = false;
  bool _obscureText = true; // For password visibility toggle

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    // Basic validation
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showMessage("Please fill all fields: Name, Email, and Password.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = userCredential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(), // Storing as 'name'
        'role': _selectedRole,
        'isApproved': false, // New users typically need approval
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Account created successfully! Awaiting admin approval.');

      // Clear fields after successful registration
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() {
        _selectedRole = 'student'; // Reset dropdown
      });

      // Navigate to a waiting approval screen or directly to login
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WaitingApprovalScreen()), // Or LoginScreen
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else {
        message = 'Registration failed: ${e.message}';
      }
      _showMessage(message);
    } catch (e) {
      _showMessage("An unexpected error occurred: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Custom SnackBar for messages
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 900; // Define breakpoint for desktop-like layout

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Light grey background like outside the window
      body: Center(
        child: Container(
          width: isLargeScreen ? 1000 : screenWidth * 0.95, // Responsive width for main card
          height: isLargeScreen ? 650 : null, // Fixed height for large, auto for small
          margin: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white, // White background for the main window
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 5,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Flex(
            direction: isLargeScreen ? Axis.horizontal : Axis.vertical, // Layout direction
            children: [
              // --- Left Column: Signup Form ---
              Expanded(
                flex: isLargeScreen ? 1 : 0, // Takes half width on large screen
                child: Container(
                  padding: isLargeScreen ? const EdgeInsets.all(40) : const EdgeInsets.all(25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // Align content to the left
                    mainAxisSize: isLargeScreen ? MainAxisSize.max : MainAxisSize.min, // Fill height on large, wrap on small
                    children: [
                      // "Osmo" Logo/Text
                      Row(
                        children: [


                          const Text(
                            'Edattain',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isLargeScreen ? 50 : 30),
                      const Text(
                        'Create your account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Register your store with Eduaatain', // Or "Register your account"
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 30),






                      // Name Store Field (Using your _nameController)
                      _buildTextField(
                        controller: _nameController,
                        labelText: 'Username', // Label as per image
                        hintText: 'Enter your name',
                        prefixIcon: Icons.person_outline,
                      ),
                      const SizedBox(height: 20),

                      // Email Field
                      _buildTextField(
                        controller: _emailController,
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      _buildTextField(
                        controller: _passwordController,
                        labelText: 'Password',
                        hintText: '••••••••',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscureText,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Role Dropdown (Integrated into the design)
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        onChanged: (val) => setState(() => _selectedRole = val!),
                        items: ['student', 'teacher', 'hod'].map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(role.toUpperCase(), style: const TextStyle(color: Colors.black87)),
                          );
                        }).toList(),
                        decoration: InputDecoration(
                          labelText: 'Role',
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.person_2_rounded, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.transparent,
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFFD5F372), width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                        ),
                        style: const TextStyle(color: Colors.black87),
                        iconEnabledColor: Colors.grey,
                      ),
                      const SizedBox(height: 40),

                      // Register Now Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _registerUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD5F372), // Light green button color
                            foregroundColor: Color(0xff000400), // Dark text on light button
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                              : const Text('Register Now'),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // "Already have an account? Login here" link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account? ",
                            style: TextStyle(color: Colors.grey),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                              );
                            },
                            child: const Text(
                              "Login here",
                              style: TextStyle(
                                color:Color(0xff000400), // Light green link color
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isLargeScreen) const SizedBox(height: 40), // Spacing for small screen
                    ],
                  ),
                ),
              ),

              // --- Right Column: Visual Dashboard Preview ---
              Expanded(
                flex: isLargeScreen ? 1 : 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2B36), // Dark background like the image
                    borderRadius: isLargeScreen
                        ? const BorderRadius.only(
                      topRight: Radius.circular(15),
                      bottomRight: Radius.circular(15),
                    )
                        : const BorderRadius.only(
                      bottomLeft: Radius.circular(15), // Adjusted for stacking
                      bottomRight: Radius.circular(15),
                    ),
                    // You can add a subtle background pattern if desired
                     image: DecorationImage(
                       image: AssetImage('assets/images/login.jpg'), // Add your pattern image here
                      fit: BoxFit.cover,
                    //   opacity: 0.1,
                    // ),
                  ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method for consistent TextField styling
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black87), // Input text color
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: const TextStyle(color: Colors.grey), // Label color
        hintStyle: const TextStyle(color: Colors.grey), // Hint text color
        prefixIcon: Icon(prefixIcon, color: Colors.grey), // Leading icon color
        suffixIcon: suffixIcon, // Apply optional suffix icon
        filled: true, // Enable fill color
        fillColor: Colors.transparent, // Light grey fill for input background
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300), // Subtle border when not focused
          borderRadius: BorderRadius.circular(8), // Rounded corners for the border
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFD5F372), width: 1), // Light green border when focused
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10), // Padding inside the input field
      ),
    );
  }
}

// Your existing WaitingApprovalScreen remains unchanged
class WaitingApprovalScreen extends StatelessWidget {
  const WaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval Pending'),
        backgroundColor: const Color(0xFF1F2B36), // Dark app bar
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: const Color(0xFFF0F2F5), // Match outer background
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_empty,
                  size: 80,
                  color: Colors.grey,
                ),
                SizedBox(height: 20),
                Text(
                  'Your account is awaiting approval by the Admin/HOD.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                ),
                SizedBox(height: 10),
                Text(
                  'Please try logging in again after your account has been approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}