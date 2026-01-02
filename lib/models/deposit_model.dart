// lib/models/deposit_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Deposit {
  final String id;
  final String memberId;
  final double amount;
  final DateTime timestamp;

  Deposit({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.timestamp,
  });

  factory Deposit.fromMap(Map<String, dynamic> map) {
    return Deposit(
      id: map['id'] ?? '',
      memberId: map['member_id'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'member_id': memberId,
      'amount': amount,
      'timestamp': timestamp,
    };
  }
}