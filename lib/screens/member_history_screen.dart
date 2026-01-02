import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Now we will actually use this!

class MemberHistoryScreen extends StatelessWidget {
  final String tourId;
  final String memberId;
  final String memberName;

  MemberHistoryScreen({
    required this.tourId,
    required this.memberId,
    required this.memberName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$memberName's History")),
      body: FutureBuilder(
        future: _fetchMemberHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
            return Center(child: Text("No records found for $memberName"));
          }

          // Combine and sort the list
          List<Map<String, dynamic>> history = snapshot.data as List<Map<String, dynamic>>;

          // Calculate Total
          double totalGiven = history.fold(0, (sum, item) => sum + item['amount']);

          return Column(
            children: [
              // Summary Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                color: Colors.teal.shade50,
                child: Column(
                  children: [
                    Text("Total Given / Paid", style: TextStyle(color: Colors.teal, fontSize: 16)),
                    Text(
                        "${totalGiven.toStringAsFixed(0)} ৳",
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal)
                    ),
                  ],
                ),
              ),

              // Timeline List
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.all(12),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => Divider(),
                  itemBuilder: (context, index) {
                    var item = history[index];
                    bool isExpense = item['type'] == 'expense';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isExpense ? Colors.orange.shade100 : Colors.green.shade100,
                        child: Icon(
                          isExpense ? Icons.shopping_bag : Icons.savings,
                          color: isExpense ? Colors.orange : Colors.green,
                        )
                      ),
                      title: Text(
                        isExpense ? item['description'] : "Deposit to Manager",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      // FIX FOR LINE 69: explicitly tell Dart this is a DateTime
                      subtitle: Text(_formatDate(item['date'] as DateTime)),
                      trailing: Text(
                        "${item['amount']} ৳",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchMemberHistory() async {
    List<Map<String, dynamic>> history = [];

    // 1. Fetch Deposits
    var depositSnap = await FirebaseFirestore.instance
        .collection('tours')
        .doc(tourId)
        .collection('deposits')
        .where('member_id', isEqualTo: memberId)
        .get();

    for (var doc in depositSnap.docs) {
      history.add({
        'type': 'deposit',
        'amount': doc['amount'],
        'date': (doc['timestamp'] as Timestamp).toDate(),
        'description': 'Deposit',
      });
    }

    // 2. Fetch Expenses
    var expenseSnap = await FirebaseFirestore.instance
        .collection('tours')
        .doc(tourId)
        .collection('expenses')
        .get();

    for (var doc in expenseSnap.docs) {
      Map<String, dynamic> payers = doc['payers'];

      if (payers.containsKey(memberId)) {
        history.add({
          'type': 'expense',
          'amount': payers[memberId],
          'date': (doc['timestamp'] as Timestamp).toDate(),
          'description': doc['description'],
        });
      }
    }

    // 3. Sort by Date
    history.sort((a, b) => b['date'].compareTo(a['date']));

    return history;
  }

  // FIX: Using 'intl' package correctly
  String _formatDate(DateTime date) {
    // This uses the intl package to format like "12/05/2026 at 09:30 PM"
    return DateFormat('dd/MM/yyyy at hh:mm a').format(date);
  }
}