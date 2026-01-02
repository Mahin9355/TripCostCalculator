import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Add intl: ^0.18.0 to pubspec.yaml if needed
import '../services/database_service.dart';

class TransactionHistoryScreen extends StatelessWidget {
  final String tourId;
  final String currentUserId;

  TransactionHistoryScreen({required this.tourId, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Transaction History")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tours').doc(tourId).collection('deposits').snapshots(),
        builder: (context, depositSnap) {

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tours').doc(tourId).collection('expenses').snapshots(),
            builder: (context, expenseSnap) {

              if (!depositSnap.hasData || !expenseSnap.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              // 1. MERGE LISTS
              List<Map<String, dynamic>> history = [];

              // Add Deposits (Green)
              for (var doc in depositSnap.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                history.add({
                  'id': doc.id,
                  'type': 'deposit',
                  'title': "Deposit by Member", // You can fetch name if needed
                  'amount': data['amount'],
                  'date': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  'data': data, // Keep raw data for editing
                });
              }

              // Add Expenses (Red)
              for (var doc in expenseSnap.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                history.add({
                  'id': doc.id,
                  'type': 'expense',
                  'title': data['description'],
                  'amount': data['total_amount'],
                  'date': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  'data': data,
                });
              }

              // 2. SORT BY DATE (Newest First)
              history.sort((a, b) => b['date'].compareTo(a['date']));

              if (history.isEmpty) {
                return Center(child: Text("No transactions yet."));
              }

              // 3. BUILD LIST
              return ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, index) {
                  var item = history[index];
                  bool isDeposit = item['type'] == 'deposit';

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDeposit ? Colors.green.shade100 : Colors.red.shade100,
                        child: Icon(
                          isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isDeposit ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text(item['title'] ?? "Unknown", style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(DateFormat('MMM d, h:mm a').format(item['date'])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${isDeposit ? '+' : '-'}৳${item['amount']}",
                            style: TextStyle(
                                color: isDeposit ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteTransaction(context, item['id'], item['type']);
                              } else if (value == 'edit') {
                                if (isDeposit) {
                                  _editDeposit(context, item['id'], item['data']);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("For complex expenses, please delete and re-add.")));
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'edit', child: Text("Edit")),
                              PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- ACTIONS ---

  void _deleteTransaction(BuildContext context, String docId, String type) async {
    bool confirm = await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Delete Transaction?"),
          content: Text("This will recalculate all balances. This cannot be undone."),
          actions: [
            TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context, false)),
            TextButton(child: Text("Delete", style: TextStyle(color: Colors.red)), onPressed: () => Navigator.pop(context, true)),
          ],
        )
    ) ?? false;

    if (confirm) {
      String collection = type == 'deposit' ? 'deposits' : 'expenses';
      await FirebaseFirestore.instance
          .collection('tours')
          .doc(tourId)
          .collection(collection)
          .doc(docId)
          .delete();
    }
  }

  void _editDeposit(BuildContext context, String docId, Map<String, dynamic> data) {
    TextEditingController amountCtrl = TextEditingController(text: data['amount'].toString());

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Edit Deposit"),
          content: TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: "Amount", prefixText: "৳"),
          ),
          actions: [
            TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context)),
            ElevatedButton(
              child: Text("Save"),
              onPressed: () async {
                double? newAmount = double.tryParse(amountCtrl.text);
                if (newAmount == null) return;

                await FirebaseFirestore.instance
                    .collection('tours')
                    .doc(tourId)
                    .collection('deposits')
                    .doc(docId)
                    .update({'amount': newAmount});

                Navigator.pop(context);
              },
            )
          ],
        )
    );
  }
}