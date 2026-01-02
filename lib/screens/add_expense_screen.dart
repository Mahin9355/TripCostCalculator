import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final String tourId;
  AddExpenseScreen({required this.tourId});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  List<QueryDocumentSnapshot> _members = [];

  // Stores who paid how much. Key 'fund' = Manager.
  Map<String, double> _payerAmounts = {};

  List<String> _selectedBeneficiaries = [];
  bool _isLoading = true;
  bool _isFullyPaidByFund = true; // DEFAULT: ON

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  void _fetchMembers() async {
    var snapshot = await FirebaseFirestore.instance.collection('tours').doc(widget.tourId).collection('members').get();
    setState(() {
      _members = snapshot.docs;
      // Default: Everyone consumes
      _selectedBeneficiaries = _members.map((e) => e.id).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Expense")),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Basic Info
            TextField(controller: _descController, decoration: InputDecoration(labelText: "Description (e.g. Lunch)")),
            TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "Total Bill Amount", suffixText: "BDT")
            ),
            SizedBox(height: 20),

            // 2. WHO PAID SECTION (The Logic You Wanted)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Payment Source", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),

                  // THE MAIN SWITCH
                  SwitchListTile(
                    title: Text("Paid Fully by Manager (Fund)"),
                    subtitle: Text("The total amount is taken from collected deposits."),
                    value: _isFullyPaidByFund,
                    activeColor: Colors.teal,
                    onChanged: (val) {
                      setState(() {
                        _isFullyPaidByFund = val;
                        _payerAmounts.clear(); // Reset manual entries
                      });
                    },
                  ),

                  // IF SWITCH IS OFF -> SHOW DETAILED LIST
                  if (!_isFullyPaidByFund) ...[
                    Divider(),
                    Text("Select who paid (Split allowed):", style: TextStyle(fontWeight: FontWeight.bold)),

                    // Option A: Manager's Fund (Partial)
                    _buildPayerRow(
                        id: 'fund',
                        name: "Manager's Fund (Partial)",
                        isSpecial: true
                    ),

                    // Option B: All Members
                    ..._members.map((member) {
                      return _buildPayerRow(
                          id: member.id,
                          name: member['name']
                      );
                    }).toList(),

                    // Split Calculation Helper
                    Builder(builder: (context) {
                      double paidSum = _payerAmounts.values.fold(0, (sum, val) => sum + val);
                      double billTotal = double.tryParse(_amountController.text) ?? 0;
                      double remaining = billTotal - paidSum;

                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "Remaining to assign: ${remaining.toStringAsFixed(0)} ৳",
                          style: TextStyle(
                              color: remaining == 0 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                      );
                    }),
                  ]
                ],
              ),
            ),

            SizedBox(height: 20),
            Divider(),

            // 3. FOR WHOM?
            Text("For Whom? (Uncheck if they didn't eat)", style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8.0,
              children: _members.map((member) {
                final isSelected = _selectedBeneficiaries.contains(member.id);
                return FilterChip(
                  label: Text(member['name']),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) _selectedBeneficiaries.add(member.id);
                      else _selectedBeneficiaries.remove(member.id);
                    });
                  },
                );
              }).toList(),
            ),

            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: EdgeInsets.all(16)),
                child: Text("SAVE EXPENSE"),
                onPressed: _saveExpense,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPayerRow({required String id, required String name, bool isSpecial = false}) {
    bool isSelected = _payerAmounts.containsKey(id);
    return CheckboxListTile(
      dense: true,
      title: Text(name, style: TextStyle(fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal)),
      secondary: isSpecial
          ? Icon(Icons.savings, color: Colors.orange)
          : CircleAvatar(radius: 12, backgroundColor: Colors.blue.shade100, child: Text(name[0], style: TextStyle(fontSize: 12))),
      value: isSelected,
      subtitle: isSelected ? Text("Pays: ${_payerAmounts[id]} ৳") : null,
      onChanged: (bool? value) {
        if (value == true) {
          _showAmountDialog(id, name);
        } else {
          setState(() => _payerAmounts.remove(id));
        }
      },
    );
  }

  void _showAmountDialog(String id, String name) {
    TextEditingController _splitCtrl = TextEditingController();

    // Auto-fill logic
    double billTotal = double.tryParse(_amountController.text) ?? 0;
    double currentPaid = _payerAmounts.values.fold(0, (sum, val) => sum + val);
    double remaining = billTotal - currentPaid;
    if (remaining > 0) _splitCtrl.text = remaining.toStringAsFixed(0);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Amount for $name?"),
        content: TextField(controller: _splitCtrl, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(child: Text("OK"), onPressed: () {
            if (_splitCtrl.text.isNotEmpty) {
              setState(() => _payerAmounts[id] = double.parse(_splitCtrl.text));
              Navigator.pop(context);
            }
          })
        ],
      ),
    );
  }

  void _saveExpense() {
    if (_descController.text.isEmpty || _amountController.text.isEmpty) return;
    double total = double.parse(_amountController.text);

    Map<String, double> finalPayers = {};

    if (_isFullyPaidByFund) {
      // Logic 1: Default (Manager pays all)
      finalPayers = {'fund': total};
    } else {
      // Logic 2: Manual Split
      double paidSum = _payerAmounts.values.fold(0, (sum, val) => sum + val);
      if ((paidSum - total).abs() > 1.0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Mismatch! Assigned: $paidSum, Total: $total")));
        return;
      }
      finalPayers = _payerAmounts;
    }

    if (_selectedBeneficiaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Select at least one beneficiary")));
      return;
    }

    DatabaseService().addExpense(
        widget.tourId,
        _descController.text,
        total,
        finalPayers,
        _selectedBeneficiaries
    );

    Navigator.pop(context);
  }
}