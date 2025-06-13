import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void checkApprovalStatus(BuildContext context, String userId) {
  FirebaseFirestore.instance.collection('users').doc(userId).snapshots().listen((doc) {
    final isApproved = doc.data()?['isApproved'] ?? false;
    if (isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 You have been approved!')),
      );
    }
  });
}
