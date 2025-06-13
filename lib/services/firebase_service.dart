import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Future<void> updateApproval(String uid, bool status) {
    return firestore.collection('users').doc(uid).update({'isApproved': status});
  }

  static Stream<QuerySnapshot> getAllUsersByRole(String role) {
    return firestore.collection('users').where('role', isEqualTo: role).snapshots();
  }
}
