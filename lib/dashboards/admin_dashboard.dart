import 'package:eduattain/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Initialize Firestore

  final hodNameController = TextEditingController();
  final hodEmailController = TextEditingController();
  final hodPasswordController = TextEditingController();

  final deptNameController = TextEditingController();
  String? selectedHodId;

  // Define new theme colors based on the new image and current code
  static const Color primaryColor = Color(0xFFD5F372); // Accent green
  static const Color textBlackColor =
  Color(0xFF000400); // Very dark text/sidebar background
  static const Color lightGreyBackground = Color(
      0xFFF7F7F7); // Main content background
  static const Color cardBorderColor = Color(0xFFE0E0E0); // Subtle card borders

  int _selectedIndex = 0; // State variable to track selected sidebar item
  String? _selectedUserId; // New: To store the ID of the selected user for detail view

  // New state variables for dashboard counts
  int? _totalUsers;
  int? _totalDepartments;
  int? _totalHODs; // New state variable for HOD count
  int? _totalTeachers; // New state variable for Teacher (Faculty) count
  int? _totalStudents; // New state variable for Student count
  bool _isDashboardLoading = true; // Loading indicator for dashboard counts


  @override
  void initState() {
    super.initState();
    _fetchDashboardCounts(); // Fetch counts when the dashboard initializes
  }

  @override
  void dispose() {
    hodNameController.dispose();
    hodEmailController.dispose();
    hodPasswordController.dispose();
    deptNameController.dispose();
    super.dispose();
  }

  // Method to fetch total user and department counts, including specific roles
  Future<void> _fetchDashboardCounts() async {
    setState(() {
      _isDashboardLoading = true;
    });
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final departmentsSnapshot = await _firestore.collection('departments').get();

      // Fetch counts for specific roles
      final hodsSnapshot = await _firestore.collection('users').where('role', isEqualTo: 'hod').get();
      final facultySnapshot = await _firestore.collection('users').where('role', isEqualTo: 'teacher').get();
      final studentsSnapshot = await _firestore.collection('users').where('role', isEqualTo: 'student').get();


      setState(() {
        _totalUsers = usersSnapshot.docs.length-1;
        _totalDepartments = departmentsSnapshot.docs.length;
        _totalHODs = hodsSnapshot.docs.length; // Update HOD count
        _totalTeachers = facultySnapshot.docs.length; // Update Teacher count
        _totalStudents = studentsSnapshot.docs.length; // Update Student count
      });
    } catch (e) {
      _showMessage("Error fetching dashboard counts: $e");
      print("Error fetching dashboard counts: $e");
    } finally {
      setState(() {
        _isDashboardLoading = false;
      });
    }
  }

  // Approve a user
  void _approveUser(String uid) {
    _firestore
        .collection('users')
        .doc(uid)
        .update({'isApproved': true}).then((_) {
      _showMessage("User approved successfully!");
      _fetchDashboardCounts(); // Refresh counts after approval
    }).catchError((error) {
      _showMessage("Failed to approve user: $error");
    });
  }

  // Create a HOD
  Future<void> _createHod() async {
    final name = hodNameController.text.trim();
    final email = hodEmailController.text.trim();
    final password = hodPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage("Please fill all HOD fields.");
      return;
    }

    try {
      // Create user with Firebase Auth
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store user data in Firestore
      await _firestore
          .collection('users')
          .doc(cred.user!.uid)
          .set({
        'name': name,
        'email': email,
        'role': 'hod',
        'isApproved': true, // HODs are approved by default
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showMessage("HOD created successfully!");
      hodNameController.clear();
      hodEmailController.clear();
      hodPasswordController.clear();
      _fetchDashboardCounts(); // Refresh counts after creation
    } on FirebaseAuthException catch (e) {
      _showMessage("Failed to create HOD: ${e.message}");
    } catch (e) {
      _showMessage("Unexpected error: $e");
    }
  }

  // Create a Department
  Future<void> _createDepartment() async {
    final deptName = deptNameController.text.trim();

    if (deptName.isEmpty) {
      _showMessage("Please enter department name.");
      return;
    }
    if (selectedHodId == null) {
      _showMessage("Please select an HOD for the department.");
      return;
    }

    try {
      final docRef =
      await _firestore.collection('departments').add({
        'name': deptName,
        'hodId': selectedHodId, // Assign selected HOD to department
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update HOD's document to link them to the department
      await _firestore
          .collection('users')
          .doc(selectedHodId)
          .update({'departmentId': docRef.id}); // Changed 'hodDepartmentId' to 'departmentId' for consistency

      _showMessage("Department created successfully!");
      deptNameController.clear();
      setState(() => selectedHodId = null); // Clear selected HOD
      _fetchDashboardCounts(); // Refresh counts after creation
    } catch (e) {
      _showMessage("Failed to create department: $e");
    }
  }

  // Show SnackBar messages
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: textBlackColor)),
        backgroundColor: primaryColor.withOpacity(0.8),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Edit User Functionality
  Future<void> _editUser(DocumentSnapshot userDoc) async {
    final data = userDoc.data() as Map<String, dynamic>;
    final currentName = data['name'] ?? '';
    final currentRole = data['role'] ?? '';
    final TextEditingController nameController =
    TextEditingController(text: currentName);
    String? selectedRole = currentRole; // Use a local variable to update before setState

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField( // Re-use consistent TextField styling
              controller: nameController,
              labelText: 'Name',
              hintText: 'Enter name', // Added hintText
              prefixIcon: Icons.person_outline, // Added prefixIcon
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(labelText: 'Role'),
              items: <String>['student', 'faculty', 'hod', 'admin']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                // Update the local variable directly for immediate use in dialog
                selectedRole = newValue;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || selectedRole == null) {
                _showMessage("Name and Role cannot be empty.");
                return;
              }
              try {
                await _firestore // Use _firestore instance
                    .collection('users')
                    .doc(userDoc.id)
                    .update({
                  'name': nameController.text.trim(),
                  'role': selectedRole,
                });
                _showMessage("User updated successfully!");
                if (mounted) Navigator.pop(context);
                _fetchDashboardCounts(); // Refresh counts after update
              } catch (e) {
                _showMessage("Failed to update user: $e");
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Delete User Functionality
  Future<void> _deleteUser(String uid) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text(
            'Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
        false;

    if (confirmDelete) {
      try {
        await _firestore.collection('users').doc(uid).delete(); // Use _firestore instance
        _showMessage("User deleted successfully!");
        _fetchDashboardCounts(); // Refresh counts after deletion
      } catch (e) {
        _showMessage("Failed to delete user: $e");
      }
    }
  }

  // List of all users - now styled as a table matching the image
  Widget _buildUserList() {
    return Column(
      children: [
        // Table Header
        Card(
          margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
          color: Colors.white,
          elevation: 0, // No shadow for header
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(
                color: cardBorderColor, width: 1), // Light border
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text('Name',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Email',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Role',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                SizedBox(width: 120), // Adjusted for action buttons
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // User List Rows
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('users').snapshots(), // Use _firestore instance
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: primaryColor));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                  child: Text("No users found.",
                      style: TextStyle(color: Colors.grey)));
            }

            final users = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics:
              const NeverScrollableScrollPhysics(), // Important for nested ListView
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final data = user.data() as Map<String, dynamic>;
                final isApproved = data['isApproved'] ?? false;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Card(
                    color: Colors.white,
                    elevation: 0, // No shadow for rows
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: cardBorderColor, width: 1),
                    ),
                    child: ListTile( // Changed from Padding to ListTile for easier tap handling
                      onTap: () { // New: Tap to view user details
                        setState(() {
                          _selectedUserId = user.id;
                        });
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      title: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              data['name'] ?? 'No Name',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: textBlackColor),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              data['email'],
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              data['role'],
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Approve/Approved Button
                              if (!isApproved)
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline,
                                      color:
                                      primaryColor), // Primary color for approve
                                  onPressed: () => _approveUser(user.id),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.check_circle,
                                      color:
                                      Colors.green), // Green for approved
                                  onPressed:
                                      () {}, // No action if already approved
                                ),
                              // Edit Button
                              IconButton(
                                icon:
                                const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editUser(user),
                              ),
                              // Delete Button
                              IconButton(
                                icon:
                                const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteUser(user.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Fetch HODs for dropdown
  Widget _buildHodDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore // Use _firestore instance
          .collection('users')
          .where('role', isEqualTo: 'hod')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: primaryColor)); // Show loading for HODs
        }
        final hods = snapshot.data!.docs;

        return DropdownButtonFormField<String>(
          value: selectedHodId,
          decoration: InputDecoration(
            labelText: "Select HOD",
            labelStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.transparent, // Match other text fields
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), // Match other text fields
              borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: primaryColor, width: 1.0),
            ),
          ),
          dropdownColor: Colors.white, // Dropdown background
          style: const TextStyle(
              color: textBlackColor), // Text color for selected item
          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          items: hods.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: doc.id,
              child: Text(data['name'] ?? 'Unnamed',
                  style: const TextStyle(color: textBlackColor)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedHodId = value;
            });
          },
        );
      },
    );
  }

  // Helper method for consistent TextField styling (updated to match new image)
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
      style: const TextStyle(color: textBlackColor), // Input text color
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: const TextStyle(color: Colors.grey), // Label color
        hintStyle: const TextStyle(color: Colors.grey), // Hint text color
        prefixIcon: Icon(prefixIcon, color: Colors.grey), // Leading icon color
        suffixIcon: suffixIcon, // Apply optional suffix icon
        filled: true, // Enable fill color
        fillColor: Colors.transparent, // Background of the text field itself
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Color(0xFFE2E2E2)), // Subtle border when not focused
          borderRadius:
          BorderRadius.circular(8), // Rounded corners for the border
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: primaryColor,
              width: 1), // Primary color border when focused
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
            vertical: 15, horizontal: 10), // Padding inside the input field
      ),
    );
  }

  // Helper method for consistent ElevatedButton styling
  Widget _buildElevatedButton(
      {required VoidCallback onPressed, required String text}) {
    return SizedBox(
      width: double.infinity, // Make button full width
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD5F372), // Light green button color
          foregroundColor: const Color(0xff000400), // Dark text on light button
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        child: Text(text),
      ),
    );
  }

  // Helper for Admin Section Cards (reused)
  Widget _buildAdminCard(
      {required String title, required List<Widget> children}) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: cardBorderColor, width: 1), // Added border
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textBlackColor,
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  // Build the persistent Sidebar
  Widget _buildSidebar() {
    return Container(
      width: 250+32, // Increased width for better text visibility
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15), // Adjusted border radius to match cards
        boxShadow: [ // Added subtle shadow for depth
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column( // Use Column instead of ListView for controlled layout
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
            child: SizedBox(
              height: 64,
              width: 80, // Original width from user provided HTML - kept for consistency
              child: Image.asset('assets/images/logo1.png'), // Ensure this path is correct
            ),
          ),
          // Navigation Items using _buildSidebarItem
          _buildSidebarItem(0, Icons.dashboard, 'Dashboard'),
          _buildSidebarItem(1, Icons.person_add, 'Create HOD'), // New sidebar item
          _buildSidebarItem(2, Icons.group, 'User Management'), // User List
          _buildSidebarItem(3, Icons.business, 'Department Management'),
          // Add more items here if needed for other admin functionalities

          const Spacer(), // Pushes logout button to the bottom

          // Logout Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildElevatedButton(
              onPressed: () async {
                await _auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                }
              },
              text: 'Logout',
            ),
          ),
          const SizedBox(height: 16), // Padding at the very bottom
        ],
      ),
    );
  }

  // Helper for Sidebar items
  Widget _buildSidebarItem(int index, IconData icon, String title) {
    bool selected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material( // Use Material for tap ripple effect
        color: selected ? primaryColor.withOpacity(0.8) : Colors.transparent, // Highlight selected item
        borderRadius: BorderRadius.circular(10),
        child: InkWell( // Use InkWell for tap detection and ripple
          onTap: () {
            setState(() {
              _selectedIndex = index; // Update selected index on tap
              _selectedUserId = null; // Clear selected user when navigating to a list view
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Row(
              children: [
                Icon(icon, color: selected ? textBlackColor : Colors.grey[700]), // Icon color based on selection
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? textBlackColor : Colors.grey[700], // Text color based on selection
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Content for Dashboard page
  Widget _buildDashboardContent() {
    return _isDashboardLoading
        ? const Center(child: CircularProgressIndicator(color: primaryColor))
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAdminCard(
          title: "Admin Overview",
          children: [
            Text(
              "Welcome to your Admin Dashboard! Use the sidebar to navigate through different management sections.",
              style: TextStyle(color: textBlackColor.withOpacity(0.8), fontSize: 16),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: primaryColor.withOpacity(0.2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Users", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textBlackColor)),
                          const SizedBox(height: 8),
                          Text(
                            _totalUsers?.toString() ?? '...', // Display fetched total users
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textBlackColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    color: primaryColor.withOpacity(0.2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Departments", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textBlackColor)),
                          const SizedBox(height: 8),
                          Text(
                            _totalDepartments?.toString() ?? '...', // Display fetched total departments
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textBlackColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16), // Spacing between rows of cards
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: primaryColor.withOpacity(0.2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total HODs", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textBlackColor)),
                          const SizedBox(height: 8),
                          Text(
                            _totalHODs?.toString() ?? '...', // Display fetched total HODs
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textBlackColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    color: primaryColor.withOpacity(0.2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Teachers", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textBlackColor)),
                          const SizedBox(height: 8),
                          Text(
                            _totalTeachers?.toString() ?? '...', // Display fetched total Teachers
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textBlackColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: primaryColor.withOpacity(0.2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total Students", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textBlackColor)),
                          const SizedBox(height: 8),
                          Text(
                            _totalStudents?.toString() ?? '...', // Display fetched total Students
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textBlackColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(), // Empty Expanded for layout balance
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // Content for Create HOD page
  Widget _buildCreateHodContent() {
    return _buildAdminCard(
      title: "Create HOD",
      children: [
        _buildTextField(
          controller: hodNameController,
          labelText: "Name",
          hintText: "Enter HOD's full name",
          prefixIcon: Icons.person,
        ),
        const SizedBox(height: 10),
        _buildTextField(
          controller: hodEmailController,
          labelText: "Email",
          hintText: "Enter HOD's email",
          prefixIcon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),
        _buildTextField(
          controller: hodPasswordController,
          labelText: "Password",
          hintText: "Enter HOD's password",
          prefixIcon: Icons.lock,
          obscureText: true,
        ),
        const SizedBox(height: 20),
        _buildElevatedButton(
            onPressed: _createHod, text: "Create HOD"),
      ],
    );
  }

  // Content for User Management (All Users List) page
  Widget _buildUserListContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAdminCard(
          title: "All Users",
          children: [
            _buildUserList(),
          ],
        ),
      ],
    );
  }

  // Content for Department Management page
  Widget _buildDepartmentManagementContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Create Department Section ---
        _buildAdminCard(
          title: "Create Department",
          children: [
            _buildTextField(
              controller: deptNameController,
              labelText: "Department Name",
              hintText: "e.g., Computer Science",
              prefixIcon: Icons.business,
            ),
            const SizedBox(height: 10),
            _buildHodDropdown(),
            const SizedBox(height: 20),
            _buildElevatedButton(
                onPressed: _createDepartment,
                text: "Create Department"),
          ],
        ),
        const SizedBox(height: 20),
        // You could add a list of existing departments here similarly to _buildUserList()
        // Example: _buildDepartmentList();
      ],
    );
  }

  // New: Content for Single User Detail page
  Widget _buildSingleUserDetailContent(String userId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("User not found.", style: TextStyle(color: Colors.grey)));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;

        // Define keys to exclude from display, including any 'id' field within the data
        final List<String> excludedKeys = ['id', 'sectionId', 'departmentId', 'createdBy', 'createdAt','hodDepartmentId','uid','sectionIds','teacherId'];

        return _buildAdminCard(
          title: "User Details: ${userData['name'] ?? 'N/A'}",
          children: [
            // Filter out excluded keys before mapping to Text widgets
            ...userData.entries.where((entry) => !excludedKeys.contains(entry.key)).map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  // Format the key to be more readable (e.g., "isApproved" to "Is Approved")
                  '${entry.key.replaceAll(RegExp(r'(?<=[a-z])(?=[A-Z])'), ' ').capitalizeFirstLetter()}: ${entry.value.toString()}',
                  style: const TextStyle(fontSize: 16, color: textBlackColor),
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
            _buildElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedUserId = null; // Clear selected user to go back to list
                  // No need to change _selectedIndex here, it will default back to the list
                });
              },
              text: 'Back to All Users',
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreyBackground, // Use defined background color
      body: Row(
        children: [
          // Left Sidebar
          Padding(
            padding: const EdgeInsets.all(16.0), // Padding around the sidebar card
            child: _buildSidebar(),
          ),
          // Main Content Area
          Expanded(
            child: SingleChildScrollView( // Ensure main content is scrollable
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prioritize showing single user detail if selected
                  if (_selectedUserId != null)
                    _buildSingleUserDetailContent(_selectedUserId!)
                  else if (_selectedIndex == 0)
                    _buildDashboardContent()
                  else if (_selectedIndex == 1)
                      _buildCreateHodContent()
                    else if (_selectedIndex == 2)
                        _buildUserListContent() // This will show the table of users
                      else if (_selectedIndex == 3)
                          _buildDepartmentManagementContent(),
                  // Add more conditions for other content pages
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension to capitalize the first letter of a string and add spaces before capitals
extension StringExtension on String {
  String capitalizeFirstLetter() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
