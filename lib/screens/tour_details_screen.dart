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
            icon: Icon(Icons.person_add),
            tooltip: "Add New Member",
            onPressed: () => _showAddMemberDialog(context),
          ),
          SizedBox(width: 6,),
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
          SizedBox(width: 28,)
        ],
        // --------------------------------------
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "জমা (Deposits)", icon: Icon(Icons.deblur)),
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
            Text("ট্যুর শেষ? হিসাব চেক করুন", style: TextStyle(color: Colors.purple[700])),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.only(right: 50,left: 50),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.calculate, color: Colors.white),
                  label: Text("CALCULATE FINAL COST", style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan[900],
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CalculationScreen(tourId: widget.tourId)
                    ));
                  },
                ),
              ),
            ),
            SizedBox(height: 16,)
          ],
        ),
      ),
    );
  }
  // --- SHOW ADD MEMBER DIALOG ---
  void _showAddMemberDialog(BuildContext context) {
    final TextEditingController _nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add New Member"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "This person will be added to the tour immediately. They will be included in FUTURE expenses, but not past ones.",
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: "Member Name",
                //hintText: "e.g. Rahim",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context)
          ),
          ElevatedButton(
            child: Text("Add Member"),
            onPressed: () async {
              String name = _nameController.text.trim();
              if (name.isNotEmpty) {
                // Call Database Service
                await DatabaseService().addMemberToRunningTour(widget.tourId, name);

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$name added to the tour!"))
                );
              }
            },
          )
        ],
      ),
    );
  }
  // ==========================================
  // TAB 1: MEMBER LIST (Click = History, Menu = Access/Status)
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
                .orderBy('joined_at', descending: false) // Keep order consistent
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

              var members = snapshot.data!.docs;

              return ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  var member = members[index];
                  var data = member.data() as Map<String, dynamic>;

                  // Check status
                  bool isLinked = data.containsKey('linked_uid');
                  bool isActive = data['is_active'] ?? true; // Default to true if missing

                  return FutureBuilder<double>(
                    future: _calculateMemberTotal(member.id),
                    builder: (context, calcSnapshot) {
                      String totalText = calcSnapshot.hasData
                          ? "${calcSnapshot.data!.toStringAsFixed(0)} ৳"
                          : "...";

                      return Card(
                        // Grey out the card if they left
                        color: isActive ? Colors.white : Colors.grey.shade200,
                        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: ListTile(
                          // VISUAL: Initials or Checkmark
                          leading: CircleAvatar(
                            backgroundColor: isActive
                                ? (isLinked ? Colors.blue.shade800 : Colors.teal)
                                : Colors.grey, // Grey circle if left
                            child: isLinked
                                ? Icon(Icons.check, color: Colors.white, size: 18)
                                : Text(data['name'][0].toUpperCase(), style: TextStyle(color: Colors.white)),
                          ),

                          title: Row(
                            children: [
                              Text(
                                  data['name'],
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: isActive ? null : TextDecoration.lineThrough, // Cross out name
                                      color: isActive ? Colors.black : Colors.grey
                                  )
                              ),
                              if (!isActive)
                                Text(" (Left)", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))
                            ],
                          ),

                          subtitle: Text("Total Given: $totalText", style: TextStyle(color: isActive ? Colors.teal : Colors.grey)),

                          // ACTION 1: CLICK ROW -> VIEW HISTORY
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => MemberHistoryScreen(
                                  tourId: widget.tourId,
                                  memberId: member.id,
                                  memberName: data['name'],
                                )
                            )).then((_) => setState(() {}));
                          },

                          // ACTION 2: MENU (Access & Status Toggle)
                          trailing: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.grey),
                            onSelected: (value) {
                              if (value == 'access') {
                                _showGrantAccessDialog(context, member.id, data['name']);
                              } else if (value == 'toggle_status') {
                                _toggleMemberStatus(context, member.id, data['name'], isActive);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'access',
                                child: Row(children: [
                                  Icon(Icons.vpn_key, size: 20, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(isLinked ? "Update ID" : "Grant Access")
                                ]),
                              ),
                              // DYNAMIC TOGGLE BUTTON
                              PopupMenuItem(
                                value: 'toggle_status',
                                child: Row(children: [
                                  Icon(
                                      isActive ? Icons.exit_to_app : Icons.undo,
                                      size: 20,
                                      color: isActive ? Colors.orange : Colors.green
                                  ),
                                  SizedBox(width: 8),
                                  Text(isActive ? "Mark as Left" : "Undo (Mark Active)")
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
          padding: EdgeInsets.only(right: 100,left: 100,top: 16,bottom: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text("নতুন জমা (+ New Deposit)"),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.all(15), backgroundColor: Colors.cyan[700], foregroundColor: Colors.white),
              onPressed: () => _showAddDepositDialog(context),
            ),
          ),
        ),
      ],
    );
  }

  // --- TOGGLE MEMBER STATUS (LEFT / UNDO) ---
  void _toggleMemberStatus(BuildContext context, String memberId, String name, bool currentStatus) async {
    // If currently active, we are marking as LEFT.
    // If currently inactive, we are UNDOING (marking as active).
    bool newStatus = !currentStatus;

    String title = newStatus ? "Re-activate $name?" : "Mark $name as Left?";
    String content = newStatus
        ? "$name will be included in future expenses again."
        : "$name will be excluded from default selections in future expenses.";

    bool confirm = await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context, false)),
            TextButton(child: Text("Confirm"), onPressed: () => Navigator.pop(context, true)),
          ],
        )
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance
          .collection('tours')
          .doc(widget.tourId)
          .collection('members')
          .doc(memberId)
          .update({'is_active': newStatus}); // Toggle the boolean

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newStatus ? "$name is back!" : "$name marked as left."),
        duration: Duration(seconds: 2),
      ));
    }
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
          padding: const EdgeInsets.only(left: 100,right: 100,top: 16,bottom: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text("নতুন খরচ (+ New Expense)"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent[200], foregroundColor: Colors.white, padding: EdgeInsets.all(15)),
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
    // 1. First, wait for the user to pick a member
    final selectedMember = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => MemberSelectorDialog(tourId: widget.tourId),
    );

    if (selectedMember == null) return; // User cancelled selection

    final amountController = TextEditingController();

    // 2. Show the amount input dialog
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Deposit for ${selectedMember['name']}"),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: "Amount",
            suffixText: "BDT",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context)
          ),
          ElevatedButton(
            child: Text("Save"),
            onPressed: () { // Removed 'async' here
              String amountText = amountController.text.trim();

              if (amountText.isNotEmpty) {
                double? amount = double.tryParse(amountText);
                if (amount == null) return;

                // --- FIX IS HERE: FIRE AND FORGET ---
                // Do NOT use 'await'. This lets the code continue immediately.
                DatabaseService().addDeposit(
                  widget.tourId,
                  selectedMember['id'],
                  amount,
                ).catchError((e) {
                  // Optional: Log error if it fails completely (rare in offline mode)
                  print("Error adding deposit: $e");
                });

                // Close the dialog INSTANTLY
                Navigator.pop(context);

                // Optional: Show a little confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Deposit added for ${selectedMember['name']}!"),
                      duration: Duration(seconds: 1),
                    )
                );
              }
            },
          )
        ],
      ),
    );

    // 3. Update UI (Streams handle data, but this refreshes any local calculations if needed)
    setState(() {});
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "Just now";
    DateTime date = (timestamp as Timestamp).toDate();
    return "${date.day}/${date.month} ${date.hour}:${date.minute}";
  }
}