import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class TransactionHistoryScreen extends StatelessWidget {
  final String tourId;
  final String currentUserId;

  TransactionHistoryScreen({required this.tourId, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Transaction History")),

      // 1. FIRST STREAM: GET ALL MEMBERS
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tours').doc(tourId).collection('members').snapshots(),
        builder: (context, memberSnap) {

          // 2. SECOND STREAM: GET DEPOSITS
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tours').doc(tourId).collection('deposits').snapshots(),
            builder: (context, depositSnap) {

              // 3. THIRD STREAM: GET EXPENSES
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tours').doc(tourId).collection('expenses').snapshots(),
                builder: (context, expenseSnap) {

                  // Check if everything is loaded
                  if (!memberSnap.hasData || !depositSnap.hasData || !expenseSnap.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  // --- STEP A: CREATE MEMBER LOOKUP MAP ---
                  // This turns the list of members into a quick dictionary:
                  // { "abc1234": "Rahim", "xyz5678": "Karim" }
                  Map<String, String> memberMap = {};
                  for (var doc in memberSnap.data!.docs) {
                    memberMap[doc.id] = doc['name'];
                  }

                  // --- STEP B: MERGE LISTS ---
                  List<Map<String, dynamic>> history = [];

                  // Add Deposits (Green)
                  for (var doc in depositSnap.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;

                    // FETCH NAME USING THE MAP
                    String memberId = data['member_id'] ?? "";
                    String memberName = memberMap[memberId] ?? "Unknown Member";

                    history.add({
                      'id': doc.id,
                      'type': 'deposit',
                      'title': "Deposit from $memberName", // <--- UPDATED HERE
                      'amount': data['amount'],
                      'date': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      'data': data,
                    });
                  }

                  // 2. Process Expenses (SMART "Mixed Payment" Logic)
                  for (var doc in expenseSnap.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    double totalCost = (data['total_amount'] as num).toDouble();

                    // -- NEW LOGIC START --
                    Map<String, dynamic> payers = data['payers'] ?? {};
                    double membersPaidTotal = 0;
                    List<String> paymentParts = [];

                    // A. Add Members to the list
                    payers.forEach((uid, amount) {
                      double paidAmt = (amount as num).toDouble();
                      membersPaidTotal += paidAmt;

                      String name = memberMap[uid] ?? "Fund";
                      // format: "Rahim (500)"
                      paymentParts.add("$name (${paidAmt.toStringAsFixed(0)})");
                    });

                    // B. Calculate Fund Contribution
                    double fundPaid = totalCost - membersPaidTotal;

                    // If Fund paid anything (even 1 taka), add it to the start of the list
                    if (fundPaid > 0) {
                      paymentParts.insert(0, "Fund (${fundPaid.toStringAsFixed(0)})");
                    }

                    String paymentInfo = paymentParts.join(', ');
                    // Example Output: "Fund (2000), Rahim (500), Sajib (1000)"
                    // -- NEW LOGIC END --

                    history.add({
                      'id': doc.id,
                      'type': 'expense',
                      'title': data['description'],
                      'subtitle': paymentInfo, // <--- Using the detailed string
                      'amount': totalCost,
                      'date': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      'data': data,
                    });
                  }

                  // --- STEP C: SORT BY DATE (Newest First) ---
                  history.sort((a, b) => b['date'].compareTo(a['date']));

                  if (history.isEmpty) {
                    return Center(child: Text("No transactions yet."));
                  }

                  // --- STEP D: BUILD LIST ---
                  return ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      var item = history[index];
                      bool isDeposit = item['type'] == 'deposit';

                      // Inside ListView.builder...

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

                          // --- THIS IS THE FIX ---
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. The Date
                              Text(DateFormat('MMM d, h:mm a').format(item['date'])),

                              // 2. The Smart Payment Info (Fund: 2000, Rahim: 500)
                              // We only show this if it exists (it might be null for old data)
                              if (item['subtitle'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    item['subtitle'],
                                    style: TextStyle(
                                        color: isDeposit ? Colors.green : Colors.grey[800],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // -----------------------

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
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("For expenses, please delete and re-add.")));
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
          );
        },
      ),
    );
  }

  // --- ACTIONS (Unchanged) ---

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