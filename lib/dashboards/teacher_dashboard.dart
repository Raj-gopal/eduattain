import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math'; // For min function if needed, currently not explicitly used but kept from prev context

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({Key? key}) : super(key: key);

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Added Firestore instance

  // Text Controllers for input fields
  final _studentEmailController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _studentPasswordController = TextEditingController();
  final _indirectMarksGivenController = TextEditingController(); // For indirect marks

  // Teacher and Department IDs
  String? teacherId;
  String? departmentId;

  // Dropdown selections for mark entry
  String? _selectedAssignedSubjectId; // ID of subject from subjectAssignment
  String? _selectedAssignedSectionId; // ID of section from subjectAssignment
  String? _selectedExamId; // Selected exam for which to enter marks

  // Data lists for various sections
  List<Map<String, dynamic>> _assignedSubjectsAndSections = []; // Pairs of subjectId, sectionId the teacher teaches
  List<Map<String, dynamic>> _allSubjects = []; // Full list of subjects for names and CO-PO data
  List<Map<String, dynamic>> _allSections = []; // Full list of sections for names
  List<Map<String, dynamic>> _allExams = []; // Full list of exams for names and details

  List<Map<String, dynamic>> _students = []; // Students in the currently selected section
  Map<String, dynamic>? _selectedExamDetails; // Full details of the currently selected exam
  Map<String, dynamic>? _selectedSubjectDetails; // Full subject details for the selected exam (includes COs and CO-PO mapping)

  // Controllers for marks input (per student per CO)
  // Outer map: studentId, Inner map: {'totalMarksScored': TextEditingController, 'CO1': TextEditingController, ...}
  Map<String, Map<String, TextEditingController>> _markControllers = {};
  // Stores current PO attainment for each student: {'studentId': {'PO1': 85.5, 'PO2': 70.0}, ...}
  Map<String, Map<String, double>> _studentPoAttainments = {};

  List<Map<String, dynamic>> _createdStudents = []; // Students created by this teacher
  String? _selectedStudentIdForIndirectMarks; // Selected student for indirect marks assignment
  String? _selectedSectionIdForStudentCreation; // New: Selected section for student creation

  List<Map<String, dynamic>> _indirectMarkTypes = []; // Indirect mark categories (e.g., project, viva)
  String? _selectedIndirectMarkTypeId; // Selected indirect mark type

  List<Map<String, dynamic>> _assignedIndirectMarks = []; // History of assigned indirect marks

  // CO-PO Data for View
  String? _selectedSubjectIdForCoPoView; // Selected subject for CO-PO mapping view
  Map<String, dynamic>? _currentSubjectCoPoData; // Stores the loaded CO-PO data for the selected subject (used for display)
  List<Map<String, dynamic>> _attainmentSummary = []; // Calculated CO-PO attainment summary for selected subject

  // State variable to track loading of students and marks
  bool _isLoadingStudentMarks = false;

  // Index to manage the selected item in the sidebar for navigation
  int _selectedIndex = 0;

  // --- UI Consistency Guidelines ---
  final Color primaryColor = const Color(0xFFD5F372);
  final Color textBlackColor = const Color(0xFF000400);
  final Color scaffoldBackgroundColor = const Color(0xffF7F7F7);
  final Color cardBackgroundColor = Colors.white;
  final Color cardBorderColor = const Color(0xFFE0E0E0);

  // Program Outcomes (PO's) as static data, as they are generally standard
  final List<Map<String, String>> _programOutcomes = const [
    {"poNo": "PO1", "description": "Engineering knowledge"},
    {"poNo": "PO2", "description": "Problem analysis"},
    {"poNo": "PO3", "description": "Design/development of solutions"},
    {"poNo": "PO4", "description": "Conduct investigations"},
    {"poNo": "PO5", "description": "Use of modern tools and techniques"},
    {"poNo": "PO10", "description": "Communication skills"},
  ];

  // CO-PO setup controllers (moved from HOD dashboard)
  final _coNoController = TextEditingController();
  final _coDescriptionController = TextEditingController();
  final _assessmentComponentNameController = TextEditingController(); // Not used directly in new setup
  final _assessmentMarksController = TextEditingController(); // Not used directly in new setup
  final _assessmentCoMappedController = TextEditingController(); // Not used directly in new setup
  final _assessmentPoMappedController = TextEditingController(); // Not used directly in new setup
  final _assessmentActivityController = TextEditingController(); // Not used directly in new setup

  // For CO-PO definition/editing in the teacher dashboard
  String? _selectedSubjectIdForCoPoSetup; // The subject whose CO-PO data is being defined/edited
  List<Map<String, dynamic>> _currentCourseOutcomes = []; // COs for the selected subject
  Map<String, List<String>> _currentCoPoMappings = {}; // CO -> List of POs mapping for selected subject
  Map<String, dynamic> _currentAssessmentStructure = {}; // Assessment structure for selected subject

  // Assessment Types for a fixed structure (as seen in HOD Dashboard)
  final List<String> _assessmentTypes = const [
    'CA-1', 'CA-2', 'CA-3', 'CA-4', 'Semester Examination (Theory Paper)', 'Attendance and Behavior'
  ];

  // For linking COs/POs to specific exams
  String? _selectedExamForCoPoEdit;
  String? _selectedSubjectForExamCoPo; // The subject associated with the selected exam for CO-PO linking
  List<String> _selectedCoMappedForExam = []; // COs mapped to the selected exam
  List<String> _selectedPoMappedForExam = []; // POs mapped to the selected exam
  Map<String, TextEditingController> _examCoMaxMarksControllers = {}; // Max marks for COs in a specific exam


  @override
  void initState() {
    super.initState();
    _loadTeacherData(); // Initiate data loading when the widget starts
  }

  @override
  void dispose() {
    // Dispose all TextEditingControllers to prevent memory leaks
    _studentEmailController.dispose();
    _studentNameController.dispose();
    _studentPasswordController.dispose();
    _indirectMarksGivenController.dispose();

    _coNoController.dispose();
    _coDescriptionController.dispose();
    _assessmentComponentNameController.dispose();
    _assessmentMarksController.dispose();
    _assessmentCoMappedController.dispose();
    _assessmentPoMappedController.dispose();
    _assessmentActivityController.dispose();

    // Dispose dynamically created mark controllers
    _markControllers.forEach((studentId, coControllers) {
      coControllers.forEach((co, controller) {
        controller.dispose();
      });
    });

    // Dispose CO Max Marks controllers for exams
    _examCoMaxMarksControllers.forEach((key, controller) {
      controller.dispose();
    });

    super.dispose();
  }

  /// Loads teacher's ID and department ID from Firestore, then triggers
  /// the loading of all other dependent data (exams, students, mark types, etc.).
  Future<void> _loadTeacherData() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showMessage("User not logged in.");
      return;
    }

    teacherId = user.uid;

    // Fetch the teacher's document to get their departmentId
    try {
      final teacherDoc = await _firestore.collection('users').doc(teacherId).get();
      if (teacherDoc.exists && teacherDoc.data()!.containsKey('departmentId')) {
        setState(() {
          departmentId = teacherDoc['departmentId'];
        });
      } else {
        _showMessage("Department ID not found for this teacher.");
        return;
      }

      // Load all necessary data concurrently using Future.wait
      await Future.wait([
        _loadAllMasterData(), // This loads subjects, sections, exams (including coMaxMarks)
        _loadCreatedStudents(),
        _loadIndirectMarkTypes(),
        _loadAssignedIndirectMarks(),
        _loadAssignedSubjectsAndSections(), // This populates _assignedSubjectsAndSections
      ]);

      // After subjects are loaded, if any, load initial CO-PO data
      if (_assignedSubjectsAndSections.isNotEmpty) {
        // Find a distinct list of subjects assigned to this teacher
        final distinctAssignedSubjects = _assignedSubjectsAndSections
            .map((e) => e['subjectId'] as String)
            .toSet()
            .toList();

        if (distinctAssignedSubjects.isNotEmpty) {
          // Check if the first assigned subject actually exists in _allSubjects
          final initialSubjectIdCandidate = distinctAssignedSubjects.first;

          // Ensure that the initialSubjectIdCandidate is present in the _allSubjects list
          // before attempting to set it as the selected value.
          final validInitialSubjectId = _allSubjects.firstWhere(
                  (sub) => sub['id'] == initialSubjectIdCandidate,
              orElse: () => {'id': null} // Provide a fallback if not found
          )['id'] as String?;

          // Initialize _selectedSubjectIdForCoPoSetup (for editing)
          if (_selectedSubjectIdForCoPoSetup == null && validInitialSubjectId != null) {
            setState(() {
              _selectedSubjectIdForCoPoSetup = validInitialSubjectId;
            });
            await _loadSubjectCoPoMapping(_selectedSubjectIdForCoPoSetup!); // Load for editing
          } else if (_selectedSubjectIdForCoPoSetup == null && _allSubjects.isNotEmpty) {
            setState(() {
              _selectedSubjectIdForCoPoSetup = _allSubjects.first['id'];
            });
            await _loadSubjectCoPoMapping(_selectedSubjectIdForCoPoSetup!);
          } else if (_selectedSubjectIdForCoPoSetup != null && !_allSubjects.any((sub) => sub['id'] == _selectedSubjectIdForCoPoSetup)) {
            setState(() {
              _selectedSubjectIdForCoPoSetup = null;
              _currentSubjectCoPoData = null;
              _currentCourseOutcomes = [];
              _currentCoPoMappings = {};
              _currentAssessmentStructure = {};
            });
          }

          // Initialize _selectedSubjectIdForCoPoView (for attainment summary)
          // Keep this separate as it was already working for the attainment view
          if (_selectedSubjectIdForCoPoView == null && validInitialSubjectId != null) {
            setState(() {
              _selectedSubjectIdForCoPoView = validInitialSubjectId;
            });
            await _loadCoPoAttainment(_selectedSubjectIdForCoPoView!);
          } else if (_selectedSubjectIdForCoPoView == null && _allSubjects.isNotEmpty) {
            setState(() {
              _selectedSubjectIdForCoPoView = _allSubjects.first['id'];
            });
            await _loadCoPoAttainment(_selectedSubjectIdForCoPoView!);
          }
        }
      }
    } catch (e) {
      _showMessage("Error loading teacher data: $e");
    }
  }

  /// Loads all subjects, sections, and exams relevant to the teacher's department.
  /// These are used to populate dropdowns and retrieve details.
  Future<void> _loadAllMasterData() async {
    if (departmentId == null) return;

    try {
      // Load all subjects
      final subjectsSnapshot = await _firestore
          .collection('subjects')
          .where('departmentId', isEqualTo: departmentId)
          .get();
      setState(() {
        _allSubjects = subjectsSnapshot.docs.map((doc) => {'id': doc.id, 'name': doc['name']}).toList();
        print('DEBUG: _loadAllMasterData - Loaded _allSubjects: ${_allSubjects.length} items'); // Debug print
      });

      // Load all sections
      final sectionsSnapshot = await _firestore
          .collection('sections')
          .where('departmentId', isEqualTo: departmentId)
          .get();
      setState(() {
        _allSections = sectionsSnapshot.docs.map((doc) => {'id': doc.id, 'name': doc['name']}).toList();
        print('DEBUG: _loadAllMasterData - Loaded _allSections: ${_allSections.length} items'); // Debug print');
        _allSections.forEach((s) => print('   Section: ${s['name']} (ID: ${s['id']})')); // Detailed section debug
        if (_allSections.isEmpty) {
          _showMessage("No sections available for your department. Please ask HOD to create sections.");
        }
      });

      // Load all exams that are assigned to this teacher
      final examsSnapshot = await _firestore
          .collection('exams')
          .where('departmentId', isEqualTo: departmentId)
          .where('assignedTeacherIds', arrayContains: teacherId) // Only exams assigned to this teacher
          .get();
      setState(() {
        _allExams = examsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'],
            'totalMarks': data['totalMarks'],
            'subjectId': data['subjectId'],
            'coMapped': List<String>.from(data['coMapped'] ?? []),
            'poMapped': List<String>.from(data['poMapped'] ?? []),
            'coMaxMarks': Map<String, int>.from(data['coMaxMarks'] ?? {}), // IMPORTANT: Load CO max marks
            // Assume if applicableSectionIds is empty, it applies to all sections in the department
            'applicableSectionIds': List<String>.from(data['applicableSectionIds'] ?? []),
          };
        }).toList();
        print('DEBUG: _loadAllMasterData - Loaded _allExams: ${_allExams.length} items'); // Debug print
      });
    } catch (e) {
      _showMessage("Error loading master data: $e");
      print('Error loading master data: $e'); // Debug print
    }
  }

  /// Loads the subjects and sections that are specifically assigned to this teacher.
  /// This data is used to populate the initial dropdowns for selecting exam details.
  Future<void> _loadAssignedSubjectsAndSections() async {
    if (teacherId == null) return;

    try {
      final assignmentSnapshot = await _firestore
          .collection('subjectAssignments')
          .where('teacherId', isEqualTo: teacherId)
          .where('departmentId', isEqualTo: departmentId)
          .get();

      final List<Map<String, dynamic>> tempAssignments = [];
      for (var doc in assignmentSnapshot.docs) {
        final subjectId = doc['subjectId'];
        final sectionId = doc['sectionId'];

        // Get names for display (from already loaded _allSubjects and _allSections)
        // Use firstWhere with orElse to prevent errors if ID is not found
        final subjectName = _allSubjects.firstWhere(
                (sub) => sub['id'] == subjectId,
            orElse: () {
              print('DEBUG: Subject with ID $subjectId not found in _allSubjects. Defaulting to "Unknown Subject".');
              return {'name': 'Unknown Subject'};
            }
        )['name'];

        final sectionDoc = _allSections.firstWhere(
                (sec) => sec['id'] == sectionId,
            orElse: () {
              print('DEBUG: Section with ID $sectionId not found in _allSections for subject assignment $subjectId. Defaulting to "Unknown Section".');
              return {'name': 'Unknown Section'};
            }
        );
        final sectionName = sectionDoc['name'];


        tempAssignments.add({
          'subjectId': subjectId,
          'subjectName': subjectName,
          'sectionId': sectionId,
          'sectionName': sectionName,
        });
      }

      setState(() {
        _assignedSubjectsAndSections = tempAssignments;
      });
      print('DEBUG: _loadAssignedSubjectsAndSections - Loaded _assignedSubjectsAndSections: ${_assignedSubjectsAndSections.length} items'); // Debug print
      _assignedSubjectsAndSections.forEach((assignment) {
        print('   Assignment: Subject: ${assignment['subjectName']} (ID: ${assignment['subjectId']}), Section: ${assignment['sectionName']} (ID: ${assignment['sectionId']})');
      });


      if (_assignedSubjectsAndSections.isEmpty) {
        _showMessage("No subjects or sections assigned to you by HOD.");
      }
    } catch (e) {
      _showMessage("Error loading assigned subjects and sections: $e");
      print('Error loading assigned subjects and sections: $e'); // Debug print
    }
  }

  /// Loads students for the selected section and pre-fills their existing marks for the selected exam.
  Future<void> _loadStudentsAndMarks() async {
    if (_selectedAssignedSectionId == null || _selectedExamId == null || departmentId == null) {
      setState(() {
        _students = [];
        // Dispose existing controllers before clearing the map
        _markControllers.forEach((studentId, coControllers) {
          coControllers.forEach((co, controller) {
            controller.dispose();
          });
        });
        _markControllers.clear();
        _selectedExamDetails = null;
        _selectedSubjectDetails = null;
        _studentPoAttainments.clear();
      });
      return;
    }

    setState(() {
      _isLoadingStudentMarks = true; // Start loading
      _students = []; // Clear previous students
      _markControllers.clear();
      _selectedExamDetails = null;
      _selectedSubjectDetails = null;
      _studentPoAttainments.clear();
    });

    try {
      // 1. Get Exam Details
      final examDoc = _allExams.firstWhere((exam) => exam['id'] == _selectedExamId, orElse: () => {});
      if (examDoc.isEmpty) {
        _showMessage("Selected exam details not found. Please ensure the exam is properly configured by HOD.");
        setState(() { _isLoadingStudentMarks = false; });
        return;
      }
      _selectedExamDetails = examDoc;

      // 2. Get Subject Details (for COs and CO-PO mapping)
      final subjectIdForExam = _selectedExamDetails!['subjectId'];
      if (subjectIdForExam == null) {
        _showMessage("Exam is not linked to a subject. Please ask HOD to link it.");
        setState(() { _isLoadingStudentMarks = false; });
        return;
      }
      final subjectDocSnapshot = await _firestore.collection('subjects').doc(subjectIdForExam).get();
      if (!subjectDocSnapshot.exists) {
        _showMessage("Linked subject details for exam not found. Please ask HOD to configure subject CO-PO mapping.");
        setState(() { _isLoadingStudentMarks = false; });
        return;
      }
      _selectedSubjectDetails = subjectDocSnapshot.data()!;

      // 3. Load Students for the selected section
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('sectionId', isEqualTo: _selectedAssignedSectionId)
          .where('departmentId', isEqualTo: departmentId)
          .get();

      // 4. Load existing marks for these students for the selected exam
      final existingMarksSnapshot = await _firestore
          .collection('studentExamCoPoMarks')
          .where('examId', isEqualTo: _selectedExamId)
          .where('sectionId', isEqualTo: _selectedAssignedSectionId)
          .get();

      final Map<String, Map<String, dynamic>> existingMarksMap = {};
      for (var doc in existingMarksSnapshot.docs) {
        existingMarksMap[doc['studentId']] = {
          'totalMarksScored': doc['totalMarksScored'],
          'coMarks': Map<String, int>.from(doc['coMarks'] ?? {}),
          'docId': doc.id, // Store doc ID for updates
        };
      }

      final List<Map<String, dynamic>> loadedStudents = [];
      final Map<String, Map<String, TextEditingController>> newMarkControllers = {};
      // No need to reinitialize newStudentPoAttainments here as _calculateStudentPoAttainment
      // will set it for each student.

      for (var studentDoc in studentsSnapshot.docs) {
        final studentId = studentDoc.id;
        final studentName = studentDoc['name'];

        // Initialize controllers and pre-fill if marks exist
        final studentExistingMarks = existingMarksMap[studentId];
        final Map<String, TextEditingController> coControllers = {};

        // Overall exam marks
        coControllers['totalMarksScored'] = TextEditingController(
          text: (studentExistingMarks?['totalMarksScored'] ?? '').toString(),
        );

        // CO-wise marks
        final coMapped = _selectedExamDetails!['coMapped'] as List<String>;
        for (String coNo in coMapped) {
          final coMark = studentExistingMarks?['coMarks']?[coNo];
          coControllers[coNo] = TextEditingController(text: (coMark ?? '').toString());
          // Add listener to recalculate PO attainment when CO mark changes
          coControllers[coNo]?.addListener(() => _calculateStudentPoAttainment(studentId));
        }

        newMarkControllers[studentId] = coControllers;
        loadedStudents.add({'id': studentId, 'name': studentName});

        // Immediately calculate PO attainment for loaded marks
        _calculateStudentPoAttainment(studentId); // Always recalculate on load
      }

      setState(() {
        _students = loadedStudents;
        // Dispose old controllers before replacing with new ones
        _markControllers.forEach((studentId, coControllers) {
          coControllers.forEach((co, controller) {
            controller.dispose();
          });
        });
        _markControllers = newMarkControllers;
        _studentPoAttainments.clear(); // Clear before recalculating
        _isLoadingStudentMarks = false; // End loading
      });
      _showMessage("Students and existing marks loaded.");
    } catch (e) {
      _showMessage("Error loading students and marks: $e");
      print('Error loading students and marks: $e'); // Debug print
      setState(() {
        _students = []; // Clear students on error
        _markControllers.clear();
        _selectedExamDetails = null;
        _selectedSubjectDetails = null;
        _studentPoAttainments.clear();
        _isLoadingStudentMarks = false; // End loading on error
      });
    }
  }

  /// Calculates the PO attainment for a single student based on their CO marks.
  void _calculateStudentPoAttainment(String studentId) {
    if (_selectedSubjectDetails == null || _selectedExamDetails == null) return;

    final subjectCoPoMappingRaw = _selectedSubjectDetails!['coPoMapping'] as List<dynamic>?;
    if (subjectCoPoMappingRaw == null) return;

    // Convert raw mapping to a more usable map: {'CO1': ['PO1', 'PO2'], ...}
    final Map<String, List<String>> subjectCoPoMapping = {};
    for (var mapping in subjectCoPoMappingRaw) {
      if (mapping is Map<String, dynamic> && mapping.containsKey('co') && mapping.containsKey('pos')) {
        subjectCoPoMapping[mapping['co'] as String] = List<String>.from(mapping['pos'] ?? []);
      }
    }

    final examCoMaxMarks = Map<String, int>.from(_selectedExamDetails!['coMaxMarks'] ?? {});
    final studentCoMarkControllers = _markControllers[studentId] ?? {};

    final Map<String, double> poScoresSum = {}; // Sum of attainment percentages for each PO
    final Map<String, int> poContributionsCount = {}; // Count of COs contributing to each PO

    // Iterate through each CO mapped to the exam
    final coMapped = _selectedExamDetails!['coMapped'] as List<String>?;
    if (coMapped == null) return; // Add null check for coMapped
    for (String coNo in coMapped) {
      final coMarkController = studentCoMarkControllers[coNo];
      final coMarkScored = double.tryParse(coMarkController?.text ?? '0') ?? 0.0;
      final coMaxMark = examCoMaxMarks[coNo]?.toDouble();

      if (coMaxMark != null && coMaxMark > 0) {
        final coAttainmentPercentage = (coMarkScored / coMaxMark) * 100;

        // Find which POs this CO maps to
        final mappedPOs = subjectCoPoMapping[coNo] ?? [];
        for (String poNo in mappedPOs) {
          poScoresSum.update(poNo, (value) => value + coAttainmentPercentage,
              ifAbsent: () => coAttainmentPercentage);
          poContributionsCount.update(poNo, (value) => value + 1,
              ifAbsent: () => 1);
        }
      }
    }

    // Calculate final average PO attainment percentage
    final Map<String, double> studentPoAttainment = {};
    poScoresSum.forEach((poNo, totalScore) {
      final count = poContributionsCount[poNo] ?? 1;
      studentPoAttainment[poNo] = totalScore / count;
    });

    setState(() {
      _studentPoAttainments[studentId] = studentPoAttainment;
    });
  }

  /// Saves or updates the marks for all students for the selected exam.
  Future<void> _saveStudentMarks() async {
    if (_selectedExamId == null || _selectedAssignedSubjectId == null || _selectedAssignedSectionId == null || teacherId == null || departmentId == null) {
      _showMessage("Please select subject, section, and exam first.");
      return;
    }

    if (_students.isEmpty) {
      _showMessage("No students to save marks for.");
      return;
    }

    List<Future<void>> saveOperations = [];

    for (var student in _students) {
      final studentId = student['id'];
      final studentControllers = _markControllers[studentId];

      if (studentControllers == null) continue;

      final totalMarksScored = int.tryParse(studentControllers['totalMarksScored']?.text ?? '0') ?? 0;
      final Map<String, int> coMarks = {};
      final coMappedByExam = _selectedExamDetails!['coMapped'] as List<String>;

      // Validate and collect CO marks
      final examCoMaxMarks = Map<String, int>.from(_selectedExamDetails!['coMaxMarks'] ?? {});
      for (String coNo in coMappedByExam) {
        final markText = studentControllers[coNo]?.text.trim();
        final mark = int.tryParse(markText ?? '');
        final maxMarkForCo = examCoMaxMarks[coNo] ?? 0;

        if (mark != null) {
          if (maxMarkForCo > 0 && mark > maxMarkForCo) {
            _showMessage("Error: Mark for $coNo for ${student['name']} ($mark) exceeds max ($maxMarkForCo). Please correct.");
            return; // Stop saving and alert
          }
          coMarks[coNo] = mark; // Corrected: assign to coMarks
        } else if (markText != null && markText.isNotEmpty) {
          _showMessage("Error: Invalid mark entered for $coNo for ${student['name']}. Please correct.");
          return; // Stop saving and alert
        }
      }


      // Check if student's marks for this exam already exist
      final existingDoc = await _firestore.collection('studentExamCoPoMarks')
          .where('studentId', isEqualTo: studentId)
          .where('examId', isEqualTo: _selectedExamId)
          .limit(1)
          .get();

      final dataToSave = {
        'studentId': studentId,
        'examId': _selectedExamId,
        'subjectId': _selectedExamDetails!['subjectId'], // Get subjectId from exam details
        'sectionId': _selectedAssignedSectionId,
        'teacherId': teacherId,
        'departmentId': departmentId,
        'totalMarksScored': totalMarksScored,
        'coMarks': coMarks,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (existingDoc.docs.isNotEmpty) {
        // Update existing document
        saveOperations.add(_firestore.collection('studentExamCoPoMarks').doc(existingDoc.docs.first.id).update(dataToSave));
      } else {
        // Add new document
        saveOperations.add(_firestore.collection('studentExamCoPoMarks').add(dataToSave));
      }
    }

    try {
      await Future.wait(saveOperations);
      _showMessage("Marks saved successfully!");
      // After saving, re-load marks to update docIds and ensure fresh state
      _loadStudentsAndMarks();
      // Also refresh the overall attainment summary if a subject is selected
      if (_selectedSubjectIdForCoPoView != null) {
        _loadCoPoAttainment(_selectedSubjectIdForCoPoView!);
      }
    } catch (e) {
      _showMessage("Error saving marks: $e");
      print('Error saving marks: $e'); // Debug print
    }
  }

  /// Loads students created by the current teacher from Firestore.
  Future<void> _loadCreatedStudents() async {
    if (teacherId == null) return;

    try {
      final studentSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('createdBy', isEqualTo: teacherId)
          .get();

      setState(() {
        _createdStudents = studentSnapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc['name'],
          'email': doc['email'],
          'sectionId': doc['sectionId'], // Include sectionId for display/logic
        }).toList();
        print('Loaded _createdStudents: ${_createdStudents.length} items'); // Debug print
      });
    } catch (e) {
      _showMessage("Error loading created students: $e");
      print('Error loading created students: $e'); // Debug print
    }
  }

  /// Loads indirect mark types (e.g., project, viva) defined by HOD
  /// for the current teacher's department.
  Future<void> _loadIndirectMarkTypes() async {
    if (departmentId == null) return;

    try {
      final typesSnapshot = await _firestore
          .collection('indirectMarkTypes')
          .where('departmentId', isEqualTo: departmentId)
          .get();

      setState(() {
        _indirectMarkTypes = typesSnapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc['name'],
          'weight': doc['weight'],
        }).toList();
        print('Loaded _indirectMarkTypes: ${_indirectMarkTypes.length} items'); // Debug print
      });
    } catch (e) {
      _showMessage("Error loading indirect mark types: $e");
      print('Error loading indirect mark types: $e'); // Debug print
    }
  }

  /// Loads indirect marks previously assigned by the current teacher.
  /// Fetches associated student and mark type names for display.
  Future<void> _loadAssignedIndirectMarks() async {
    if (teacherId == null || departmentId == null) return;

    try {
      final marksSnapshot = await _firestore
          .collection('indirectMarksAssigned')
          .where('assignedBy', isEqualTo: teacherId)
          .get();

      List<Map<String, dynamic>> loadedMarks = [];
      for (var doc in marksSnapshot.docs) {
        // Fetch related student and indirect mark type details for display
        final studentDoc = await _firestore.collection('users').doc(doc['studentId']).get();
        final indirectMarkTypeDoc = await _firestore.collection('indirectMarkTypes').doc(doc['indirectMarkTypeId']).get();

        loadedMarks.add({
          'id': doc.id,
          'studentName': studentDoc['name'] ?? 'Unknown Student',
          'markTypeName': indirectMarkTypeDoc['name'] ?? 'Unknown Type',
          'marks': doc['marks'],
          'weight': indirectMarkTypeDoc['weight'] ?? 0,
          'studentId': doc['studentId'],
          'indirectMarkTypeId': doc['indirectMarkTypeId'],
        });
      }

      setState(() {
        _assignedIndirectMarks = loadedMarks;
        print('Loaded _assignedIndirectMarks: ${_assignedIndirectMarks.length} items'); // Debug print
      });
    } catch (e) {
      _showMessage("Error loading assigned indirect marks: $e");
      print('Error loading assigned indirect marks: $e'); // Debug print
    }
  }

  /// Loads the detailed CO-PO mapping and assessment structure for a given subject.
  Future<void> _loadCoPoDataForSubject(String subjectId) async {
    try {
      final subjectDoc = await _firestore.collection('subjects').doc(subjectId).get();

      if (subjectDoc.exists) {
        setState(() {
          _currentSubjectCoPoData = subjectDoc.data();
          print('Loaded CO-PO data for subject $subjectId'); // Debug print
        });
      } else {
        setState(() {
          _currentSubjectCoPoData = null;
        });
        _showMessage("CO-PO data not found for selected subject.");
        print('CO-PO data not found for selected subject: $subjectId'); // Debug print
      }
    } catch (e) {
      _showMessage("Error loading CO-PO data: $e");
      print('Error loading CO-PO data: $e'); // Debug print
    }
  }

  /// Calculates and loads CO-PO attainment summary based on marks assigned
  /// for exams mapped to the selected subject. This calculates *overall* attainment
  /// for the subject, not student-wise.
  Future<void> _loadCoPoAttainment(String subjectId) async {
    if (teacherId == null || departmentId == null) return;

    try {
      final studentExamMarksSnapshot = await _firestore
          .collection('studentExamCoPoMarks') // Collection where CO-PO linked marks are stored
          .where('subjectId', isEqualTo: subjectId)
          .where('teacherId', isEqualTo: teacherId) // Filter by current teacher
          .get();

      Map<String, List<double>> coAttainments = {}; // CO -> list of attainment percentages from each student
      Map<String, List<double>> poAttainments = {}; // PO -> list of attainment percentages from each student

      // Also get the subject's CO-PO mapping
      final subjectDoc = await _firestore.collection('subjects').doc(subjectId).get();
      final Map<String, List<String>> subjectCoPoMapping = {};
      if (subjectDoc.exists) {
        final coPoMappingsRaw = subjectDoc.data()?['coPoMapping'] as List<dynamic>?;
        if (coPoMappingsRaw != null) {
          for (var mapping in coPoMappingsRaw) {
            if (mapping is Map<String, dynamic> && mapping.containsKey('co') && mapping.containsKey('pos')) {
              subjectCoPoMapping[mapping['co'] as String] = List<String>.from(mapping['pos'] ?? []);
            }
          }
        }
      }

      for (var studentMarkDoc in studentExamMarksSnapshot.docs) {
        final examId = studentMarkDoc['examId'];
        final coMarksScored = Map<String, int>.from(studentMarkDoc['coMarks'] ?? {});

        // Get exam details to know coMaxMarks for this specific exam
        final examDetails = _allExams.firstWhere((exam) => exam['id'] == examId, orElse: () => {});
        final examCoMaxMarks = Map<String, int>.from(examDetails['coMaxMarks'] ?? {});
        final coMappedByExam = List<String>.from(examDetails['coMapped'] ?? []);

        // Calculate CO attainments for this student for this exam
        final Map<String, double> studentCurrentCoAttainments = {};
        for (String coNo in coMappedByExam) {
          final scored = (coMarksScored[coNo] ?? 0).toDouble();
          final max = (examCoMaxMarks[coNo] ?? 1).toDouble(); // Prevent division by zero
          if (max > 0) {
            studentCurrentCoAttainments[coNo] = (scored / max) * 100;
          } else {
            studentCurrentCoAttainments[coNo] = 0.0;
          }
        }

        // Aggregate CO attainments across all students for this subject
        studentCurrentCoAttainments.forEach((coNo, attainment) {
          coAttainments.putIfAbsent(coNo, () => []).add(attainment);
        });

        // Calculate PO attainments for this student for this exam
        final Map<String, double> studentCurrentPoAttainments = {};
        final Map<String, int> poTempContributionsCount = {}; // To average out if multiple COs map to same PO for one student
        studentCurrentCoAttainments.forEach((coNo, coAttainment) {
          final mappedPOs = subjectCoPoMapping[coNo] ?? [];
          for (String poNo in mappedPOs) {
            studentCurrentPoAttainments.update(poNo, (value) => value + coAttainment, ifAbsent: () => coAttainment);
            poTempContributionsCount.update(poNo, (value) => value + 1, ifAbsent: () => 1);
          }
        });

        // Average out student's PO attainment for this exam based on contributing COs
        studentCurrentPoAttainments.forEach((poNo, totalScore) {
          final count = poTempContributionsCount[poNo] ?? 1;
          poAttainments.putIfAbsent(poNo, () => []).add(totalScore / count);
        });
      }

      List<Map<String, dynamic>> summary = [];

      // Calculate final average CO attainment across all students for this subject
      coAttainments.forEach((co, scoresList) {
        double averageScore = scoresList.isEmpty ? 0.0 : scoresList.reduce((a, b) => a + b) / scoresList.length;
        summary.add({
          'type': 'CO',
          'code': co,
          'averageScoreRatio': averageScore / 100, // Store as ratio
          'percentage': averageScore, // Store as percentage
        });
      });

      // Calculate final average PO attainment across all students for this subject
      poAttainments.forEach((po, scoresList) {
        double averageScore = scoresList.isEmpty ? 0.0 : scoresList.reduce((a, b) => a + b) / scoresList.length;
        summary.add({
          'type': 'PO',
          'code': po,
          'averageScoreRatio': averageScore / 100, // Store as ratio
          'percentage': averageScore, // Store as percentage
        });
      });

      // Sort summary for better readability (e.g., CO1, CO2, PO1, PO2)
      summary.sort((a, b) {
        if (a['type'] != b['type']) {
          return (a['type'] as String).compareTo(b['type'] as String);
        }
        return (a['code'] as String).compareTo(b['code'] as String);
      });

      setState(() {
        _attainmentSummary = summary;
        print('Loaded _attainmentSummary: ${_attainmentSummary.length} items'); // Debug print
      });
    } catch (e) {
      _showMessage("Error loading CO-PO attainment: $e");
      print('Error loading CO-PO attainment: $e'); // Debug print
    }
  }

  /// Loads CO-PO data for a specific subject for setup/editing.
  Future<void> _loadSubjectCoPoMapping(String subjectId) async {
    try {
      final subjectDoc = await _firestore.collection('subjects').doc(subjectId).get();
      if (subjectDoc.exists) {
        final data = subjectDoc.data()!;
        setState(() {
          _currentSubjectCoPoData = data; // Keep for the overview section
          _currentCourseOutcomes = List<Map<String, dynamic>>.from(data['courseOutcomes'] ?? []);

          // Convert List<Map<String, dynamic>> to Map<String, List<String>> for _currentCoPoMappings
          _currentCoPoMappings = {};
          final coPoMappingRaw = data['coPoMapping'] as List<dynamic>?;
          if (coPoMappingRaw != null) {
            for (var entry in coPoMappingRaw) {
              if (entry is Map<String, dynamic> && entry.containsKey('co') && entry.containsKey('pos')) {
                _currentCoPoMappings[entry['co'] as String] = List<String>.from(entry['pos'] ?? []);
              }
            }
          }

          // Initialize _currentAssessmentStructure from fetched data
          _currentAssessmentStructure = Map<String, dynamic>.from(data['assessmentStructure'] ?? {});
          // Ensure all expected assessment types are present, even if empty in DB
          for (String type in _assessmentTypes) {
            _currentAssessmentStructure.putIfAbsent(type, () => {'activity': '', 'totalMarks': 0, 'components': [], 'sections': []});
          }

          print('Teacher: Loaded CO-PO data for subject $subjectId');
        });
        _showMessage("CO-PO data loaded for subject.");
      } else {
        setState(() {
          _currentSubjectCoPoData = null;
          _currentCourseOutcomes = [];
          _currentCoPoMappings = {};
          _currentAssessmentStructure = {}; // Reset to empty if no data
          // Initialize empty structure for all assessment types
          for (String type in _assessmentTypes) {
            _currentAssessmentStructure[type] = {'activity': '', 'totalMarks': 0, 'components': [], 'sections': []};
          }
        });
        _showMessage("No existing CO-PO data for this subject. Start defining.");
        print('Teacher: No CO-PO data for subject $subjectId, initializing empty.');
      }
    } catch (e) {
      _showMessage("Error loading CO-PO data: $e");
      print('Teacher: Error loading CO-PO data: $e');
    }
  }

  /// Saves or updates the CO-PO data for the selected subject.
  Future<void> _saveSubjectCoPoMapping() async {
    if (_selectedSubjectIdForCoPoSetup == null || departmentId == null) {
      _showMessage("Please select a subject first.");
      return;
    }

    try {
      // Convert _currentCoPoMappings back to List<Map<String, dynamic>> for Firestore
      final List<Map<String, dynamic>> coPoMappingList = _currentCoPoMappings.entries.map((entry) => {
        'co': entry.key,
        'pos': entry.value,
      }).toList();

      await _firestore.collection('subjects').doc(_selectedSubjectIdForCoPoSetup).update({
        'courseOutcomes': _currentCourseOutcomes,
        'coPoMapping': coPoMappingList,
        'assessmentStructure': _currentAssessmentStructure,
        'lastUpdatedBy': teacherId, // Teacher is now updating
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      _showMessage("Subject CO-PO configuration saved successfully!");
      await _loadSubjectCoPoMapping(_selectedSubjectIdForCoPoSetup!); // Reload to confirm
      await _loadAllMasterData(); // Reload exams, subjects etc.
      await _loadCoPoAttainment(_selectedSubjectIdForCoPoSetup!); // Recalculate attainment if needed
    } catch (e) {
      _showMessage("Error saving subject CO-PO configuration: $e");
      print('Error saving subject CO-PO configuration: $e');
    }
  }

  // Dialog for adding assessment components/sections to assessment structure
  void _showAddComponentDialog(String assessmentType) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController marksController = TextEditingController();
    final TextEditingController coMappedController = TextEditingController();
    final TextEditingController poMappedController = TextEditingController();
    final TextEditingController questionTypeController = TextEditingController(); // For Semester Exam sections

    bool isSemesterExam = assessmentType == 'Semester Examination (Theory Paper)';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add ${isSemesterExam ? 'Section' : 'Component'} to $assessmentType"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(controller: nameController, labelText: isSemesterExam ? "Section Name (e.g., Part A)" : "Component Name"),
              if (isSemesterExam) ...[
                const SizedBox(height: 10),
                _buildTextField(controller: questionTypeController, labelText: "Question Type (e.g., Short Answer)"),
              ],
              const SizedBox(height: 10),
              _buildTextField(controller: marksController, labelText: "Marks for Component/Section", keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              // Hint for CO/PO mapping
              Text("Enter COs (e.g., CO1, CO2) and POs (e.g., PO1, PO2) separated by commas.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              _buildTextField(controller: coMappedController, labelText: "COs Mapped (e.g., CO1,CO2)"),
              const SizedBox(height: 10),
              _buildTextField(controller: poMappedController, labelText: "POs Mapped (e.g., PO1,PO2)"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          _buildElevatedButton(
            text: "Add",
            onPressed: () {
              final name = nameController.text.trim();
              final marks = int.tryParse(marksController.text.trim()) ?? 0;
              final coMapped = coMappedController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              final poMapped = poMappedController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              final questionType = questionTypeController.text.trim();

              if (name.isNotEmpty && marks > 0) {
                Map<String, dynamic> newItem = {
                  'name': name,
                  'marks': marks,
                  'coMapped': coMapped,
                  'poMapped': poMapped,
                };
                setState(() { // setState inside dialog to update local state and trigger rebuild
                  if (isSemesterExam) {
                    newItem['questionType'] = questionType;
                    _currentAssessmentStructure.putIfAbsent(assessmentType, () => {'sections': []});
                    (_currentAssessmentStructure[assessmentType]['sections'] as List).add(newItem);
                  } else {
                    _currentAssessmentStructure.putIfAbsent(assessmentType, () => {'components': []});
                    (_currentAssessmentStructure[assessmentType]['components'] as List).add(newItem);
                  }
                });

                Navigator.of(context).pop();
              } else {
                _showMessage("Please enter valid name and marks.");
              }
            },
          ),
        ],
      ),
    );
  }

  // Simplified Assessment Type Editor (similar to HOD, but directly in Column)
  Widget _buildSimplifiedAssessmentTypeEditor(String type) {
    return ExpansionTile(
      title: Text(type, style: TextStyle(fontWeight: FontWeight.w500, color: textBlackColor)),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                controller: TextEditingController(text: _currentAssessmentStructure[type]?['activity'] ?? ''),
                labelText: "Activity (e.g., Mid-Term Exam)",
                onChanged: (val) {
                  _currentAssessmentStructure.putIfAbsent(type, () => {});
                  _currentAssessmentStructure[type]['activity'] = val;
                },
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: TextEditingController(text: _currentAssessmentStructure[type]?['totalMarks']?.toString() ?? ''),
                labelText: "Total Marks for $type",
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  _currentAssessmentStructure.putIfAbsent(type, () => {});
                  _currentAssessmentStructure[type]['totalMarks'] = int.tryParse(val) ?? 0;
                },
              ),
              const SizedBox(height: 10),
              Text("Components/Sections for $type:", style: TextStyle(fontWeight: FontWeight.w500, color: textBlackColor)),
              // Display existing components/sections for this assessment type
              if (_currentAssessmentStructure[type]?['components'] != null && (type != 'Semester Examination (Theory Paper)'))
                ...(_currentAssessmentStructure[type]['components'] as List).map((comp) =>
                    ListTile(
                      title: Text("${comp['name']} (${comp['marks']} marks)"),
                      subtitle: Text("CO: ${comp['coMapped']?.join(', ')}, PO: ${comp['poMapped']?.join(', ')}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            (_currentAssessmentStructure[type]['components'] as List).remove(comp);
                          });
                        },
                      ),
                    )).toList()
              else if (_currentAssessmentStructure[type]?['sections'] != null && (type == 'Semester Examination (Theory Paper)'))
                ...(_currentAssessmentStructure[type]['sections'] as List).map((section) =>
                    ListTile(
                      title: Text("${section['name']} - Q Type: ${section['questionType']} (${section['marks']} marks)"),
                      subtitle: Text("CO: ${section['coMapped']?.join(', ')}, PO: ${section['poMapped']?.join(', ')}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            (_currentAssessmentStructure[type]['sections'] as List).remove(section);
                          });
                        },
                      ),
                    )).toList()
              else
                const Text("No components defined yet."),
              const SizedBox(height: 10),
              _buildElevatedButton(
                onPressed: () {
                  _showAddComponentDialog(type);
                },
                text: "Add Component/Section to $type",
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Loads existing CO-PO mapping and max marks for a specific exam.
  Future<void> _loadExamCoPoMapping(String examId) async {
    try {
      final examDoc = await _firestore.collection('exams').doc(examId).get();
      if (examDoc.exists) {
        final data = examDoc.data()!;
        setState(() {
          _selectedSubjectForExamCoPo = data['subjectId'] as String?;
          _selectedCoMappedForExam = List<String>.from(data['coMapped'] ?? []);
          _selectedPoMappedForExam = List<String>.from(data['poMapped'] ?? []);

          // Populate CO max marks controllers
          final coMaxMarks = Map<String, int>.from(data['coMaxMarks'] ?? {});
          _examCoMaxMarksControllers.forEach((key, controller) => controller.dispose()); // Dispose old ones
          _examCoMaxMarksControllers.clear();
          for (String coNo in _selectedCoMappedForExam) {
            _examCoMaxMarksControllers[coNo] = TextEditingController(text: coMaxMarks[coNo]?.toString() ?? '');
          }
        });
        // If subject is linked, load its CO-PO data as well for display/selection
        if (_selectedSubjectForExamCoPo != null) {
          await _loadSubjectCoPoMapping(_selectedSubjectForExamCoPo!);
        }
        _showMessage("Exam CO-PO data loaded.");
      } else {
        setState(() {
          _selectedSubjectForExamCoPo = null;
          _selectedCoMappedForExam = [];
          _selectedPoMappedForExam = [];
          _examCoMaxMarksControllers.forEach((key, controller) => controller.dispose());
          _examCoMaxMarksControllers.clear();
        });
        _showMessage("No existing CO-PO data for this exam. Start defining.");
      }
    } catch (e) {
      _showMessage("Error loading exam CO-PO data: $e");
      print('Error loading exam CO-PO data: $e');
    }
  }

  /// Updates CO-PO mapping and max marks for a specific exam.
  Future<void> _updateExamCoPoMapping() async {
    if (_selectedExamForCoPoEdit == null || _selectedSubjectForExamCoPo == null) {
      _showMessage("Please select an exam and its associated subject first.");
      return;
    }

    // Validate CO max marks
    final Map<String, int> coMaxMarksToSave = {};
    for (String coNo in _selectedCoMappedForExam) {
      final controller = _examCoMaxMarksControllers[coNo];
      final marks = int.tryParse(controller?.text ?? '');
      if (marks == null || marks < 0) {
        _showMessage("Please enter valid positive max marks for all selected COs.");
        return;
      }
      coMaxMarksToSave[coNo] = marks;
    }

    try {
      await _firestore.collection('exams').doc(_selectedExamForCoPoEdit).update({
        'subjectId': _selectedSubjectForExamCoPo, // Ensure subject is explicitly linked
        'coMapped': _selectedCoMappedForExam,
        'poMapped': _selectedPoMappedForExam,
        'coMaxMarks': coMaxMarksToSave,
        'lastUpdatedBy': teacherId,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      _showMessage("Exam CO-PO mapping updated successfully!");
      await _loadExamCoPoMapping(_selectedExamForCoPoEdit!); // Reload to confirm
      await _loadAllMasterData(); // Reload exams to get updated CO max marks for mark entry
      if (_selectedSubjectIdForCoPoView != null) {
        _loadCoPoAttainment(_selectedSubjectIdForCoPoView!); // Recalculate attainment if this exam impacts it
      }
    } catch (e) {
      _showMessage("Error updating exam CO-PO mapping: $e");
      print('Error updating exam CO-PO mapping: $e');
    }
  }

  /// Handles student creation in Firebase Authentication and Firestore.
  Future<void> _createStudent() async {
    final email = _studentEmailController.text.trim();
    final name = _studentNameController.text.trim();
    final password = _studentPasswordController.text.trim();
    final sectionId = _selectedSectionIdForStudentCreation; // Get selected section ID

    if (email.isEmpty || name.isEmpty || password.isEmpty || sectionId == null) {
      _showMessage("Please enter name, email, password, and select a section.");
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final studentUid = userCredential.user!.uid;

      await _firestore.collection('users').doc(studentUid).set({
        'email': email,
        'name': name,
        'role': 'student',
        'createdBy': teacherId, // Link student to the teacher who created them
        'departmentId': departmentId, // Associate student with teacher's department
        'sectionId': sectionId, // Associate student with the selected section
        'createdAt': FieldValue.serverTimestamp(),
      });

      _studentEmailController.clear();
      _studentNameController.clear();
      _studentPasswordController.clear();
      setState(() {
        _selectedSectionIdForStudentCreation = null; // Clear selected section
      });

      _showMessage("Student created successfully.");
      _loadCreatedStudents(); // Refresh the list of created students
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showMessage("This email is already registered.");
      } else {
        _showMessage("Auth error: ${e.message}");
      }
    } catch (e) {
      _showMessage("Unexpected error: $e");
    }
  }

  /// Assigns indirect marks to a student for a specific indirect mark type.
  Future<void> _assignIndirectMarks() async {
    final studentId = _selectedStudentIdForIndirectMarks;
    final marks = int.tryParse(_indirectMarksGivenController.text.trim()) ?? -1;
    final indirectMarkTypeId = _selectedIndirectMarkTypeId;

    if (indirectMarkTypeId == null || studentId == null || marks < 0) {
      _showMessage("Select indirect mark type and valid student, and enter valid marks.");
      return;
    }

    // Retrieve weight for the selected indirect mark type
    final markType = _indirectMarkTypes.firstWhere((type) => type['id'] == indirectMarkTypeId, orElse: () => {});
    final weight = markType['weight'] as int?;

    if (weight == null || marks > weight) {
      _showMessage("Marks obtained cannot exceed weightage ($weight).");
      return;
    }

    try {
      await _firestore.collection('indirectMarksAssigned').add({
        'indirectMarkTypeId': indirectMarkTypeId,
        'studentId': studentId,
        'marks': marks,
        'assignedBy': teacherId,
        'assignedAt': FieldValue.serverTimestamp(),
        'departmentId': departmentId,
      });

      _indirectMarksGivenController.clear();
      setState(() {
        _selectedStudentIdForIndirectMarks = null;
        _selectedIndirectMarkTypeId = null;
      });

      final student =
      _createdStudents.firstWhere((s) => s['id'] == studentId, orElse: () => {});
      _showMessage("Indirect marks assigned to ${student['name'] ?? 'student'}.");
      _loadAssignedIndirectMarks(); // Refresh the list of assigned indirect marks
    } catch (e) {
      _showMessage("Error assigning indirect marks: $e");
    }
  }

  /// Deletes a student record from Firestore.
  Future<void> _deleteStudent(String studentId) async {
    try {
      await _firestore.collection('users').doc(studentId).delete();
      _loadCreatedStudents(); // Refresh the student list
      _showMessage('Student deleted successfully');
    } catch (e) {
      _showMessage("Error deleting student: $e");
    }
  }

  /// Updates a student's name and email in Firestore.
  Future<void> _updateStudent(String studentId, String newName, String newEmail) async {
    try {
      await _firestore.collection('users').doc(studentId).update({
        'name': newName,
        'email': newEmail,
      });
      _loadCreatedStudents(); // Refresh the student list
      _showMessage('Student updated successfully');
    } catch (e) {
      _showMessage("Error updating student: $e");
    }
  }

  /// Deletes an assigned indirect mark record from Firestore.
  Future<void> _deleteIndirectMark(String markId) async {
    try {
      await _firestore.collection('indirectMarksAssigned').doc(markId).delete();
      _loadAssignedIndirectMarks(); // Refresh the indirect marks list
      _showMessage('Indirect mark deleted successfully');
    } catch (e) {
      _showMessage("Error deleting indirect mark: $e");
    }
  }

  /// Updates the marks for an assigned indirect mark in Firestore.
  Future<void> _updateIndirectMark(String markId, int newMarks) async {
    try {
      await _firestore.collection('indirectMarksAssigned').doc(markId).update({
        'marks': newMarks,
      });
      _loadAssignedIndirectMarks(); // Refresh the indirect marks list
      _showMessage('Indirect mark updated successfully');
    } catch (e) {
      _showMessage("Error updating indirect mark: $e");
    }
  }

  /// Displays a SnackBar message to the user for feedback.
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: textBlackColor)),
        backgroundColor: primaryColor.withOpacity(0.8),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- UI Components based on guidelines ---

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

  /// Builds a consistent TextField with common styling.
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
    bool obscureText = false,
    int? maxLines = 1,
    ValueChanged<String>? onChanged, // Added onChanged parameter
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: textBlackColor),
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged, // Pass onChanged to the TextField
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

  /// Builds a consistent DropdownButtonFormField with theme-defined styling.
  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    Key? key, // Allow key for specific dropdowns
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

  /// Builds a consistent card for displaying lists of data, with a fixed height.
  Widget _listDisplayCard({required String title, required Widget content}) {
    return _buildAdminCard(
      title: title,
      content: SizedBox(
        height: 200, // Fixed height for lists to prevent excessive scrolling
        child: content,
      ),
    );
  }

  /// Builds a consistent card for displaying tables, allowing horizontal scrolling.
  Widget _buildTableCard({required String title, required Widget content}) {
    return _buildAdminCard(
      title: title,
      content: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: content,
      ),
    );
  }

  /// Builds the table for student mark entry and PO attainment display.
  Widget _buildMarkEntryTable() {
    final coMappedByExam = _selectedExamDetails!['coMapped'] as List<String>;
    final examTotalMarks = _selectedExamDetails!['totalMarks'] as int;
    final examCoMaxMarks = Map<String, int>.from(_selectedExamDetails!['coMaxMarks'] ?? {});

    List<TableRow> tableRows = [];

    // Header Row
    List<Widget> headerCells = [
      _buildTableCell(const Text("Student Name"), isHeader: true),
      _buildTableCell(Text("Total Marks ($examTotalMarks)"), isHeader: true),
    ];
    for (String coNo in coMappedByExam) {
      final maxCoMark = examCoMaxMarks[coNo] ?? 'N/A'; // Get max mark for this specific CO
      headerCells.add(_buildTableCell(Text("$coNo (Max: $maxCoMark)"), isHeader: true));
    }
    headerCells.add(_buildTableCell(const Text("PO Attainment (%)"), isHeader: true));
    tableRows.add(TableRow(children: headerCells));

    // Data Rows for each student
    for (var student in _students) {
      final studentId = student['id'];
      final studentName = student['name'];
      final studentControllers = _markControllers[studentId] ?? {};
      final poAttainments = _studentPoAttainments[studentId] ?? {};

      List<Widget> dataCells = [
        _buildTableCell(Text(studentName as String)),
        _buildTableCell(
          TextField(
            controller: studentControllers['totalMarksScored'],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.zero),
            style: TextStyle(color: textBlackColor),
          ),
        ),
      ];

      for (String coNo in coMappedByExam) {
        dataCells.add(_buildTableCell(
          TextField(
            controller: studentControllers[coNo],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.zero),
            style: TextStyle(color: textBlackColor),
          ),
        ));
      }

      // Format PO Attainment for display
      String poAttainmentText = poAttainments.entries
          .map((entry) => "${entry.key}: ${entry.value.toStringAsFixed(1)}%")
          .join('\n');
      dataCells.add(_buildTableCell(Text(poAttainmentText, style: TextStyle(color: textBlackColor))));

      tableRows.add(TableRow(children: dataCells));
    }

    return Table(
      border: TableBorder.all(color: cardBorderColor),
      columnWidths: {
        0: const IntrinsicColumnWidth(), // Student Name
        1: const FixedColumnWidth(100), // Total Marks
        for (int i = 0; i < coMappedByExam.length; i++)
          (i + 2): const FixedColumnWidth(80), // CO Marks
        (coMappedByExam.length + 2): const FixedColumnWidth(150), // PO Attainment
      },
      children: tableRows,
    );
  }

  /// Helper to build a table cell.
  Widget _buildTableCell(Widget content, {bool isHeader = false}) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: isHeader ? primaryColor.withOpacity(0.3) : cardBackgroundColor,
      alignment: isHeader ? Alignment.center : Alignment.centerLeft,
      child: content,
    );
  }

  // --- CO-PO Mapping Definition Section (for display) ---
  /// Displays Course Outcomes, Program Outcomes, CO-PO Mapping Table,
  /// Assessment Structure, and Total Marks Distribution for a selected subject.
  Widget _buildCoPoDefinitionSection() {
    // Filter _assignedSubjectsAndSections to get unique subjects for the dropdown
    final uniqueAssignedSubjectsForCoPo = _assignedSubjectsAndSections
        .map((e) => {'id': e['subjectId'] as String, 'name': e['subjectName'] as String})
        .toSet()
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminCard(
            title: "1. Select Subject for CO-PO Setup",
            content: Column(
              children: [
                _buildDropdown<String>(
                  value: _selectedSubjectIdForCoPoSetup, // Use the setup-specific selected ID
                  hint: uniqueAssignedSubjectsForCoPo.isEmpty ? "No Subjects Assigned" : "Select Subject",
                  items: uniqueAssignedSubjectsForCoPo.map<DropdownMenuItem<String>>((subject) {
                    return DropdownMenuItem<String>(
                      value: subject['id'],
                      child: Text(subject['name']!),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    setState(() {
                      _selectedSubjectIdForCoPoSetup = val;
                      _currentSubjectCoPoData = null; // Clear existing data for display
                      _currentCourseOutcomes = []; // Clear current COs
                      _currentCoPoMappings = {}; // Clear current CO-PO mappings
                      _currentAssessmentStructure = {}; // Clear assessment structure
                      _coNoController.clear();
                      _coDescriptionController.clear();
                    });
                    if (val != null) {
                      await _loadSubjectCoPoMapping(val); // Load editable CO-PO data
                      await _loadCoPoAttainment(val); // Also load attainment for consistency
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Define Course Outcomes (COs) and Map to POs
          if (_selectedSubjectIdForCoPoSetup != null)
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
                    itemCount: _currentCourseOutcomes.length,
                    itemBuilder: (context, index) {
                      final co = _currentCourseOutcomes[index];
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
                                          if (_currentCoPoMappings.containsKey(oldCoNo)) {
                                            List<String> pos = _currentCoPoMappings.remove(oldCoNo)!;
                                            _currentCoPoMappings[text] = pos;
                                          } else {
                                            _currentCoPoMappings.putIfAbsent(text, () => []);
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
                                        final isSelected = (_currentCoPoMappings[currentCoNo] ?? []).contains(poCode);
                                        return FilterChip(
                                          label: Text(poCode),
                                          selected: isSelected,
                                          onSelected: (selected) {
                                            setState(() {
                                              List<String> currentPOs = _currentCoPoMappings.putIfAbsent(currentCoNo, () => []);
                                              if (selected) {
                                                if (!currentPOs.contains(poCode)) currentPOs.add(poCode);
                                              } else {
                                                currentPOs.remove(poCode);
                                              }
                                              _currentCoPoMappings[currentCoNo] = currentPOs;
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
                                            _currentCourseOutcomes.removeAt(index);
                                            _currentCoPoMappings.remove(removedCoNo);
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
                        final newCoNo = "CO${_currentCourseOutcomes.length + 1}";
                        _currentCourseOutcomes.add({'coNo': newCoNo, 'description': ''});
                        _currentCoPoMappings[newCoNo] = [];
                      });
                    },
                    text: "Add New Course Outcome",
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Section 3: Define Subject Assessment Structure (Simplified)
          if (_selectedSubjectIdForCoPoSetup != null)
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
          if (_selectedSubjectIdForCoPoSetup != null)
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
                    items: _allExams.map<DropdownMenuItem<String>>((exam) {
                      return DropdownMenuItem<String>(
                        value: exam['id'] as String,
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
                      items: _allSubjects.map<DropdownMenuItem<String>>((subject) {
                        return DropdownMenuItem<String>(
                          value: subject['id'] as String,
                          child: Text(subject['name'] as String),
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
                      children: _currentCourseOutcomes.map((co) { // Use _currentCourseOutcomes for available COs
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
                              // Removed 'key' parameter as it's not defined in _buildTextField
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
          if (_selectedSubjectIdForCoPoSetup != null)
            _buildElevatedButton(
              onPressed: _saveSubjectCoPoMapping,
              text: "Save All Subject Configuration",
            ),
        ],
      ),
    );
  }

  /// Helper widget to display individual assessment components within the CO-PO mapping section.
  Widget _buildAssessmentComponent({
    required String title,
    required Map<String, dynamic>? data,
    bool isSemesterExam = false,
  }) {
    if (data == null) return const SizedBox.shrink(); // Hide if no data

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
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
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textBlackColor,
                ),
              ),
              const SizedBox(height: 10),
              Text('Activity: ${data['activity'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
              Text('Total Marks: ${data['totalMarks'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              // Dynamic DataTable based on whether it's a semester exam or not
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 10,
                  headingRowColor: MaterialStateProperty.all(primaryColor.withOpacity(0.1)),
                  columns: isSemesterExam
                      ? const [
                    DataColumn(label: Text('Section', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Q Type', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Marks', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('CO Mapped', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('PO Mapped', style: TextStyle(fontWeight: FontWeight.bold))),
                  ]
                      : const [
                    DataColumn(label: Text('Component', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Marks', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('CO Mapped', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('PO Mapped', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: (isSemesterExam ? data['sections'] : data['components'])
                      ?.map<DataRow>((item) {
                    final coMapped = (item['coMapped'] as List?)?.join(', ') ?? 'N/A';
                    final poMapped = (item['poMapped'] as List?)?.join(', ') ?? 'N/A';
                    return DataRow(cells: [
                      if (isSemesterExam) DataCell(Text((item['name'] as String?) ?? 'N/A')),
                      DataCell(Text(isSemesterExam ? (item['questionType'] as String?) ?? 'N/A' : (item['name'] as String?) ?? 'N/A')),
                      DataCell(Text(item['marks']?.toString() ?? 'N/A')),
                      DataCell(Text(coMapped)),
                      DataCell(Text(poMapped)),
                    ]);
                  }).toList()?.cast<DataRow>() ?? [], // Cast to DataRow to satisfy type checker
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CO-PO Attainment Overview Section ---
  /// Displays the calculated CO-PO attainment summary for the selected subject.
  Widget _buildCoPoAttainmentOverviewSection() {
    // Filter _assignedSubjectsAndSections to get unique subjects for the dropdown
    final uniqueAssignedSubjectsForCoPo = _assignedSubjectsAndSections
        .map((e) => {'id': e['subjectId'] as String, 'name': e['subjectName'] as String})
        .toSet()
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminCard(
            title: "CO-PO Attainment Overview",
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdown<String>(
                  value: _selectedSubjectIdForCoPoView, // Re-use the same selection for consistency
                  hint: uniqueAssignedSubjectsForCoPo.isEmpty ? "No Subjects Assigned" : "Select Subject",
                  items: uniqueAssignedSubjectsForCoPo.map<DropdownMenuItem<String>>((subject) {
                    return DropdownMenuItem<String>(
                      value: subject['id'],
                      child: Text(subject['name']!),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    setState(() {
                      _selectedSubjectIdForCoPoView = val;
                      _attainmentSummary = []; // Clear attainment summary
                    });
                    if (val != null) {
                      await _loadCoPoAttainment(val); // Reload attainment data for new subject
                    }
                  },
                ),
                const SizedBox(height: 20),
                if (_selectedSubjectIdForCoPoView != null && _attainmentSummary.isNotEmpty)
                  _buildTableCard(
                    title: "Attainment Summary for Selected Subject",
                    content: DataTable(
                      columnSpacing: 20,
                      headingRowColor: MaterialStateProperty.all(primaryColor.withOpacity(0.2)),
                      columns: const [
                        DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Avg Score', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Attainment %', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _attainmentSummary.map((data) => DataRow(cells: [
                        DataCell(Text(data['type'] as String)),
                        DataCell(Text(data['code'] as String)),
                        DataCell(Text((data['averageScoreRatio'] as double).toStringAsFixed(2))),
                        DataCell(Text("${(data['percentage'] as double).toStringAsFixed(2)}%")),
                      ])).toList(),
                    ),
                  )
                else if (_selectedSubjectIdForCoPoView != null && _attainmentSummary.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text("No CO-PO attainment data recorded for this subject yet.\n(Ensure exams are assigned marks and linked to COs/POs.)"),
                  ))
                else
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text("Select a subject to view attainment data."),
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog to edit an indirect mark.
  void _showEditIndirectMarkDialog(Map<String, dynamic> mark) {
    final TextEditingController editMarksController =
    TextEditingController(text: mark['marks'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Marks for ${mark['studentName']} - ${mark['markTypeName']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(
              controller: editMarksController,
              labelText: "New Marks (Max: ${mark['weight']})",
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          _buildElevatedButton( // Re-use consistent button styling
            text: "Update",
            onPressed: () {
              final newMarks = int.tryParse(editMarksController.text);
              if (newMarks != null && newMarks >= 0 && newMarks <= (mark['weight'] as int)) {
                _updateIndirectMark(mark['id'] as String, newMarks);
                Navigator.of(context).pop();
              } else {
                _showMessage("Invalid marks. Must be between 0 and ${mark['weight']}.");
              }
            },
          ),
        ],
      ),
    );
  }

  /// Dialog for editing student details.
  Future<void> _showEditStudentDialog(Map<String, dynamic> student) async {
    final nameController = TextEditingController(text: student['name'] as String);
    final emailController = TextEditingController(text: student['email'] as String);

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Make column only take necessary space
              children: [
                _buildTextField( // Re-use consistent TextField styling
                  controller: nameController,
                  labelText: 'Name',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: emailController,
                  labelText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            _buildElevatedButton( // Re-use consistent button styling
              text: 'Update',
              onPressed: () {
                _updateStudent(student['id'] as String, nameController.text, emailController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter assigned subjects to get unique subject IDs for the first dropdown
    final uniqueAssignedSubjects = _assignedSubjectsAndSections
        .map((e) => {'id': e['subjectId'] as String, 'name': e['subjectName'] as String})
        .toSet()
        .toList();

    // Filter sections based on selected subject
    // This list should contain sections that are part of the teacher's subject assignments
    final sectionsForSelectedSubject = _assignedSubjectsAndSections
        .where((e) => e['subjectId'] == _selectedAssignedSubjectId)
        .map((e) => {'id': e['sectionId'] as String, 'name': e['sectionName'] as String})
        .toSet() // Use toSet to ensure unique sections if a subject is assigned to the same section multiple times (unlikely but good for robustness)
        .toList();


    // Filter exams based on selected subject and applicable sections
    final examsForSelectedSubjectAndSection = _allExams
        .where((exam) {
      bool subjectMatches = exam['subjectId'] == _selectedAssignedSubjectId;
      bool sectionApplies = false;

      // If exam has no specific applicable sections, it applies to all in the department
      if (exam['applicableSectionIds'] == null || (exam['applicableSectionIds'] as List).isEmpty) {
        // If no sections are explicitly listed in the exam, it applies to all sections
        // that the teacher is assigned to for this subject.
        sectionApplies = _selectedAssignedSectionId != null &&
            sectionsForSelectedSubject.any((s) => s['id'] == _selectedAssignedSectionId);
      } else {
        // If specific applicableSectionIds are listed, check if the selected section is one of them
        sectionApplies = _selectedAssignedSectionId != null &&
            (exam['applicableSectionIds'] as List).contains(_selectedAssignedSectionId);
      }
      return subjectMatches && sectionApplies;
    }).toList();


    // Debug prints to help diagnose dropdown issues
    print('BUILD: Current _selectedAssignedSubjectId: $_selectedAssignedSubjectId');
    print('BUILD: Current _selectedAssignedSectionId: $_selectedAssignedSectionId');
    print('BUILD: Unique Assigned Subjects for dropdown: ${uniqueAssignedSubjects.length} items');
    print('BUILD: Sections for selected subject: ${sectionsForSelectedSubject.length} items');
    sectionsForSelectedSubject.forEach((s) => print('   Available Section (for dropdown): ${s['name']} (ID: ${s['id']})'));
    print('BUILD: Exams for selected subject and section: ${examsForSelectedSubjectAndSection.length} items');


    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      // Removed AppBar and replaced with sidebar
      body: teacherId == null || departmentId == null
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator
          : Row(
        children: [
          // --- Sidebar Navigation ---
          Padding(
            padding: const EdgeInsets.all(16.0), // Padding around the sidebar card
            child: Container(
              width: 280, // Increased width for better text visibility
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
                  _buildSidebarItem(Icons.person_add_alt_1_outlined, "Create Student", 0),
                  _buildSidebarItem(Icons.people_alt_outlined, "Created Students List", 1),
                  const Divider(),
                  _buildSidebarItem(Icons.grade_outlined, "Enter Exam Marks", 2),
                  _buildSidebarItem(Icons.assignment_ind_outlined, "Assign Indirect Marks", 3),
                  _buildSidebarItem(Icons.list_alt, "Assigned Indirect Marks", 4),
                  const Divider(),
                  _buildSidebarItem(Icons.school_outlined, "CO-PO Definition", 5),
                  _buildSidebarItem(Icons.analytics_outlined, "CO-PO Attainment", 6),

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
        return "Create Student";
      case 1:
        return "Created Students List";
      case 2:
        return "Enter Exam Marks (CO-PO Enabled)";
      case 3:
        return "Assign Indirect Marks";
      case 4:
        return "Assigned Indirect Marks List";
      case 5:
        return "CO-PO Definition Overview";
      case 6:
        return "CO-PO Attainment Summary";
      default:
        return "Teacher Dashboard";
    }
  }

  /// Returns the widget content for the main content area based on the selected sidebar index.
  Widget _getPageContent(int index) {
    switch (index) {
      case 0:
        return _buildCreateStudentSection();
      case 1:
        return _buildCreatedStudentsListSection();
      case 2:
        return _buildEnterExamMarksSection();
      case 3:
        return _buildAssignIndirectMarksSection();
      case 4:
        return _buildAssignedIndirectMarksListSection();
      case 5:
        return _buildCoPoDefinitionSection();
      case 6:
        return _buildCoPoAttainmentOverviewSection();
      default:
        return const Center(child: Text("Select an option from the sidebar."));
    }
  }

  // --- Main Content Sections (displayed based on sidebar selection) ---
  /// Section for creating new students.
  Widget _buildCreateStudentSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminCard(
            title: "Create Student",
            content: Column(
              children: [
                _buildTextField(
                  controller: _studentNameController,
                  labelText: "Student Name",
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _studentEmailController,
                  labelText: "Student Email",
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _studentPasswordController,
                  labelText: "Student Password",
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 10), // Added SizedBox
                _buildDropdown<String>( // New dropdown for section selection
                  value: _selectedSectionIdForStudentCreation,
                  hint: _allSections.isEmpty ? "No Sections Available (HOD needs to create)" : "Select Section for Student",
                  items: _allSections.map<DropdownMenuItem<String>>((section) {
                    return DropdownMenuItem<String>(
                      value: section['id'] as String,
                      child: Text(section['name'] as String),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSectionIdForStudentCreation = val;
                    });
                  },
                ),
                const SizedBox(height: 20),
                _buildElevatedButton(
                  onPressed: _createStudent,
                  text: "Create Student",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section for entering exam marks.
  Widget _buildEnterExamMarksSection() {
    // Filter assigned subjects to get unique subject IDs for the first dropdown
    final uniqueAssignedSubjects = _assignedSubjectsAndSections
        .map((e) => {'id': e['subjectId'] as String, 'name': e['subjectName'] as String})
        .toSet()
        .toList();

    // Filter sections based on selected subject
    final sectionsForSelectedSubject = _assignedSubjectsAndSections
        .where((e) => e['subjectId'] == _selectedAssignedSubjectId)
        .map((e) => {'id': e['sectionId'] as String, 'name': e['sectionName'] as String})
        .toSet()
        .toList();

    // Filter exams based on selected subject and applicable sections
    final examsForSelectedSubjectAndSection = _allExams
        .where((exam) {
      bool subjectMatches = exam['subjectId'] == _selectedAssignedSubjectId;
      bool sectionApplies = false;

      // If exam has no specific applicable sections, it applies to all in the department
      if (exam['applicableSectionIds'] == null || (exam['applicableSectionIds'] as List).isEmpty) {
        // If no sections are explicitly listed in the exam, it applies to all sections
        // that the teacher is assigned to for this subject.
        sectionApplies = _selectedAssignedSectionId != null &&
            sectionsForSelectedSubject.any((s) => s['id'] == _selectedAssignedSectionId);
      } else {
        // If specific applicableSectionIds are listed, check if the selected section is one of them
        sectionApplies = _selectedAssignedSectionId != null &&
            (exam['applicableSectionIds'] as List).contains(_selectedAssignedSectionId);
      }
      return subjectMatches && sectionApplies;
    }).toList();


    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminCard(
            title: "Enter Exam Marks (CO-PO Enabled)",
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdown<String>(
                  value: _selectedAssignedSubjectId,
                  hint: uniqueAssignedSubjects.isEmpty ? "No Subjects Assigned to You by HOD" : "Select Subject",
                  items: uniqueAssignedSubjects.map<DropdownMenuItem<String>>((subject) {
                    return DropdownMenuItem<String>(
                      value: subject['id'],
                      child: Text(subject['name']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedAssignedSubjectId = val;
                      // Reset section and exam when subject changes
                      _selectedAssignedSectionId = null;
                      _selectedExamId = null;
                      _students = []; // Clear students
                      _markControllers.clear(); // Clear controllers
                      _selectedExamDetails = null;
                      _selectedSubjectDetails = null;
                      _studentPoAttainments.clear();
                    });
                    print('Selected Subject: $val');
                    print('Sections for selected subject after change (from _assignedSubjectsAndSections): ${sectionsForSelectedSubject.length} items');
                  },
                ),
                const SizedBox(height: 10),
                _buildDropdown<String>(
                  key: ValueKey(_selectedAssignedSubjectId), // Key to force rebuild when subject changes
                  value: _selectedAssignedSectionId,
                  hint: _selectedAssignedSubjectId == null
                      ? "Select a Subject first"
                      : sectionsForSelectedSubject.isEmpty
                      ? "No Sections Assigned to this Subject for you (by HOD)"
                      : "Select Section",
                  items: sectionsForSelectedSubject.map<DropdownMenuItem<String>>((section) {
                    return DropdownMenuItem<String>(
                      value: section['id'],
                      child: Text(section['name']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedAssignedSectionId = val;
                      // Reset exam when section changes
                      _selectedExamId = null;
                      _students = []; // Clear students
                      _markControllers.clear(); // Clear controllers
                      _selectedExamDetails = null;
                      _selectedSubjectDetails = null;
                      _studentPoAttainments.clear();
                    });
                    print('Selected Section: $val');
                  },
                ),
                const SizedBox(height: 10),
                _buildDropdown<String>(
                  key: ValueKey('$_selectedAssignedSubjectId-$_selectedAssignedSectionId'), // Key for exam dropdown
                  value: _selectedExamId,
                  hint: _selectedAssignedSectionId == null
                      ? "Select a Section first"
                      : examsForSelectedSubjectAndSection.isEmpty
                      ? "No Exams available for this Subject and Section (assigned to you by HOD)"
                      : "Select Exam",
                  items: examsForSelectedSubjectAndSection.map<DropdownMenuItem<String>>((exam) {
                    return DropdownMenuItem<String>(
                      value: exam['id'] as String,
                      child: Text("${exam['name']} (Total: ${exam['totalMarks'] ?? 'N/A'})"),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    setState(() {
                      _selectedExamId = val;
                    });
                    await _loadStudentsAndMarks(); // Load students and marks after exam selection
                  },
                ),
                const SizedBox(height: 20),

                if (_isLoadingStudentMarks)
                  const Center(child: CircularProgressIndicator())
                else if (_selectedExamId != null && _students.isNotEmpty && _selectedExamDetails != null && _selectedSubjectDetails != null) ...[
                  _buildTableCard(
                    title: "Mark Entry for Exam: ${_selectedExamDetails!['name']}",
                    content: _buildMarkEntryTable(),
                  ),
                  const SizedBox(height: 20),
                  _buildElevatedButton(
                    onPressed: _saveStudentMarks,
                    text: "Save All Marks",
                  ),
                ] else if (_selectedExamId != null && _students.isEmpty) ...[
                  const Center(child: Text("No students found for this section or exam. Make sure students are linked to sections and exams are configured with COs/POs by HOD.", style: TextStyle(color: Colors.grey))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section for assigning indirect marks.
  Widget _buildAssignIndirectMarksSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdminCard(
            title: "Assign Indirect Marks",
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdown<String>(
                  value: _selectedIndirectMarkTypeId,
                  hint: _indirectMarkTypes.isEmpty ? "No Indirect Mark Types" : "Choose Indirect Mark Type",
                  items: _indirectMarkTypes.map<DropdownMenuItem<String>>((type) {
                    return DropdownMenuItem<String>(
                      value: type['id'] as String,
                      child: Text("${type['name']} (Weight: ${type['weight'] ?? 'N/A'})"),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedIndirectMarkTypeId = val;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _buildDropdown<String>(
                  value: _selectedStudentIdForIndirectMarks,
                  hint: _createdStudents.isEmpty ? "No Students Created" : "Choose Student",
                  items: _createdStudents.map<DropdownMenuItem<String>>((student) {
                    return DropdownMenuItem<String>(
                      value: student['id'] as String,
                      child: Text("${student['name']} (${student['email']})"),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedStudentIdForIndirectMarks = val;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _indirectMarksGivenController,
                  labelText: "Marks Obtained",
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                _buildElevatedButton(
                  onPressed: _assignIndirectMarks,
                  text: "Assign Indirect Marks",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section for displaying assigned indirect marks.
  Widget _buildAssignedIndirectMarksListSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _listDisplayCard(
            title: "Assigned Indirect Marks List",
            content: _assignedIndirectMarks.isEmpty
                ? const Center(child: Text("No indirect marks assigned yet."))
                : ListView.builder(
              itemCount: _assignedIndirectMarks.length,
              itemBuilder: (context, index) {
                final mark = _assignedIndirectMarks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Card(
                    color: cardBackgroundColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: cardBorderColor, width: 1),
                    ),
                    child: ListTile(
                      title: Text(
                        "${mark['studentName']} - ${mark['markTypeName']}",
                        style: TextStyle(color: textBlackColor, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        "Marks: ${mark['marks']} / ${mark['weight']}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              _showEditIndirectMarkDialog(mark);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              _deleteIndirectMark(mark['id'] as String);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Section for displaying created students.
  Widget _buildCreatedStudentsListSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _listDisplayCard(
            title: "Created Students List",
            content: _createdStudents.isEmpty
                ? const Center(child: Text("No students created yet."))
                : ListView.builder(
              itemCount: _createdStudents.length,
              itemBuilder: (context, index) {
                final student = _createdStudents[index];
                final sectionName = _allSections.firstWhere(
                      (sec) => sec['id'] == student['sectionId'],
                  orElse: () => {'name': 'Unknown Section'},
                )['name'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Card(
                    color: cardBackgroundColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: cardBorderColor, width: 1),
                    ),
                    child: ListTile(
                      title: Text(
                        student['name'] as String,
                        style: TextStyle(color: textBlackColor, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        "${student['email']} (Section: $sectionName)",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              _showEditStudentDialog(student);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              _deleteStudent(student['id'] as String);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
