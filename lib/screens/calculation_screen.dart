import 'package:flutter/material.dart';
import '../services/database_service.dart';

class CalculationScreen extends StatelessWidget {
  final String tourId;

  CalculationScreen({required this.tourId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Final Calculation")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: DatabaseService().calculateTour(tourId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          var data = snapshot.data!;
          var fundStats = data['fund_stats'];
          List<dynamic> members = data['member_stats'];

          return Column(
            children: [
              // 1. MANAGER'S DASHBOARD (New Feature)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.teal.shade900,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))]
                ),
                child: Column(
                  children: [
                    Text("MANAGER'S CASH BOX", style: TextStyle(color: Colors.white70, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                    Divider(color: Colors.white24),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem("Total Collected", fundStats['collected'], Colors.greenAccent),
                        _buildStatItem("Fund Spent", fundStats['spent'], Colors.orangeAccent),
                        _buildStatItem("Remaining Cash", fundStats['remaining'], Colors.white, isBold: true),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                child: Align(alignment: Alignment.centerLeft, child: Text("Individual Breakdown:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              ),

              // 2. INDIVIDUAL MEMBER LIST
              Expanded(
                child: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    var m = members[index];
                    double balance = m['balance'];
                    bool isGet = balance >= 0;

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  SizedBox(height: 4),
                                  Text("Given: ${m['given'].toStringAsFixed(0)} | Spent: ${m['spent'].toStringAsFixed(0)}", style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(isGet ? "Will Get" : "Will Give", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    "${balance.abs().toStringAsFixed(0)} ৳",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: isGet ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildStatItem(String label, double amount, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Text(amount.toStringAsFixed(0), style: TextStyle(color: color, fontSize: isBold ? 22 : 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}