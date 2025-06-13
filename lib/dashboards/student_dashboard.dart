import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart'; // Import for charts

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _userId;
  String? _studentName;
  String? _departmentId;

  // Separated lists for clarity
  List<Map<String, dynamic>> _examMarks = [];
  List<Map<String, dynamic>> _indirectMarks = [];
  Map<String, String> _indirectMarkTypeNames = {}; // To map indirectMarkTypeId to name

  bool _isLoading = true;
  String? _errorMessage;

  // --- UI Consistency Guidelines (Copied from TeacherDashboard) ---
  final Color primaryColor = const Color(0xFFD5F372);
  final Color textBlackColor = const Color(0xFF000400);
  final Color scaffoldBackgroundColor = const Color(0xffF7F7F7);
  final Color cardBackgroundColor = Colors.white;
  final Color cardBorderColor = const Color(0xFFE0E0E0);

  // Index to manage the selected item in the sidebar for navigation
  int _selectedIndex = 0; // 0 for Overview, 1 for My Exam Marks, 2 for My Indirect Marks

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  /// Loads student's profile, department, all associated exam marks,
  /// indirect mark types, and student's indirect marks from Firestore.
  Future<void> _loadStudentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _examMarks = []; // Clear previous data
      _indirectMarks = [];
      _indirectMarkTypeNames = {};
    });

    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = "User not logged in.";
        _isLoading = false;
      });
      return;
    }
    _userId = user.uid;
    print("Loading student data for user ID: $_userId");

    try {
      // 1. Fetch student's profile to get name and departmentId
      final studentDoc = await _firestore.collection('users').doc(_userId).get();
      if (!studentDoc.exists || studentDoc.data()?['role'] != 'student') {
        setState(() {
          _errorMessage = "Student profile not found or role incorrect. Please contact admin.";
          _isLoading = false;
        });
        print("Student profile not found or role incorrect for user ID: $_userId");
        return;
      }
      _studentName = studentDoc['name'];
      _departmentId = studentDoc['departmentId'];
      print("Student Name: $_studentName, Department ID: $_departmentId");


      if (_departmentId == null) {
        setState(() {
          _errorMessage = "Department ID not found for your profile. Please contact admin.";
          _isLoading = false;
        });
        return;
      }

      // 2. Fetch all relevant subjects and exams for lookup (department-specific)
      final subjectsSnapshot = await _firestore.collection('subjects')
          .where('departmentId', isEqualTo: _departmentId)
          .get();
      final Map<String, String> subjectNames = {
        for (var doc in subjectsSnapshot.docs) doc.id: doc['name']
      };
      print("Fetched ${subjectsSnapshot.docs.length} subjects.");

      final examsSnapshot = await _firestore.collection('exams')
          .where('departmentId', isEqualTo: _departmentId)
          .get();
      final Map<String, Map<String, dynamic>> examDetails = {
        for (var doc in examsSnapshot.docs) doc.id: doc.data()!
      };
      print("Fetched ${examsSnapshot.docs.length} exams.");

      // 3. Fetch indirect mark types for lookup
      final indirectTypesSnapshot = await _firestore.collection('indirectMarkTypes')
          .where('departmentId', isEqualTo: _departmentId)
          .get();
      _indirectMarkTypeNames = {
        for (var doc in indirectTypesSnapshot.docs) doc.id: doc['name']
      };
      print("Fetched ${indirectTypesSnapshot.docs.length} indirect mark types.");


      // 4. Fetch all exam marks for this student from 'studentExamCoPoMarks'
      final marksSnapshot = await _firestore
          .collection('studentExamCoPoMarks')
          .where('studentId', isEqualTo: _userId)
          .orderBy('timestamp', descending: true)
          .get();

      final List<Map<String, dynamic>> loadedExamMarks = [];
      print("Fetched ${marksSnapshot.docs.length} exam mark entries.");
      for (var doc in marksSnapshot.docs) {
        final data = doc.data();
        final subjectName = subjectNames[data['subjectId']] ?? 'Unknown Subject';
        final examName = examDetails[data['examId']]?['name'] ?? 'Unknown Exam';
        final examTotalMarks = examDetails[data['examId']]?['totalMarks'] ?? 0;

        loadedExamMarks.add({
          'subjectId': data['subjectId'],
          'subjectName': subjectName,
          'examId': data['examId'],
          'examName': examName,
          'totalMarksScored': (data['totalMarksScored'] as num).toDouble(),
          'examTotalMarks': examTotalMarks.toDouble(),
        });
        print("Loaded exam mark: ${examName} for ${subjectName}, Scored: ${data['totalMarksScored']}");
      }

      // 5. Fetch student's indirect marks from 'indirectMarksAssigned' (as per user's request)
      final studentIndirectMarksSnapshot = await _firestore
          .collection('indirectMarksAssigned') // Changed to 'indirectMarksAssigned' as requested
          .where('studentId', isEqualTo: _userId)
          .get();
      print('Firebase Snapshot (indirectMarksAssigned): ${studentIndirectMarksSnapshot.docs.length} documents fetched.');


      final List<Map<String, dynamic>> loadedIndirectMarks = [];
      print("Fetched ${studentIndirectMarksSnapshot.docs.length} indirect mark entries.");
      for (var doc in studentIndirectMarksSnapshot.docs) {
        final data = doc.data();
        print('Processing indirect mark document: ${doc.id}, Data: $data'); // More detailed debug print

        // CORRECTED: Used 'indirectMarkTypeId' as the key to lookup typeName
        final typeName = _indirectMarkTypeNames[data['indirectMarkTypeId']] ?? 'Unknown Category';

        // Safely get typeDetails. Use try-catch for firstWhere as orElse cannot return nullable
        QueryDocumentSnapshot<Map<String, dynamic>>? typeDoc;
        try {
          typeDoc = indirectTypesSnapshot.docs.firstWhere(
                (tDoc) => tDoc.id == data['indirectMarkTypeId'],
          );
        } catch (e) {
          // If the indirect mark type is not found, typeDoc will remain null.
          // This error can occur if an indirect mark document exists but its associated
          // indirectMarkType document has been deleted or has a mismatched ID.
          print('Indirect mark type not found for ID: ${data['indirectMarkTypeId']} - Error: $e');
        }

        final typeDetails = typeDoc?.data() ?? {'weight': 0, 'totalMarks': 0}; // Provide default map if typeDoc is null


        loadedIndirectMarks.add({
          'id': doc.id,
          'indirectMarkTypeId': data['indirectMarkTypeId'],
          'typeName': typeName, // Added back typeName for display
          'marksScored': (data['marks'] as num?)?.toDouble() ?? 0.0, // Corrected: use 'marksScored' and make it nullable safe
          'totalPossibleMarks': (typeDetails['weight'] as num?)?.toDouble() ?? 0.0,

        });
        print("Loaded indirect mark: ${typeName}, Scored: ${data['marksScored']}");
      }

      setState(() {
        _examMarks = loadedExamMarks;
        _indirectMarks = loadedIndirectMarks;
        _isLoading = false;
      });
      _showMessage("Your academic data loaded successfully!");
    } catch (e) {
      print("Error loading student data: $e"); // Debug print
      setState(() {
        _errorMessage = "Failed to load academic data. Please ensure your HOD has assigned subjects and exams. Error: $e";
        _isLoading = false;
      });
    }
  }

  /// Displays a SnackBar message to the user for feedback.
  void _showMessage(String msg) {
    if (mounted) { // Check if widget is still mounted before showing SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: TextStyle(color: textBlackColor)),
          backgroundColor: primaryColor.withOpacity(0.8),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Builds a consistent card container for grouping related UI elements.
  Widget _buildAdminCard({required String title, required Widget content}) {
    return Card(
      color: cardBackgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: cardBorderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textBlackColor,
              ),
            ),
            const SizedBox(height: 15),
            content,
          ],
        ),
      ),
    );
  }

  /// Builds a consistent ElevatedButton with theme-defined styling.
  Widget _buildElevatedButton({required String text, required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: textBlackColor,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
        minimumSize: const Size(double.infinity, 0),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Generates a PDF report of the student's academic performance.
  Future<void> _generatePdf(BuildContext context) async {
    if (_examMarks.isEmpty && _indirectMarks.isEmpty) {
      _showMessage("No academic data to generate report for.");
      return;
    }
    if (_studentName == null || _departmentId == null) {
      _showMessage("Student details not fully loaded for PDF generation. Please reload dashboard.");
      return;
    }

    final pdf = pw.Document();

    try { // Added try-catch for PDF generation
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(48),
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Student Academic Report', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('Student Name: ${_studentName ?? 'N/A'}', style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 5),
                pw.Divider(),
              ],
            );
          },
          build: (pw.Context context) {
            List<pw.Widget> content = [];

            // --- Exam Marks Overview ---
            content.add(pw.Text('Exam Marks Overview', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)));
            content.add(pw.SizedBox(height: 15));

            if (_examMarks.isEmpty) {
              content.add(pw.Center(child: pw.Text("No exam marks recorded yet.")));
            } else {
              for (var markEntry in _examMarks) {
                content.add(pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Subject: ${markEntry['subjectName']}',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text('Exam: ${markEntry['examName']}', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text('Total Marks Scored: ${markEntry['totalMarksScored'].toInt()} / ${markEntry['examTotalMarks'].toInt()}', style: const pw.TextStyle(fontSize: 14)),
                    pw.SizedBox(height: 10),
                  ],
                ));
              }
            }

            // --- Indirect Marks Overview ---
            content.add(pw.SizedBox(height: 20));
            content.add(pw.Text('Indirect Marks Overview', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)));
            content.add(pw.SizedBox(height: 15));

            if (_indirectMarks.isEmpty) {
              content.add(pw.Center(child: pw.Text("No indirect marks recorded yet.")));
            } else {
              content.add(
                pw.Table.fromTextArray(
                  headers: ['Category', 'Scored Marks', 'Total Marks', 'Remarks'], // Added Remarks header
                  data: _indirectMarks.map<List<dynamic>>((markEntry) {
                    final totalMarks = markEntry['totalPossibleMarks'] > 0 ? markEntry['totalPossibleMarks'].toInt() : 'N/A'; // Handle 0
                    final remarks = (markEntry['remarks'] != null && markEntry['remarks'].isNotEmpty) ? markEntry['remarks'] : '-'; // Handle empty remarks
                    return [
                      markEntry['typeName'],
                      markEntry['marksScored'].toInt(),
                      totalMarks,

                      remarks, // Add remarks to data
                    ];
                  }).toList(),
                  border: pw.TableBorder.all(width: 0.5),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.center,
                  cellPadding: const pw.EdgeInsets.all(4),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1),
                    4: const pw.FlexColumnWidth(2), // Column for remarks
                  },
                ),
              );
            }

            return content;
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (format) => pdf.save());
      _showMessage("PDF generated successfully!");
    } catch (e) {
      _showMessage("Error generating PDF: $e");
      print('PDF generation error: $e'); // Log the detailed error
    }
  }

  /// Builds a consistent header for main content sections.
  Widget _buildMainContentHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        border: Border(bottom: BorderSide(color: cardBorderColor, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textBlackColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a sidebar item with an icon, title, and selected state.
  Widget _buildSidebarItem(IconData icon, String title, int index) {
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
            });
            _showMessage("Navigated to $title");
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

  /// Returns the title for the main content area based on the selected sidebar index.
  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return "Overview";
      case 1:
        return "My Exam Marks";
      case 2: // Index 2 is now for My Indirect Marks
        return "My Indirect Marks";
      default:
        return "Student Dashboard";
    }
  }

  /// Returns the widget content for the main content area based on the selected sidebar index.
  Widget _getPageContent(int index) {
    switch (index) {
      case 0:
        return _buildOverviewSection();
      case 1:
        return _buildExamMarksSection();
      case 2: // Index 2 is now for My Indirect Marks
        return _buildIndirectMarksSection();
      default:
        return const Center(child: Text("Select an option from the sidebar."));
    }
  }

  // --- Main Content Sections for Student Dashboard ---

  /// Section for student overview and PDF download.
  Widget _buildOverviewSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminCard(
            title: "Welcome, ${_studentName ?? 'Student'}!",
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Here is an overview of your academic performance including exam marks and indirect marks.',
                  style: TextStyle(color: textBlackColor.withOpacity(0.8), fontSize: 16),
                ),
                const SizedBox(height: 20),
                _buildElevatedButton(
                  onPressed: () => _generatePdf(context),
                  text: "Download Academic Report (PDF)",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section for displaying detailed exam marks with a graph.
  Widget _buildExamMarksSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminCard(
            title: "Detailed Exam Marks",
            content: _examMarks.isEmpty
                ? const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("No exam marks recorded for you yet. Please check back later or contact your teacher.", style: TextStyle(color: Colors.grey)),
            ))
                : Column(
              children: [
                const SizedBox(height: 20),
                // Bar Chart for Exam Marks
                SizedBox(
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (BarChartGroupData group) => Colors.blueGrey,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            String examName = _examMarks[groupIndex]['examName'];
                            double scored = _examMarks[groupIndex]['totalMarksScored'];
                            // Corrected: Removed 'groupC' and directly accessed 'examTotalMarks' from _examMarks
                            double total = _examMarks[groupIndex]['examTotalMarks'];
                            return BarTooltipItem(
                              '$examName\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              children: <TextSpan>[
                                TextSpan(
                                  text: '${scored.toInt()} / ${total.toInt()}',
                                  style: TextStyle(
                                    color: primaryColor.withOpacity(0.9),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: false, // Set to false to remove bottom titles
                            reservedSize: 40,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: cardBorderColor, width: 1),
                      ),
                      barGroups: _examMarks.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> markEntry = entry.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: markEntry['totalMarksScored'],
                              color: primaryColor,
                              width: 15,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            BarChartRodData(
                              toY: markEntry['examTotalMarks'],
                              color: primaryColor.withOpacity(0.3),
                              width: 15,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                          showingTooltipIndicators: [0, 1], // Show tooltips for both bars
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ..._examMarks.map((markEntry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Card(
                      color: cardBackgroundColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: cardBorderColor, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${markEntry['examName']} (${markEntry['subjectName']})',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textBlackColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total Marks: ${markEntry['totalMarksScored'].toInt()} / ${markEntry['examTotalMarks'].toInt()}',
                              style: TextStyle(color: textBlackColor.withOpacity(0.7), fontSize: 15),
                            ),
                            // Removed CO breakdown here
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section for displaying Indirect Marks.
  Widget _buildIndirectMarksSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminCard(
            title: "My Indirect Marks",
            content: _indirectMarks.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "No indirect marks recorded for you yet.",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            )
                : Column(
              children: _indirectMarks.map((markEntry) {
                // Determine display for total marks, only show if > 0
                final String totalMarksDisplay = markEntry['totalPossibleMarks'] > 0
                    ? ' / ${markEntry['totalPossibleMarks'].toInt()}'
                    : '';
                // Only show remarks if not null and not empty
                final String remarksDisplay = (markEntry['remarks'] != null && markEntry['remarks'].isNotEmpty)
                    ? 'Remarks: ${markEntry['remarks']}'
                    : '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Card(
                    color: cardBackgroundColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: cardBorderColor, width: 1),
                    ),
                    child: ListTile(
                      title: Text(
                        markEntry['typeName'],
                        style: TextStyle(color: textBlackColor, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Marks: ${markEntry['marksScored'].toInt()}$totalMarksDisplay'),

                          if (remarksDisplay.isNotEmpty) // Only show remarks if not empty
                            Text(remarksDisplay),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16))) // Display error message
          : Row(
        children: [
          // --- Sidebar Navigation ---
          Padding(
            padding: const EdgeInsets.all(16.0), // Padding around the sidebar card
            child: Container(
              width: 250, // Increased width for better text visibility
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
                  _buildSidebarItem(Icons.dashboard_outlined, "Overview", 0),
                  _buildSidebarItem(Icons.assignment_turned_in_outlined, "My Exam Marks", 1),
                  // Removed CO-PO Attainment section
                  _buildSidebarItem(Icons.assignment_ind_outlined, "My Indirect Marks", 2), // Index 2 for indirect marks

                  const Spacer(), // Pushes logout button to the bottom

                  // Logout Button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildElevatedButton(
                      onPressed: () async {
                        await _auth.signOut();
                        // Navigate back to login or root
                        if (mounted) {
                          // Note: Assuming LoginScreen is the entry point
                          // If you have a different root, adjust this.
                          Navigator.of(context).pushReplacementNamed('/login'); // Use named route if available
                        }
                      },
                      text: 'Logout',
                    ),
                  ),
                  const SizedBox(height: 16), // Padding at the very bottom
                ],
              ),
            ),
          ),
          // --- Main Content Area ---
          Expanded(
            child: Column(
              children: [
                // Header for the current content section
                _buildMainContentHeader(_getPageTitle(_selectedIndex)),
                // Dynamically display content based on sidebar selection
                Expanded(
                  child: _getPageContent(_selectedIndex),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
