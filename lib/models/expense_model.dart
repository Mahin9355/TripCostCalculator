import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String description;
  final double totalAmount;
  final Map<String, double> payers; // Who paid: {'member_id_1': 500.0}
  final List<String> beneficiaries; // Who it's for: ['member_id_1', 'member_id_2']
  final DateTime timestamp;

  Expense({
    required this.id,
    required this.description,
    required this.totalAmount,
    required this.payers,
    required this.beneficiaries,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'total_amount': totalAmount,
      'payers': payers,
      'beneficiaries': beneficiaries,
      'timestamp': timestamp,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? '',
      description: map['description'] ?? '',
      totalAmount: (map['total_amount'] ?? 0).toDouble(),
      payers: Map<String, double>.from(map['payers'] ?? {}),
      beneficiaries: List<String>.from(map['beneficiaries'] ?? []),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}