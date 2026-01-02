// lib/models/tour_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Tour {
  final String id;
  final String tourName;
  final DateTime createdAt;
  final bool isActive;

  Tour({
    required this.id,
    required this.tourName,
    required this.createdAt,
    required this.isActive,
  });

  // Convert Firebase Document to Object
  factory Tour.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tour(
      id: doc.id,
      tourName: data['tour_name'] ?? '',
      // SAFETY CHECK: If created_at is null, use current time instead of crashing
      createdAt: data['created_at'] != null
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: data['is_active'] ?? true,
    );
  }

  // Convert Object to Map (for saving)
  Map<String, dynamic> toMap() {
    return {
      'tour_name': tourName,
      'created_at': createdAt,
      'is_active': isActive,
    };
  }
}