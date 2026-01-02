import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for User ID
import '../services/database_service.dart';
import '../widgets/member_selector_dialog.dart';
import 'add_expense_screen.dart';
import 'calculation_screen.dart';
import 'member_history_screen.dart';
import 'transaction_history_screen.dart'; // Make sure this file exists from previous step

class TourDetailsScreen extends StatefulWidget {
  final String tourId;
  final String tourName;

  TourDetailsScreen({required this.tourId, required this.tourName});

  @override
  _TourDetailsScreenState createState() => _TourDetailsScreenState();
}

class _TourDetailsScreenState extends State<TourDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tourName),
        // --- NEW: ACTION BUTTON FOR HISTORY ---
        actions: [
          IconButton(
            icon: Icon(Icons.history), // The History Clock Icon
            tooltip: "All Transactions",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => TransactionHistoryScreen(
                    tourId: widget.tourId,
                    currentUserId: FirebaseAuth.instance.currentUser!.uid,
                  )
              )).then((_) {
                // Refresh screen when coming back (in case something was deleted)
                setState(() {});
              });
            },
          ),
        ],
        // --------------------------------------
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "জমা (Deposits)", icon: Icon(Icons.savings)),
            Tab(text: "খরচ (Expenses)", icon: Icon(Icons.receipt_long)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDepositTab(),
          _buildExpenseTab(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        color: Colors.grey.shade100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("ট্যুর শেষ? হিসাব চেক করুন", style: TextStyle(color: Colors.grey[700])),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.calculate, color: Colors.white),
                label: Text("CALCULATE FINAL COST", style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CalculationScreen(tourId: widget.tourId)
                  ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: MEMBER LIST (Click = History, Menu = Access)
  // ==========================================
  Widget _buildDepositTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tours')
                .doc(widget.tourId)
                .collection('members')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

              var members = snapshot.data!.docs;

              return ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  var member = members[index];
                  // Check if this member is already linked to a real user
                  bool isLinked = (member.data() as Map).containsKey('linked_uid');

                  return FutureBuilder<double>(
                    future: _calculateMemberTotal(member.id),
                    builder: (context, calcSnapshot) {
                      String totalText = calcSnapshot.hasData
                          ? "${calcSnapshot.data!.toStringAsFixed(0)} ৳"
                          : "...";

                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: ListTile(
                          // VISUAL: Show Checkmark if linked, otherwise Initials
                          leading: CircleAvatar(
                            backgroundColor: isLinked ? Colors.blue.shade800 : Colors.teal,
                            child: isLinked
                                ? Icon(Icons.check, color: Colors.white, size: 18)
                                : Text(member['name'][0].toUpperCase(), style: TextStyle(color: Colors.white)),
                          ),

                          title: Text(member['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Total Given: $totalText", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),

                          // ACTION 1: CLICK ROW -> VIEW HISTORY
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => MemberHistoryScreen(
                                  tourId: widget.tourId,
                                  memberId: member.id,
                                  memberName: member['name'],
                                )
                            )).then((_) => setState(() {})); // Refresh when coming back
                          },

                          // ACTION 2: 3-DOT MENU -> GRANT ACCESS ONLY
                          trailing: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.grey),
                            onSelected: (value) {
                              if (value == 'access') {
                                _showGrantAccessDialog(context, member.id, member['name']);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'access',
                                child: Row(children: [
                                  Icon(Icons.vpn_key, size: 20, color: isLinked ? Colors.grey : Colors.blue),
                                  SizedBox(width: 8),
                                  Text(isLinked ? "Update User ID" : "Grant App Access")
                                ]),
                              ),
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
        ),

        // Add Deposit Button
        Container(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text("নতুন জমা (+ New Deposit)"),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.all(15), backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () => _showAddDepositDialog(context),
            ),
          ),
        ),
      ],
    );
  }

  // --- GRANT ACCESS DIALOG ---
  void _showGrantAccessDialog(BuildContext context, String memberId, String memberName) {
    TextEditingController _uidController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Give Access to $memberName"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Paste the User ID (UID) of this person:", style: TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(height: 10),
            TextField(
              controller: _uidController,
              decoration: InputDecoration(
                  labelText: "User ID",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_search),
                  hintText: "e.g. 5ty78..."
              ),
            ),
          ],
        ),
        actions: [
          TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context)),
          ElevatedButton(
            child: Text("Grant Access"),
            onPressed: () async {
              if (_uidController.text.isNotEmpty) {
                await DatabaseService().linkMemberToUser(
                    widget.tourId,
                    memberId,
                    _uidController.text.trim()
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$memberName is now linked!")));
              }
            },
          )
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: EXPENSES LIST
  // ==========================================
  Widget _buildExpenseTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tours')
                .doc(widget.tourId)
                .collection('expenses')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

              var docs = snapshot.data!.docs;
              if (docs.isEmpty) return Center(child: Text("No expenses yet."));

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.red.shade100, child: Icon(Icons.shopping_bag, color: Colors.red)),
                    title: Text(data['description']),
                    subtitle: Text("${_formatDate(data['timestamp'])}"),
                    trailing: Text(
                      "-${data['total_amount']} ৳",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text("নতুন খরচ (+ New Expense)"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: EdgeInsets.all(15)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(tourId: widget.tourId)
                )).then((_) => setState(() {})); // Refresh totals on return
              },
            ),
          ),
        ),
      ],
    );
  }

  // Helper: Calculate Total Given (Deposits + Direct Payments) for one member
  Future<double> _calculateMemberTotal(String memberId) async {
    double total = 0;

    // 1. Sum Deposits
    var deposits = await FirebaseFirestore.instance
        .collection('tours')
        .doc(widget.tourId)
        .collection('deposits')
        .where('member_id', isEqualTo: memberId)
        .get();

    for (var doc in deposits.docs) {
      total += (doc['amount'] as num).toDouble();
    }

    // 2. Sum Expenses (Direct Payments)
    var expenses = await FirebaseFirestore.instance
        .collection('tours')
        .doc(widget.tourId)
        .collection('expenses')
        .get();

    for (var doc in expenses.docs) {
      Map<String, dynamic> payers = doc['payers'];
      if (payers.containsKey(memberId)) {
        total += (payers[memberId] as num).toDouble();
      }
    }

    return total;
  }

  void _showAddDepositDialog(BuildContext context) async {
    final selectedMember = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => MemberSelectorDialog(tourId: widget.tourId),
    );

    if (selectedMember == null) return;

    final amountController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Deposit for ${selectedMember['name']}"),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(labelText: "Amount", suffixText: "BDT"),
        ),
        actions: [
          TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context)),
          ElevatedButton(
            child: Text("Save"),
            onPressed: () async {
              if (amountController.text.isNotEmpty) {
                await DatabaseService().addDeposit(
                  widget.tourId,
                  selectedMember['id'],
                  double.parse(amountController.text),
                );
                Navigator.pop(context);
              }
            },
          )
        ],
      ),
    );
    // Force rebuild to update the totals in the list
    setState(() {});
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "Just now";
    DateTime date = (timestamp as Timestamp).toDate();
    return "${date.day}/${date.month} ${date.hour}:${date.minute}";
  }
}