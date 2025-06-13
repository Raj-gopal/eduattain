import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HODDashboard extends StatefulWidget {
  const HODDashboard({super.key});

  @override
  State<HODDashboard> createState() => _HODDashboardState();
}

class _HODDashboardState extends State<HODDashboard> {
  // Authentication instance
  final _auth = FirebaseAuth.instance;

  // Text Controllers for various input fields in the HOD Dashboard
  final _teacherNameController = TextEditingController();
  final _teacherEmailController = TextEditingController();
  final _teacherNewPasswordController = TextEditingController(); // For new teacher's password
  final _hodPasswordController = TextEditingController(); // HOD's password for re-authentication
  final _sectionNameController = TextEditingController();
  final _subjectNameController = TextEditingController();
  final _examNameController = TextEditingController();
  final _examTotalMarksController = TextEditingController();
  final _indirectNameController = TextEditingController();
  final _indirectWeightController = TextEditingController();

  // Student specific controllers
  final _studentNameController = TextEditingController();
  final _studentEmailController = TextEditingController();
  final _studentRollNoController = TextEditingController();
  final _studentNewPasswordController = TextEditingController(); // For new student's password

  // State variables for selected items in dropdowns for assignments
  String? selectedSectionId;
  String? selectedSubjectId; // Used for assigning subject to teacher
  String? selectedTeacherId;
  String? selectedExamId;
  String? _selectedSectionForStudentCreation; // Selected section for student creation

  // State variable for subject selected during exam creation
  String? _selectedSubjectForExamCreation;

  // Department ID of the logged-in HOD
  String? departmentId;
  // Index to manage the selected item in the sidebar for navigation
  int _selectedIndex = 0;

  // --- State variables for CO-PO Mapping Section ---
  // List of all subjects associated with the current department
  List<Map<String, dynamic>> _allSubjects = [];
  // List of all sections associated with the current department
  List<Map<String, dynamic>> _allSections = [];
  // Currently selected subject for defining COs and CO-PO mapping
  String? _selectedSubjectForCoPoMapping;
  // List of Course Outcomes (COs) for the currently selected subject.
  // Example: [{'coNo': 'CO1', 'description': 'Understand concepts'}]
  List<Map<String, dynamic>> _currentSubjectCOs = [];
  // Mapping of COs to POs for the currently selected subject.
  // Example: {'CO1': ['PO1', 'PO2'], 'CO2': ['PO2', 'PO3']}
  Map<String, List<String>> _currentCoPoMapping = {};

  // Static list of Program Outcomes (POs) as defined in AICTE/NBA guidelines
  final List<Map<String, String>> _programOutcomes = const [
    {"poNo": "PO1", "description": "Engineering knowledge"},
    {"poNo": "PO2", "description": "Problem analysis"},
    {"poNo": "PO3", "description": "Design/development of solutions"},
    {"poNo": "PO4", "description": "Conduct investigations"},
    {"poNo": "PO5", "description": "Use of modern tools and techniques"},
    {"poNo": "PO10", "description": "Communication skills"},
  ];

  // --- State variables for Exam CO-PO Assignment Section ---
  // List of all exams associated with the current department
  List<Map<String, dynamic>> _allExams = [];
  // Currently selected exam for assigning COs and POs
  String? _selectedExamForCoPoEdit;
  // Subject ID linked to the currently selected exam (can be different from _selectedSubjectForCoPoMapping)
  String? _selectedSubjectForExamCoPo;
  // List of Course Outcomes selected for the currently selected exam
  List<String> _selectedCoMappedForExam = [];
  // List of Program Outcomes selected for the currently selected exam
  List<String> _selectedPoMappedForExam = [];
  // Controllers for CO Max Marks for the selected exam
  Map<String, TextEditingController> _examCoMaxMarksControllers = {};

  // --- State variables for Assessment Structure ---
  // Simplified structure for assessment types
  // Example: {'CA-1': {'activity': 'Quiz', 'totalMarks': 20}}
  Map<String, dynamic> _currentAssessmentStructure = {};

  // Predefined list of assessment types for consistent structure
  final List<String> _assessmentTypes = const [
    'CA-1', 'CA-2', 'CA-3', 'CA-4', 'Semester Examination (Theory Paper)', 'Attendance and Behavior'
  ];

