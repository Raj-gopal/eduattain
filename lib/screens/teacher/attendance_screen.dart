import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String selectedStudent = '';
  String selectedSubject = '';
  bool isPresent = true;
  List<String> selectedCOs = [];
  List<String> selectedPOs = [];

  List<String> coList = ['CO1', 'CO2', 'CO3'];
  List<String> poList = ['PO1', 'PO2', 'PO3'];

  Future<void> markAttendance() async {
    await FirebaseFirestore.instance.collection('attendance').add({
      'studentId': selectedStudent,
      'subjectId': selectedSubject,
      'coMapped': selectedCOs,
      'poMapped': selectedPOs,
      'present': isPresent,
      'date': DateTime.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Attendance marked'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mark Attendance')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // TODO: Replace with real dropdowns populated from Firebase
            TextField(
              onChanged: (val) => selectedStudent = val,
              decoration: const InputDecoration(labelText: 'Student ID'),
            ),
            TextField(
              onChanged: (val) => selectedSubject = val,
              decoration: const InputDecoration(labelText: 'Subject ID'),
            ),
            SwitchListTile(
              value: isPresent,
              onChanged: (val) => setState(() => isPresent = val),
              title: const Text('Present'),
            ),
            const SizedBox(height: 10),
            Text('Map COs'),
            ...coList.map((co) => CheckboxListTile(
              title: Text(co),
              value: selectedCOs.contains(co),
              onChanged: (val) {
                setState(() {
                  val! ? selectedCOs.add(co) : selectedCOs.remove(co);
                });
              },
            )),
            const SizedBox(height: 10),
            Text('Map POs'),
            ...poList.map((po) => CheckboxListTile(
              title: Text(po),
              value: selectedPOs.contains(po),
              onChanged: (val) {
                setState(() {
                  val! ? selectedPOs.add(po) : selectedPOs.remove(po);
                });
              },
            )),
            ElevatedButton(
              onPressed: markAttendance,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
