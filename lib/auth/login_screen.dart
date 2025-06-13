import 'package:eduattain/auth/signup_screen.dart'; // Ensure this path is correct
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import your dashboard screens
import '../dashboards/admin_dashboard.dart';
import '../dashboards/hod_dashboard.dart';
import '../dashboards/teacher_dashboard.dart';
import '../dashboards/student_dashboard.dart';

// --- Login Screen ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscureText = true; // State for password visibility toggle

  @override
  void dispose() {
    // Dispose controllers to free up resources when the widget is removed
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Handles user login and redirects to appropriate dashboard based on role and approval status
  void loginUser() async {
    // Basic validation: Check if email and password fields are empty
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      showMessage('Please enter both email and password.');
      return;
    }

    // Set loading state to true to show progress indicator during login
    setState(() => isLoading = true);

    try {
      // Authenticate user with Firebase Email and Password
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Fetch user document from Firestore using the authenticated user's UID
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      // Check if the user document exists and contains necessary role and approval status fields
      if (!doc.exists || !doc.data()!.containsKey('role') || !doc.data()!.containsKey('isApproved')) {
        showMessage('User data is incomplete. Please contact support.');
        await FirebaseAuth.instance.signOut(); // Sign out user with incomplete data
        return;
      }

      final role = doc['role'];
      final isApproved = doc['isApproved'];

      // Check if the user account is approved by an admin
      if (!isApproved) {
        showMessage('Your account is waiting for approval from the administrator.');
        // Sign out the user immediately if not approved to prevent unauthorized access
        await FirebaseAuth.instance.signOut();
        return; // Stop further execution
      }

      // Navigate to the appropriate dashboard based on user's role
      // `mounted` check ensures the widget is still in the widget tree before navigation
      if (mounted) {
        if (role == 'admin') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
        } else if (role == 'hod') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HODDashboard()));
        } else if (role == 'teacher') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TeacherDashboard()));
        } else if (role == 'student') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentDashboard()));
        } else {
          // Handle unknown roles
          showMessage("Unknown user role. Please contact support.");
          await FirebaseAuth.instance.signOut(); // Sign out unknown roles
        }
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase authentication errors for better user feedback
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found for that email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        case 'invalid-credential': // Generic error for wrong email/password on newer Firebase versions
          errorMessage = 'Invalid email or password.';
          break;
        default:
          errorMessage = 'Login failed: ${e.message ?? 'An unknown authentication error occurred.'}';
      }
      showMessage(errorMessage);
    } catch (e) {
      // Catch any other unexpected errors during the process
      showMessage('An unexpected error occurred: ${e.toString()}');
    } finally {
      // Always set loading state to false once the operation is complete, only if mounted
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Displays a custom styled SnackBar message for notifications or errors
  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade800, // Darker red for error messages
        behavior: SnackBarBehavior.floating, // Makes the snackbar float above content
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // Margin around the snackbar
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Rounded corners for the snackbar
        duration: const Duration(seconds: 3), // Duration the snackbar is visible
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout adjustments
    final double screenWidth = MediaQuery.of(context).size.width;
    // Define a breakpoint for switching between two-column and single-column layout
    final bool isLargeScreen = screenWidth > 900;

    return Scaffold(
      // Prevents the screen from resizing when the keyboard appears
      resizeToAvoidBottomInset: false,
      body: Container(
        // Full-screen background with a linear gradient matching the image
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF0F2F5), // Outer light grey, simulating the desktop background
              Color(0xFFF0F2F5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            // Main white container acting as the application window
            width: isLargeScreen ? 1000 : screenWidth * 0.95, // Responsive width
            height: isLargeScreen ? 600 : null, // Fixed height for large screens, auto for small
            margin: const EdgeInsets.symmetric(vertical: 40), // Margin around the window
            decoration: BoxDecoration(
              color: Colors.white, // White background for the main window
              borderRadius: BorderRadius.circular(15), // Rounded corners
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1), // Subtle shadow for depth
                  spreadRadius: 5,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Flex(
              // Flex allows for horizontal layout on large screens and vertical on small
              direction: isLargeScreen ? Axis.horizontal : Axis.vertical,
              children: [
                // --- Left Column: Login Form ---
                Expanded(
                  flex: isLargeScreen ? 1 : 0, // Takes half width on large screen
                  child: Container(
                    padding: isLargeScreen ? const EdgeInsets.all(40) : const EdgeInsets.all(25), // Adjusted padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // Align content to the left
                      mainAxisSize: isLargeScreen ? MainAxisSize.max : MainAxisSize.min, // Fill height on large, wrap on small
                      children: [
                        // "Osmo" Logo/Text (using placeholder, replace with your app's logo/name)
                        Row(
                          children: [

                            const Text(
                              'Eduattain', // Placeholder app name
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isLargeScreen ? 50 : 30), // Spacing after logo

                        const Text(
                          'Welcome Back', // Login form title
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 10), // Small gap
                        const Text(
                          'Login to your account to continue', // Login form subtitle
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 30), // Spacing before fields

                        // Username/Email Field
                        _buildTextField(
                          controller: emailController,
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: Icons.person_outline, // Person icon
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20), // Space between fields

                        // Password Field
                        _buildTextField(
                          controller: passwordController,
                          labelText: 'Password',
                          hintText: '••••••••', // Placeholder for password dots
                          prefixIcon: Icons.lock_outline, // Lock icon
                          obscureText: _obscureText, // Toggle visibility
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText ? Icons.visibility_off : Icons.visibility, // Eye icon
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText; // Toggle password visibility
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 15), // Space before forgot password link


                        // Login Button
                        SizedBox(
                          width: double.infinity, // Button takes full width
                          child: ElevatedButton(
                            onPressed: isLoading ? null : loginUser, // Disable if loading
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD5F372), // Light green button color
                              foregroundColor: Color(0xff000400), // Dark text on light button
                              padding: const EdgeInsets.symmetric(vertical: 18), // Vertical padding
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Rounded corners
                              elevation: 0, // No default elevation
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            child: isLoading
                                ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.black, // Indicator color
                                strokeWidth: 2,
                              ),
                            )
                                : const Text('Login'), // Button text
                          ),
                        ),
                        const SizedBox(height: 20), // Space after login button

                        // "No account? Create an account" link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "No account? ",
                              style: TextStyle(color: Colors.grey),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SignupScreen()),
                                );
                              },
                              child: const Text(
                                "Create an account",
                                style: TextStyle(
                                  color: Color(0xFF000400), // Light green link color
                                  fontWeight: FontWeight.bold,

                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Right Column: Visual Dashboard Preview ---
                Expanded(
                  flex: isLargeScreen ? 1 : 0, // Takes half width on large screen
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2B36), // Dark background for this section
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
      ),
    );
  }

  // Helper method to build consistently styled TextFields
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon, // Optional suffix icon (e.g., for password visibility)
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
          borderSide: BorderSide(color:  Color(0xFFE2E2E2)), // Subtle border when not focused
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