  // --- UI Consistency Guidelines ---
  // Color palette for consistent UI styling
  final Color primaryColor = const Color(0xFFD5F372);
  final Color textBlackColor = const Color(0xFF000400);
  final Color scaffoldBackgroundColor = const Color(0xffF7F7F7);
  final Color cardBackgroundColor = Colors.white;
  final Color cardBorderColor = const Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _getDepartmentId(); // Start by getting the HOD's department ID
  }

  @override
  void dispose() {
    // Dispose all TextEditingControllers to prevent memory leaks
    _teacherNameController.dispose();
    _teacherEmailController.dispose();
    _teacherNewPasswordController.dispose();
    _hodPasswordController.dispose();
    _sectionNameController.dispose();
    _subjectNameController.dispose();
    _examNameController.dispose();
    _examTotalMarksController.dispose();
    _indirectNameController.dispose();
    _indirectWeightController.dispose();
    _studentNameController.dispose();
    _studentEmailController.dispose();
    _studentRollNoController.dispose();
    _studentNewPasswordController.dispose();
    // Dispose dynamically created exam CO max mark controllers
    _examCoMaxMarksControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  /// Fetches the HOD's department ID from Firestore based on their UID.
  /// This ID is crucial for filtering data relevant to their department.
  Future<void> _getDepartmentId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showMessage("HOD not logged in.");
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('departments')
          .where('hodId', isEqualTo: uid)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          departmentId = snapshot.docs.first.id;
        });
        // After departmentId is set, load all data dependent on it
        _loadAllSubjects(); // Load all subjects for CO-PO setup and exam creation
        _loadAllExams(); // Load all exams for CO-PO assignment to exams
        _loadAllSections(); // Load all sections for student creation and display
      } else {
        _showMessage("Department not found for this HOD.");
      }
    } catch (e) {
      _showMessage("Error getting department ID: $e");
    }
  }

  /// Loads all subjects belonging to the current HOD's department.
  /// This list is used for dropdowns in CO-PO setup and exam CO-PO assignment.
  Future<void> _loadAllSubjects() async {
    if (departmentId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('subjects')
          .where('departmentId', isEqualTo: departmentId)
          .get();
      setState(() {
        _allSubjects = snapshot.docs.map((doc) => {'id': doc.id, 'name': doc['name']}).toList();
      });
    } catch (e) {
      _showMessage("Error loading subjects: $e");
    }
  }

  /// Loads all sections belonging to the current HOD's department.
  /// This list is used for dropdowns in student creation and displaying student section.
  Future<void> _loadAllSections() async {
    if (departmentId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sections')
          .where('departmentId', isEqualTo: departmentId)
          .get();
      setState(() {
        _allSections = snapshot.docs.map((doc) => {'id': doc.id, 'name': doc['name']}).toList();
      });
    } catch (e) {
      _showMessage("Error loading sections: $e");
    }
  }

  /// Loads all exams belonging to the current HOD's department.
  /// This list is used for dropdowns in exam CO-PO assignment.
  Future<void> _loadAllExams() async {
    if (departmentId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('exams')
          .where('departmentId', isEqualTo: departmentId)
          .get();
      setState(() {
        _allExams = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'],
            'totalMarks': data['totalMarks'],
            'subjectId': data['subjectId'], // Load subjectId from exam
            'coMapped': List<String>.from(data['coMapped'] ?? []),
            'poMapped': List<String>.from(data['poMapped'] ?? []),
            'coMaxMarks': Map<String, int>.from(data['coMaxMarks'] ?? {}),
          };
        }).toList();
      });
    } catch (e) {
      _showMessage("Error loading exams: $e");
    }
  }

  /// Loads the Course Outcomes and CO-PO mapping data for a specified subject.
  /// This data is populated into `_currentSubjectCOs` and `_currentCoPoMapping`
  /// for editing in the UI. Also loads assessmentStructure.
  Future<void> _loadSubjectCoPoMapping(String subjectId) async {
    try {
      final subjectDoc = await FirebaseFirestore.instance.collection('subjects').doc(subjectId).get();
      if (subjectDoc.exists) {
        setState(() {
          // Load Course Outcomes
          _currentSubjectCOs = List<Map<String, dynamic>>.from(subjectDoc.data()?['courseOutcomes'] ?? []);

          // Load CO-PO mapping into a convenient map format
          _currentCoPoMapping = {};
          final coPoMappingsRaw = subjectDoc.data()?['coPoMapping'] as List<dynamic>?;
          if (coPoMappingsRaw != null) {
            for (final item in coPoMappingsRaw) {
              if (item is Map<String, dynamic>) {
                final Map<String, dynamic> mappedItem = item;
                if (mappedItem.containsKey('co') && mappedItem.containsKey('pos')) {
                  _currentCoPoMapping[mappedItem['co']] = List<String>.from(mappedItem['pos'] ?? []);
                }
              }
            }
          }

          // Load assessmentStructure
          _currentAssessmentStructure = Map<String, dynamic>.from(subjectDoc.data()?['assessmentStructure'] ?? {});

          // Initialize assessment structure with default empty values if not present
          _assessmentTypes.forEach((type) {
            _currentAssessmentStructure.putIfAbsent(type, () => {
              'activity': '',
              'totalMarks': 0,
            });
            // Ensure data types are correct for loaded assessment structure
            _currentAssessmentStructure[type]['activity'] = _currentAssessmentStructure[type]['activity'] as String? ?? '';
            _currentAssessmentStructure[type]['totalMarks'] = _currentAssessmentStructure[type]['totalMarks'] as int? ?? 0;
          });

        });
      } else {
        // Clear data if subject document doesn't exist
        setState(() {
          _currentSubjectCOs = [];
          _currentCoPoMapping = {};
          _currentAssessmentStructure = {};
          _assessmentTypes.forEach((type) {
            _currentAssessmentStructure[type] = {
              'activity': '',
              'totalMarks': 0,
            };
          });
        });
      }
    } catch (e) {
      _showMessage("Error loading subject CO-PO data: $e");
    }
  }

  /// Loads the COs and POs mapped to a specific exam.
  /// This also attempts to load the COs of the subject linked to this exam
  /// so that the user can select from relevant COs.
  Future<void> _loadExamCoPoMapping(String examId) async {
    // Find the exam data from the already loaded _allExams list
    final exam = _allExams.firstWhere((e) => e['id'] == examId, orElse: () => {});

    // Dispose old controllers before creating new ones
    _examCoMaxMarksControllers.forEach((key, controller) => controller.dispose());
    _examCoMaxMarksControllers.clear();

    setState(() {
      _selectedSubjectForExamCoPo = exam['subjectId'] as String?;
      _selectedCoMappedForExam = List<String>.from(exam['coMapped'] ?? []);
      _selectedPoMappedForExam = List<String>.from(exam['poMapped'] ?? []);

      // Populate _examCoMaxMarksControllers with existing data
      final Map<String, int> existingCoMaxMarks = Map<String, int>.from(exam['coMaxMarks'] ?? {});
      for (String coNo in _selectedCoMappedForExam) {
        _examCoMaxMarksControllers[coNo] = TextEditingController(
            text: (existingCoMaxMarks[coNo] ?? '').toString());
      }
    });

    // If the exam is linked to a subject, load that subject's COs for selection
    if (_selectedSubjectForExamCoPo != null) {
      await _loadSubjectCoPoMapping(_selectedSubjectForExamCoPo!); // Await this call
    } else {
      // Clear subject COs if no subject is linked to the exam
      setState(() {
        _currentSubjectCOs = [];
        // Also clear assessment structure if subject unlinked
        _currentAssessmentStructure = {};
        _assessmentTypes.forEach((type) {
          _currentAssessmentStructure[type] = {
            'activity': '',
            'totalMarks': 0,
          };
        });
      });
    }
  }

  /// Displays a SnackBar message to the user for feedback (success/error).
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: textBlackColor)),
        backgroundColor: primaryColor.withOpacity(0.8),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Creates a new teacher account in Firebase Authentication and stores
  /// their details (name, email, role, departmentId, isApproved) in Firestore.
  /// Requires HOD's password for re-authentication for security.
  Future<void> _createTeacher() async {
    final name = _teacherNameController.text.trim();
    final email = _teacherEmailController.text.trim();
    final newTeacherPassword = _teacherNewPasswordController.text; // Get new teacher's password
    final hodPassword = _hodPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || newTeacherPassword.isEmpty || hodPassword.isEmpty || departmentId == null) {
      _showMessage("Fill all fields, including new teacher's password and your password.");
      return;
    }

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showMessage("Error: No current HOD user found.");
        return;
      }

      // Re-authenticate HOD for security before creating new user
      AuthCredential credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: hodPassword,
      );
      await currentUser.reauthenticateWithCredential(credential);

      // Create new teacher user in Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: newTeacherPassword, // Use the password from the text field
      );

      // Store teacher details in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'role': 'teacher',
        'departmentId': departmentId,
        'isApproved': true, // Directly approve teachers created by HOD
        'teacherId': userCredential.user!.uid, // Explicitly add teacherId
        'sectionIds': [], // Initialize empty list for assigned sections
        'subjectIds': [], // Initialize empty list for assigned subjects
      });

      // Clear input fields and show success message
      _teacherNameController.clear();
      _teacherEmailController.clear();
      _teacherNewPasswordController.clear(); // Clear new teacher's password
      _hodPasswordController.clear();
      _showMessage("Teacher created and approved.");
    } on FirebaseAuthException catch (e) {
      // Handle Firebase Authentication specific errors
      if (e.code == 'wrong-password' || e.code == 'user-not-found') {
        _showMessage("Authentication failed: Incorrect HOD password.");
      } else if (e.code == 'email-already-in-use') {
        _showMessage("Error: Email already in use for another account.");
      } else if (e.code == 'weak-password') {
        _showMessage("Error: New password is too weak. Please use a stronger password.");
      } else {
        _showMessage("Error creating teacher: ${e.message}");
      }
    } catch (e) {
      // Handle any other unexpected errors
      _showMessage("An unexpected error occurred: $e");
    }
  }

  /// Creates a new student account in Firebase Authentication and stores
  /// their details (name, email, rollNo, role, departmentId, sectionId) in Firestore.
  /// Requires HOD's password for re-authentication for security.
  Future<void> _createStudent() async {
    final name = _studentNameController.text.trim();
    final email = _studentEmailController.text.trim();
    final rollNo = _studentRollNoController.text.trim();
    final newStudentPassword = _studentNewPasswordController.text; // Get new student's password
    final hodPassword = _hodPasswordController.text.trim(); // HOD's password for re-auth

    if (name.isEmpty || email.isEmpty || rollNo.isEmpty || newStudentPassword.isEmpty || _selectedSectionForStudentCreation == null || hodPassword.isEmpty || departmentId == null) {
      _showMessage("Fill all fields, including new student's password, your password and select a section.");
      return;
    }

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showMessage("Error: No current HOD user found.");
        return;
      }

      // Re-authenticate HOD for security before creating new user
      AuthCredential credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: hodPassword,
      );
      await currentUser.reauthenticateWithCredential(credential);

      // Create new student user in Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: newStudentPassword, // Use the password from the text field
      );

      // Store student details in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'rollNo': rollNo,
        'role': 'student',
        'departmentId': departmentId,
        'sectionId': _selectedSectionForStudentCreation, // Assign student to a section
        'createdBy': currentUser.uid, // Record which HOD created the student
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Clear input fields and show success message
      _studentNameController.clear();
      _studentEmailController.clear();
      _studentRollNoController.clear();
      _studentNewPasswordController.clear(); // Clear new student's password
      _hodPasswordController.clear(); // Clear HOD's password for security
      setState(() {
        _selectedSectionForStudentCreation = null; // Clear selected section
      });
      _showMessage("Student created successfully.");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'user-not-found') {
        _showMessage("Authentication failed: Incorrect HOD password.");
      } else if (e.code == 'email-already-in-use') {
        _showMessage("Error: Email already in use for another account.");
      } else if (e.code == 'weak-password') {
        _showMessage("Error: New password is too weak. Please use a stronger password.");
      }
      else {
        _showMessage("Error creating student: ${e.message}");
      }
    } catch (e) {
      _showMessage("An unexpected error occurred: $e");
    }
  }


  /// Creates a new section within the HOD's department in Firestore.
  Future<void> _createSection() async {
    final name = _sectionNameController.text.trim();
    if (name.isEmpty || departmentId == null) {
      _showMessage("Section name required.");
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('sections').add({
        'name': name,
        'departmentId': departmentId,
        'assignedTeacherIds': [], // Initialize empty list for assigned teachers
        'assignedSubjectIds': [], // Initialize empty list for assigned subjects
      });
      _sectionNameController.clear();
      _showMessage("Section created.");
      _loadAllSections(); // Reload sections after creation
    } catch (e) {
      _showMessage("Error creating section: $e");
    }
  }

  /// Creates a new subject within the HOD's department in Firestore.
  /// Also refreshes the list of all subjects.
  Future<void> _createSubject() async {
    final name = _subjectNameController.text.trim();
    if (name.isEmpty || departmentId == null) {
      _showMessage("Subject name required.");
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('subjects').add({
        'name': name,
        'departmentId': departmentId,
        // Initialize COs and mapping for new subjects
        'courseOutcomes': [],
        'coPoMapping': [],
        'assessmentStructure': {}, // Add empty structure
      });
      _subjectNameController.clear();
      _showMessage("Subject created.");
      _loadAllSubjects(); // Refresh subjects list for CO-PO mapping
    } catch (e) {
      _showMessage("Error creating subject: $e");
    }
  }

  /// Creates a new exam within the HOD's department in Firestore.
  /// Each exam created here can be linked to any existing subject.
  /// You can create multiple exams and link them all to the same subject.
  Future<void> _createExam() async {
    final name = _examNameController.text.trim();
    final marks = int.tryParse(_examTotalMarksController.text.trim());

    // Check if a subject is selected for exam creation
    if (name.isEmpty || departmentId == null || marks == null || _selectedSubjectForExamCreation == null) {
      _showMessage("Exam Name, Total Marks, and Subject are required.");
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('exams').add({
        'name': name,
        'totalMarks': marks,
        'departmentId': departmentId,
        'assignedTeacherIds': [], // Initialize as empty array, teachers assigned later
        'subjectId': _selectedSubjectForExamCreation, // Link to subject at creation
        'coMapped': [],    // Initialize as empty, HOD will assign later in CO-PO Setup
        'poMapped': [],    // Initialize as empty, HOD will assign later in CO-PO Setup
        'coMaxMarks': {},  // Initialize empty map for CO max marks
      });
      _examNameController.clear();
      _examTotalMarksController.clear();
      setState(() {
        _selectedSubjectForExamCreation = null; // Clear selection after creation
      });
      _showMessage("Exam created and linked to subject.");
      _loadAllExams(); // Refresh exams list for CO-PO assignment
    } catch (e) {
      _showMessage("Error creating exam: $e");
    }
  }

  /// Assigns a selected subject to a selected teacher and section.
  /// This function also denormalizes the assignment by updating
  /// the teacher's and section's documents with the assigned IDs.
  Future<void> _assignSubjectToTeacher() async {
    if (selectedSubjectId == null || selectedSectionId == null || selectedTeacherId == null) {
      _showMessage("All selections required.");
      return;
    }

    try {
      // 1. Create the assignment document in 'subjectAssignments'
      await FirebaseFirestore.instance.collection('subjectAssignments').add({
        'subjectId': selectedSubjectId,
        'sectionId': selectedSectionId,
        'teacherId': selectedTeacherId,
        'departmentId': departmentId,
        'assignedAt': FieldValue.serverTimestamp(),
      });

      // 2. Denormalize: Update the teacher's document in 'users'
      final teacherDocRef = FirebaseFirestore.instance.collection('users').doc(selectedTeacherId!);
      await teacherDocRef.update({
        'sectionIds': FieldValue.arrayUnion([selectedSectionId!]), // Add sectionId to teacher's array
        'subjectIds': FieldValue.arrayUnion([selectedSubjectId!]), // Add subjectId to teacher's array
      });

      // 3. Denormalize: Update the section's document in 'sections'
      final sectionDocRef = FirebaseFirestore.instance.collection('sections').doc(selectedSectionId!);
      await sectionDocRef.update({
        'assignedTeacherIds': FieldValue.arrayUnion([selectedTeacherId!]), // Add teacherId to section's array
        'assignedSubjectIds': FieldValue.arrayUnion([selectedSubjectId!]), // Add subjectId to section's array
      });

      _showMessage("Subject assigned to teacher and records updated.");
    } catch (e) {
      _showMessage("Error assigning subject: $e");
    }
  }

  /// Assigns a selected exam to a selected teacher by updating the exam document.
  Future<void> _assignExamToTeacher() async {
    if (selectedExamId == null || selectedTeacherId == null) {
      _showMessage("Exam and Teacher must be selected.");
      return;
    }

    try {
      final examDocRef = FirebaseFirestore.instance.collection('exams').doc(selectedExamId!);
      final examSnapshot = await examDocRef.get();

      if (examSnapshot.exists) {
        final existingList = List<String>.from(examSnapshot.data()?['assignedTeacherIds'] ?? []);
        if (!existingList.contains(selectedTeacherId)) {
          existingList.add(selectedTeacherId!);
          await examDocRef.update({'assignedTeacherIds': existingList});
          _showMessage("Exam assigned to teacher.");
        } else {
          _showMessage("Teacher already assigned.");
        }
      } else {
        _showMessage("Exam not found.");
      }
    } catch (e) {
      _showMessage("Error assigning exam: $e");
    }
  }

  /// Creates a new indirect mark type (e.g., 'Project', 'Attendance')
  /// with a specified name and weightage.
  Future<void> _createIndirectMarkType() async {
    final name = _indirectNameController.text.trim();
    final weight = int.tryParse(_indirectWeightController.text.trim());

    if (name.isEmpty || weight == null || departmentId == null) {
      _showMessage("All fields are required.");
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('indirectMarkTypes').add({
        'name': name,
        'weight': weight,
        'departmentId': departmentId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _indirectNameController.clear();
      _indirectWeightController.clear();
      _showMessage("Indirect mark type created.");
    } catch (e) {
      _showMessage("Error creating indirect mark type: $e");
    }
  }

  /// Deletes an item from a specified Firestore collection.
  /// Refreshes relevant lists after deletion.
  Future<void> _deleteItem(String collection, String id) async {
    try {
      await FirebaseFirestore.instance.collection(collection).doc(id).delete();
      _showMessage("Deleted from $collection.");
      // Reload relevant lists after deletion to update UI
      if (collection == 'subjects') _loadAllSubjects();
      if (collection == 'exams') _loadAllExams();
      if (collection == 'sections') _loadAllSections();
      // No explicit reload for users here, as their lists are StreamBuilders
      // and will react to changes automatically from Firestore.
    } catch (e) {
      _showMessage("Error deleting from $collection: $e");
    }
  }

  /// Saves the Course Outcomes (COs) and their mapping to Program Outcomes (POs)
  /// for the currently selected subject into Firestore.
  /// Also saves assessmentStructure.
  Future<void> _saveSubjectCoPoMapping() async {
    if (_selectedSubjectForCoPoMapping == null) {
      _showMessage("Please select a subject first.");
      return;
    }
    if (_currentSubjectCOs.isEmpty) {
      _showMessage("Please add at least one Course Outcome.");
      return;
    }

    // Prepare CO-PO mapping data in the format expected by Firestore
    List<Map<String, dynamic>> coPoMappingForFirestore = [];
    for (var co in _currentSubjectCOs) {
      String coNo = co['coNo'] as String;
      List<String> mappedPOs = _currentCoPoMapping[coNo] ?? [];
      coPoMappingForFirestore.add({'co': coNo, 'pos': mappedPOs});
    }

    // Prepare assessment structure for Firestore
    Map<String, dynamic> assessmentStructureToSave = {};
    _assessmentTypes.forEach((type) {
      final data = _currentAssessmentStructure[type];
      // Only save if there's meaningful data (activity or totalMarks > 0)
      if (data != null && (data['activity'].isNotEmpty || data['totalMarks'] > 0)) {
        assessmentStructureToSave[type] = {
          'activity': data['activity'],
          'totalMarks': data['totalMarks'],
        };
      }
    });

    try {
      await FirebaseFirestore.instance.collection('subjects').doc(_selectedSubjectForCoPoMapping!).update({
        'courseOutcomes': _currentSubjectCOs, // Save the list of CO maps
        'coPoMapping': coPoMappingForFirestore, // Save the formatted CO-PO mapping
        'assessmentStructure': assessmentStructureToSave, // Save assessment structure
      });
      _showMessage("COs, PO Mapping, and Assessment Structure saved for subject.");
      // Reload the subject's CO-PO mapping to confirm changes are reflected
      _loadSubjectCoPoMapping(_selectedSubjectForCoPoMapping!);
    } catch (e) {
      _showMessage("Error saving COs and CO-PO mapping: $e");
    }
  }

  /// Updates the `subjectId`, `coMapped`, and `poMapped` fields for a selected exam
  /// in its Firestore document. This links the exam to its subject and relevant
  /// COs and POs, enabling CO-PO attainment at the teacher level.
  Future<void> _updateExamCoPoMapping() async {
    if (_selectedExamForCoPoEdit == null || _selectedSubjectForExamCoPo == null) {
      _showMessage("Select an exam and its subject.");
      return;
    }
    if (_selectedCoMappedForExam.isEmpty && _selectedPoMappedForExam.isEmpty) {
      _showMessage("Please select at least one CO or PO for the exam mapping.");
      return;
    }

    // Collect CO Max Marks from controllers
    Map<String, int> coMaxMarksToSave = {};
    for (String coNo in _selectedCoMappedForExam) {
      final controller = _examCoMaxMarksControllers[coNo];
      final maxMark = int.tryParse(controller?.text ?? '0') ?? 0;
      if (maxMark <= 0) {
        _showMessage("Please enter valid max marks ( > 0) for all selected COs.");
        return;
      }
      coMaxMarksToSave[coNo] = maxMark;
    }

    try {
      await FirebaseFirestore.instance.collection('exams').doc(_selectedExamForCoPoEdit!).update({
        'subjectId': _selectedSubjectForExamCoPo, // Link exam to subject
        'coMapped': _selectedCoMappedForExam,     // Assign selected COs
        'poMapped': _selectedPoMappedForExam,     // Assign selected POs
        'coMaxMarks': coMaxMarksToSave,           // Save CO Max Marks
      });
      _showMessage("Exam CO-PO mapping updated successfully.");
      _loadAllExams(); // Refresh exam data to reflect updated mappings
    } catch (e) {
      _showMessage("Error updating exam CO-PO mapping: $e");
    }
  }

  // --- UI Building Helper Methods ---

  /// Builds a consistent header for major content sections.
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

  /// Builds a consistent card container for forms and information display.
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

  /// Builds a consistent TextField with customizable properties.
  /// Includes an optional `onChanged` callback.
  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
    bool obscureText = false,
    int? maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: textBlackColor),
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.grey),
        hintStyle: const TextStyle(color: Colors.grey),
        fillColor: Colors.transparent,
        filled: true,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey) : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 1),
        ),
      ),
    );
  }

  /// Builds a consistent ElevatedButton with full width and theme-defined styling.
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
        minimumSize: const Size(double.infinity, 0), // Full width button
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

  /// Builds a consistent DropdownButtonFormField.
  Widget _buildDropdown<T>({
    Key? key,
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: key,
      decoration: InputDecoration(
        fillColor: Colors.transparent,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 1),
        ),
      ),
      hint: Text(hint, style: const TextStyle(color: Colors.grey)),
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: Colors.white,
      style: TextStyle(color: textBlackColor),
    );
  }

  /// Builds a dropdown populated with data from a Firestore stream.
  /// Now correctly uses `currentValue` to display the selected item.
  Widget _dropdownStream(String collection, String hint, void Function(String?) onChanged, String? currentValue, {Map<String, dynamic>? filters}) {
    Query query = FirebaseFirestore.instance.collection(collection).where('departmentId', isEqualTo: departmentId);
    filters?.forEach((k, v) => query = query.where(k, isEqualTo: v));

    return StreamBuilder<QuerySnapshot>( // Specify type for StreamBuilder
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text("Error: ${snapshot.error}");
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildDropdown<String>( // Use the helper for consistency
            value: null, // No items to select, so value is null
            hint: hint,
            items: [],
            onChanged: onChanged,
          );
        }

        final docs = snapshot.data!.docs;
        // Filter out invalid currentValue if it's not in the current docs list
        final validItems = docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'] ?? doc['email'] ?? 'No Name', style: TextStyle(color: textBlackColor)))).toList();
        String? actualValue = validItems.any((item) => item.value == currentValue) ? currentValue : null;

        return _buildDropdown<String>(
          value: actualValue, // Pass the actual current value here
          hint: hint,
          items: validItems,
          onChanged: onChanged,
        );
      },
    );
  }

  /// Builds a list of items from a Firestore stream with a delete option.
  /// Enhanced to show assigned counts for teachers and sections.
  Widget _listStreamWithDelete(String collection) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection(collection).where('departmentId', isEqualTo: departmentId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Text("No items to display.", style: const TextStyle(color: Colors.grey));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            String titleText = doc['name'] ?? doc['email'] ?? 'No Name';
            String subtitleText = '';

            if (collection == 'exams') {
              final totalMarks = doc['totalMarks'];
              if (totalMarks != null) {
                subtitleText = 'Total Marks: $totalMarks';
              }
              // Display subjectId, coMapped, poMapped for exams
              // Handle potential null `doc['subjectId']` explicitly
              final String? examSubjectId = doc['subjectId'] as String?;
              final String subjectName;
              if (examSubjectId != null && _allSubjects.isNotEmpty) {
                // Find the subject name from the _allSubjects list
                subjectName = _allSubjects.firstWhere(
                        (sub) => sub['id'] == examSubjectId,
                    orElse: () => {'name': 'N/A'} // Provide a default map if not found
                )['name']; // Access the name from the found map
              } else {
                subjectName = 'N/A'; // Default if subjectId is null or subjects not loaded
              }

              final coMapped = (doc['coMapped'] as List?)?.join(', ') ?? 'N/A';
              final poMapped = (doc['poMapped'] as List?)?.join(', ') ?? 'N/A';
              subtitleText += '\nSubject: $subjectName\nCOs: $coMapped\nPOs: $poMapped'; // Multi-line subtitle
            } else if (collection == 'indirectMarkTypes') {
              final weight = doc['weight'];
              if (weight != null) {
                subtitleText = 'Weightage: $weight%';
              }
            } else if (collection == 'sections') {
              // Show assigned teachers and subjects for sections
              final assignedTeachers = (doc['assignedTeacherIds'] as List?)?.length ?? 0;
              final assignedSubjects = (doc['assignedSubjectIds'] as List?)?.length ?? 0;
              subtitleText = 'Assigned Teachers: $assignedTeachers, Subjects: $assignedSubjects';
            } else if (collection == 'users' && doc['role'] == 'teacher') {
              // Show assigned sections and subjects for teachers
              final assignedSections = (doc['sectionIds'] as List?)?.length ?? 0;
              final assignedSubjects = (doc['subjectIds'] as List?)?.length ?? 0;
              subtitleText = 'Assigned Sections: $assignedSections, Subjects: $assignedSubjects';
            } else if (collection == 'users' && doc['role'] == 'student') {
              // Show assigned section and roll number for students
              final rollNo = doc['rollNo'] ?? 'N/A';
              final sectionId = doc['sectionId'];
              String sectionName = 'N/A';

              // Find the section name from the pre-loaded _allSections list
              if (sectionId != null) {
                final sectionData = _allSections.firstWhere(
                      (s) => s['id'] == sectionId,
                  orElse: () => {'name': 'N/A'}, // Fallback if section not found
                );
                sectionName = sectionData['name'];
              }
              subtitleText = 'Roll No: $rollNo, Section: $sectionName';
            }

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
                    titleText,
                    style: TextStyle(color: textBlackColor, fontWeight: FontWeight.w500),
                  ),
                  subtitle: subtitleText.isNotEmpty
                      ? Text(subtitleText, style: const TextStyle(color: Colors.grey))
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteItem(collection, doc.id),
                  ),
                ),
              ),
            );
          },
        );
      },
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

  // --- Main Content Sections (displayed based on sidebar selection) ---

  /// Section for creating new entities like Teacher, Section, Subject, Exam, Student.
  Widget _buildCreationManagementSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminCard(
            title: "Create Teacher",
            content: Column(
              children: [
                _buildTextField(controller: _teacherNameController, labelText: "Teacher Name", prefixIcon: Icons.person_outline),
                const SizedBox(height: 10),
                _buildTextField(controller: _teacherEmailController, labelText: "Teacher Email", prefixIcon: Icons.email_outlined),
                const SizedBox(height: 10),
                // Field for the new teacher's password
                _buildTextField(
                  controller: _teacherNewPasswordController,
                  labelText: "New Teacher Password",
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _hodPasswordController,
                  labelText: "Your Password (HOD)",
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                _buildElevatedButton(onPressed: _createTeacher, text: "Create Teacher"),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Create Student Card
          _buildAdminCard(
            title: "Create Student",
            content: Column(
              children: [
                _buildTextField(controller: _studentNameController, labelText: "Student Name", prefixIcon: Icons.person_outline),
                const SizedBox(height: 10),
                _buildTextField(controller: _studentEmailController, labelText: "Student Email", prefixIcon: Icons.email_outlined),
                const SizedBox(height: 10),
                _buildTextField(controller: _studentRollNoController, labelText: "Roll Number", keyboardType: TextInputType.number, prefixIcon: Icons.format_list_numbered),
                const SizedBox(height: 10),
                _dropdownStream(
                  'sections',
                  'Select Section for Student',
                      (val) => setState(() => _selectedSectionForStudentCreation = val),
                  _selectedSectionForStudentCreation,
                ),
                const SizedBox(height: 10),
                // Field for the new student's password
                _buildTextField(
                  controller: _studentNewPasswordController,
                  labelText: "New Student Password",
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                // Re-use HOD password controller for security during student creation
                _buildTextField(
                  controller: _hodPasswordController,
                  labelText: "Your Password (HOD) - for student creation",
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                _buildElevatedButton(onPressed: _createStudent, text: "Create Student"),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildAdminCard(
            title: "Create Section",
            content: Column(
              children: [
                _buildTextField(controller: _sectionNameController, labelText: "Section Name", prefixIcon: Icons.bookmark_outline),
                const SizedBox(height: 20),
                _buildElevatedButton(onPressed: _createSection, text: "Create Section"),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildAdminCard(
            title: "Create Subject",
            content: Column(
              children: [
                _buildTextField(controller: _subjectNameController, labelText: "Subject Name", prefixIcon: Icons.menu_book_outlined),
                const SizedBox(height: 20),
                _buildElevatedButton(onPressed: _createSubject, text: "Create Subject"),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildAdminCard(
            title: "Create Exam",
            content: Column(
              children: [
                _buildTextField(controller: _examNameController, labelText: "Exam Name", prefixIcon: Icons.assignment_outlined),
                const SizedBox(height: 10),
                _buildTextField(controller: _examTotalMarksController, keyboardType: TextInputType.number, labelText: "Total Marks", prefixIcon: Icons.score),
                const SizedBox(height: 10),
                // Dropdown for selecting subject during exam creation.
                // The same subject can be selected for multiple different exams.
                _buildDropdown<String>(
                  value: _selectedSubjectForExamCreation,
                  hint: _allSubjects.isEmpty ? "No Subjects Available" : "Select Subject for Exam",
                  items: _allSubjects.map((subject) {
                    return DropdownMenuItem<String>(
                      value: subject['id'],
                      child: Text(subject['name']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSubjectForExamCreation = val;
                    });
                  },
                ),
                const SizedBox(height: 20),
                _buildElevatedButton(onPressed: _createExam, text: "Create Exam"),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildAdminCard(
            title: "Create Indirect Marking Category",
            content: Column(
              children: [
                _buildTextField(controller: _indirectNameController, labelText: "Category Name", prefixIcon: Icons.category_outlined),
                const SizedBox(height: 10),
                _buildTextField(controller: _indirectWeightController, keyboardType: TextInputType.number, labelText: "Weightage (e.g. 10)", prefixIcon: Icons.line_weight),
                const SizedBox(height: 20),
                _buildElevatedButton(onPressed: _createIndirectMarkType, text: "Create Category"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section for assigning subjects and exams to teachers and sections.
  Widget _buildAssignmentManagementSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminCard(
            title: "Assign Subject to Teacher",
            content: Column(
              children: [
                _dropdownStream('sections', 'Select Section', (val) => setState(() => selectedSectionId = val), selectedSectionId),
                const SizedBox(height: 10),
                _dropdownStream('subjects', 'Select Subject', (val) => setState(() => selectedSubjectId = val), selectedSubjectId),
                const SizedBox(height: 10),
                _dropdownStream('users', 'Select Teacher', (val) => setState(() => selectedTeacherId = val), selectedTeacherId, filters: {'role': 'teacher'}),
                const SizedBox(height: 20),
                _buildElevatedButton(onPressed: _assignSubjectToTeacher, text: "Assign Subject"),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildAdminCard(
            title: "Assign Exam to Teacher",
            content: Column(
              children: [
                _dropdownStream('exams', 'Select Exam', (val) => setState(() => selectedExamId = val), selectedExamId),
                const SizedBox(height: 10),
                _dropdownStream('users', 'Select Teacher', (val) => setState(() => selectedTeacherId = val), selectedTeacherId, filters: {'role': 'teacher'}),
                const SizedBox(height: 20),
                _buildElevatedButton(onPressed: _assignExamToTeacher, text: "Assign Exam"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section for viewing and deleting existing data entries.
  /// Includes display of assigned sections/subjects for teachers and sections.
  Widget _buildListsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminCard(
            title: "Subjects List (Tap to Delete)",
            content: _listStreamWithDelete('subjects'),
          ),
          const SizedBox(height: 20),
          _buildAdminCard(
            title: "Sections List (Tap to Delete)",
            content: _listStreamWithDelete('sections'),
          ),
          const SizedBox(height: 20),
          _buildAdminCard(
            title: "Teachers List (Tap to Delete)",
            content: StreamBuilder<QuerySnapshot>( // Specific StreamBuilder for Teachers
              stream: FirebaseFirestore.instance.collection('users')
                  .where('departmentId', isEqualTo: departmentId)
                  .where('role', isEqualTo: 'teacher') // Filter for teachers only
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Text("No teachers to display.", style: const TextStyle(color: Colors.grey));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    String titleText = doc['name'] ?? doc['email'] ?? 'No Name';
                    // Access denormalized fields
                    final assignedSections = (doc['sectionIds'] as List?)?.length ?? 0;
                    final assignedSubjects = (doc['subjectIds'] as List?)?.length ?? 0;
                    String subtitleText = 'Assigned Sections: $assignedSections, Subjects: $assignedSubjects';

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
                            titleText,
                            style: TextStyle(color: textBlackColor, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(subtitleText, style: const TextStyle(color: Colors.grey)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteItem('users', doc.id),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildAdminCard(
            title: "Students List (Tap to Delete)", // Students list
            content: StreamBuilder<QuerySnapshot>( // Specific StreamBuilder for Students
              stream: FirebaseFirestore.instance.collection('users')
                  .where('departmentId', isEqualTo: departmentId)
                  .where('role', isEqualTo: 'student') // Filter for students only
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Text("No students to display.", style: const TextStyle(color: Colors.grey));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    String titleText = doc['name'] ?? 'No Name';
                    final rollNo = doc['rollNo'] ?? 'N/A';
                    final sectionId = doc['sectionId'];
                    String sectionName = 'N/A';

                    // Find the section name from the pre-loaded _allSections list
                    if (sectionId != null) {
                      final sectionData = _allSections.firstWhere(
                            (s) => s['id'] == sectionId,
                        orElse: () => {'name': 'N/A'}, // Fallback if section not found
                      );
                      sectionName = sectionData['name'];
                    }
                    String subtitleText = 'Roll No: $rollNo, Section: $sectionName';

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
                            titleText,
                            style: TextStyle(color: textBlackColor, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(subtitleText, style: const TextStyle(color: Colors.grey)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteItem('users', doc.id),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildAdminCard(
            title: "Exams List (Tap to Delete)",
            content: _listStreamWithDelete('exams'),
          ),
          const SizedBox(height: 20),
          _buildAdminCard(
            title: "Indirect Mark Types (Tap to Delete)",
            content: _listStreamWithDelete('indirectMarkTypes'),
          ),
        ],
      ),
    );
  }

  /// CO-PO Setup Section
  Widget _buildCoPoSetupSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Select Subject for CO-PO Mapping
          _buildAdminCard(
            title: "1. Select Subject for CO-PO Setup",
            content: Column(
              children: [
                _buildDropdown<String>(
                  value: _selectedSubjectForCoPoMapping,
                  hint: _allSubjects.isEmpty ? "No Subjects Available" : "Select Subject",
                  items: _allSubjects.map((subject) {
                    return DropdownMenuItem<String>(
                      value: subject['id'],
                      child: Text(subject['name']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSubjectForCoPoMapping = val;
                      _currentSubjectCOs = [];
                      _currentCoPoMapping = {};
                      _currentAssessmentStructure = {};
                      _assessmentTypes.forEach((type) { // Clear and re-initialize for current subject
                        _currentAssessmentStructure[type] = {
                          'activity': '',
                          'totalMarks': 0,
                        };
                      });
                      if (val != null) {
                        _loadSubjectCoPoMapping(val);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Define Course Outcomes (COs) and Map to POs
          if (_selectedSubjectForCoPoMapping != null)
            _buildAdminCard(
              title: "2. Define Course Outcomes (COs) & Map to POs",
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Define the specific learning outcomes for this subject and link them to broader Program Outcomes.",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 15),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _currentSubjectCOs.length,
                    itemBuilder: (context, index) {
                      final co = _currentSubjectCOs[index];
                      final coNoController = TextEditingController(text: co['coNo'] as String?);
                      final coDescController = TextEditingController(text: co['description'] as String?);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Card(
                          color: cardBackgroundColor.withOpacity(0.95),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: cardBorderColor, width: 1),
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            title: Text(
                              "${coNoController.text.isNotEmpty ? coNoController.text : 'New CO'} - ${coDescController.text.isNotEmpty ? coDescController.text : 'Description'}",
                              style: TextStyle(
                                  color: textBlackColor, fontWeight: FontWeight.w500),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTextField(
                                      controller: coNoController,
                                      labelText: "CO No. (e.g. CO1)",
                                      onChanged: (text) {
                                        setState(() {
                                          final oldCoNo = co['coNo'] as String;
                                          co['coNo'] = text;
                                          if (_currentCoPoMapping.containsKey(oldCoNo)) {
                                            List<String> pos = _currentCoPoMapping.remove(oldCoNo)!;
                                            _currentCoPoMapping[text] = pos;
                                          } else {
                                            _currentCoPoMapping.putIfAbsent(text, () => []);
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    _buildTextField(
                                      controller: coDescController,
                                      labelText: "CO Description",
                                      maxLines: 3,
                                      onChanged: (text) {
                                        setState(() {
                                          co['description'] = text;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 15),
                                    Text(
                                      "Map to Program Outcomes (POs):",
                                      style: TextStyle(color: textBlackColor, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8.0,
                                      children: _programOutcomes.map((po) {
                                        final poCode = po['poNo']!;
                                        final currentCoNo = coNoController.text; // Use controller text for current CO
                                        final isSelected = (_currentCoPoMapping[currentCoNo] ?? []).contains(poCode);
                                        return FilterChip(
                                          label: Text(poCode),
                                          selected: isSelected,
                                          onSelected: (selected) {
                                            setState(() {
                                              List<String> currentPOs = _currentCoPoMapping.putIfAbsent(currentCoNo, () => []);
                                              if (selected) {
                                                if (!currentPOs.contains(poCode)) currentPOs.add(poCode);
                                              } else {
                                                currentPOs.remove(poCode);
                                              }
                                              _currentCoPoMapping[currentCoNo] = currentPOs;
                                            });
                                          },
                                          selectedColor: primaryColor.withOpacity(0.5),
                                          checkmarkColor: textBlackColor,
                                        );
                                      }).toList(),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            final removedCoNo = co['coNo'] as String;
                                            _currentSubjectCOs.removeAt(index);
                                            _currentCoPoMapping.remove(removedCoNo);
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildElevatedButton(
                    onPressed: () {
                      setState(() {
                        final newCoNo = "CO${_currentSubjectCOs.length + 1}";
                        _currentSubjectCOs.add({'coNo': newCoNo, 'description': ''});
                        _currentCoPoMapping[newCoNo] = [];
                      });
                    },
                    text: "Add New Course Outcome",
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Section 3: Define Subject Assessment Structure (Simplified)
          if (_selectedSubjectForCoPoMapping != null)
            _buildAdminCard(
              title: "3. Define Subject Assessment Structure",
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Set up the different types of assessments for this subject and their overall contribution to the subject's marks. This defines the *blueprint* for how marks are distributed (e.g., how many marks are allocated to CA-1, Semester Exam, Attendance, etc. for the whole subject).",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 15),
                  ..._assessmentTypes.map((type) => _buildSimplifiedAssessmentTypeEditor(type)).toList(),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Section 4: Assign COs & POs to Exam (using existing exam instances)
          if (_selectedSubjectForCoPoMapping != null)
            _buildAdminCard(
              title: "4. Assign COs & POs to Specific Exam",
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Link a specific exam (created in 'Create Exam' tab) to its subject, and define which Course Outcomes and Program Outcomes that *particular exam* assesses, along with the max marks for each CO in that exam. This is crucial for CO-PO attainment calculations. \n\nNote: If you have an 'indirect' assessment like a Project or Viva that needs CO-PO mapping, create it as an 'Exam' in the 'Create Exam' tab first, then map it here.",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 15),
                  _buildDropdown<String>(
                    value: _selectedExamForCoPoEdit,
                    hint: _allExams.isEmpty ? "No Exams Available" : "Select Exam",
                    items: _allExams.map((exam) {
                      return DropdownMenuItem<String>(
                        value: exam['id'],
                        child: Text("${exam['name']} (Total: ${exam['totalMarks'] ?? 'N/A'})"),
                      );
                    }).toList(),
                    onChanged: (val) async {
                      setState(() {
                        _selectedExamForCoPoEdit = val;
                        // Reset subject for exam CO-PO and mapped COs/POs
                        _selectedSubjectForExamCoPo = null;
                        _selectedCoMappedForExam = [];
                        _selectedPoMappedForExam = [];
                        _examCoMaxMarksControllers.forEach((key, controller) => controller.dispose());
                        _examCoMaxMarksControllers.clear();
                      });
                      if (val != null) {
                        await _loadExamCoPoMapping(val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  if (_selectedExamForCoPoEdit != null) ...[
                    _buildDropdown<String>(
                      key: ValueKey(_selectedSubjectForExamCoPo),
                      value: _selectedSubjectForExamCoPo,
                      hint: _allSubjects.isEmpty ? "No Subjects Available" : "Select Subject For This Exam",
                      items: _allSubjects.map((subject) {
                        return DropdownMenuItem<String>(
                          value: subject['id'],
                          child: Text(subject['name']),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        setState(() {
                          _selectedSubjectForExamCoPo = val;
                          _selectedCoMappedForExam = [];
                          _selectedPoMappedForExam = [];
                          _examCoMaxMarksControllers.forEach((key, controller) => controller.dispose());
                          _examCoMaxMarksControllers.clear();
                        });
                        if (val != null) {
                          await _loadSubjectCoPoMapping(val); // This loads current subject's COs for selection
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Select COs for this Exam:",
                      style: TextStyle(color: textBlackColor, fontWeight: FontWeight.w500),
                    ),
                    Wrap(
                      spacing: 8.0,
                      children: _currentSubjectCOs.map((co) { // Use _currentSubjectCOs for available COs
                        final coCode = co['coNo'] as String;
                        final isSelected = _selectedCoMappedForExam.contains(coCode);
                        return FilterChip(
                          label: Text(coCode),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                if (!_selectedCoMappedForExam.contains(coCode)) {
                                  _selectedCoMappedForExam.add(coCode);
                                  _examCoMaxMarksControllers[coCode] = TextEditingController(); // Initialize controller
                                }
                              } else {
                                _selectedCoMappedForExam.remove(coCode);
                                _examCoMaxMarksControllers[coCode]?.dispose();
                                _examCoMaxMarksControllers.remove(coCode);
                              }
                            });
                          },
                          selectedColor: primaryColor.withOpacity(0.5),
                          checkmarkColor: textBlackColor,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    if (_selectedCoMappedForExam.isNotEmpty) ...[
                      Text(
                        "Enter Max Marks for Selected COs (for this exam):",
                        style: TextStyle(color: textBlackColor, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: _selectedCoMappedForExam.map((coNo) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: _buildTextField(
                              controller: _examCoMaxMarksControllers.putIfAbsent(coNo, () => TextEditingController()),
                              labelText: "Max Marks for $coNo",
                              keyboardType: TextInputType.number,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      "Select POs for this Exam:",
                      style: TextStyle(color: textBlackColor, fontWeight: FontWeight.w500),
                    ),
                    Wrap(
                      spacing: 8.0,
                      children: _programOutcomes.map((po) {
                        final poCode = po['poNo']!;
                        final isSelected = _selectedPoMappedForExam.contains(poCode);
                        return FilterChip(
                          label: Text(poCode),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedPoMappedForExam.add(poCode);
                              } else {
                                _selectedPoMappedForExam.remove(poCode);
                              }
                            });
                          },
                          selectedColor: primaryColor.withOpacity(0.5),
                          checkmarkColor: textBlackColor,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    _buildElevatedButton(
                      onPressed: _updateExamCoPoMapping,
                      text: "Update Exam CO-PO Mapping",
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Final Save Button for Subject (if any changes were made)
          if (_selectedSubjectForCoPoMapping != null)
            _buildElevatedButton(
              onPressed: _saveSubjectCoPoMapping,
              text: "Save All Subject Configuration",
            ),
        ],
      ),
    );
  }

  /// Simplified helper to build the editor for each assessment type (e.g., CA-1, Semester Exam).
  Widget _buildSimplifiedAssessmentTypeEditor(String assessmentType) {
    // Ensure the structure for this assessment type exists and has default values
    _currentAssessmentStructure.putIfAbsent(assessmentType, () => {
      'activity': '',
      'totalMarks': 0,
    });

    final data = _currentAssessmentStructure[assessmentType];

    final activityController = TextEditingController(text: data['activity']);
    final totalMarksController = TextEditingController(text: data['totalMarks']?.toString());


    return Card(
      color: cardBackgroundColor.withOpacity(0.95),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorderColor, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        title: Text(
          assessmentType,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textBlackColor,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  controller: activityController,
                  labelText: "General Activity (e.g., Quizzes, Midterm, Lab Work)",
                  onChanged: (val) {
                    _currentAssessmentStructure.putIfAbsent(assessmentType, () => {});
                    _currentAssessmentStructure[assessmentType]['activity'] = val;
                  },
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: totalMarksController,
                  labelText: "Overall Marks Contribution for Subject",
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    _currentAssessmentStructure.putIfAbsent(assessmentType, () => {});
                    _currentAssessmentStructure[assessmentType]['totalMarks'] = int.tryParse(val) ?? 0;
                  },
                ),
              ],
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
      // Show loading indicator until departmentId is fetched
      body: departmentId == null
          ? const Center(child: CircularProgressIndicator())
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
                  _buildSidebarItem(Icons.add_box_outlined, "Create", 0),
                  _buildSidebarItem(Icons.assignment_ind_outlined, "Assign", 1),
                  _buildSidebarItem(Icons.list_alt, "Lists", 2),
                  _buildSidebarItem(Icons.school_outlined, "CO-PO Setup", 3), // Sidebar Item for CO-PO Setup

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

  /// Returns the title for the main content area based on the selected sidebar index.
  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return "Creation Management";
      case 1:
        return "Assignment Management";
      case 2:
        return "Data Lists";
      case 3:
        return "CO-PO Setup"; // Title for the new CO-PO section
      default:
        return "HOD Dashboard";
    }
  }

  /// Returns the widget content for the main content area based on the selected sidebar index.
  Widget _getPageContent(int index) {
    switch (index) {
      case 0:
        return _buildCreationManagementSection();
      case 1:
        return _buildAssignmentManagementSection();
      case 2:
        return _buildListsSection();
      case 3:
        return _buildCoPoSetupSection(); // Content for the CO-PO section
      default:
        return const Center(child: Text("Select an option from the sidebar."));
    }
  }
}
