import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MemberHistoryScreen extends StatelessWidget {
  final String tourId;
  final String memberId;
  final String memberName;

  MemberHistoryScreen({
    required this.tourId,
    required this.memberId,
    required this.memberName
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$memberName's History")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tours')
            .doc(tourId)
            .collection('deposits')
            .where('member_id', isEqualTo: memberId)
        // --- FIX IS HERE ---
        // DO NOT use .orderBy('timestamp') here.
        // It breaks offline because offline items have no timestamp yet.
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(child: Text("No deposits yet."));
          }

          // --- SORT MANUALLY HERE ---
          // We convert the docs to a list so we can sort them in the app
          List<QueryDocumentSnapshot> sortedDocs = List.from(docs);

          sortedDocs.sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>;
            var dataB = b.data() as Map<String, dynamic>;

            // Handle offline (null) timestamps by treating them as "Now"
            // This puts the offline deposit at the very top!
            DateTime dateA = (dataA['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            DateTime dateB = (dataB['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

            return dateB.compareTo(dateA); // Newest first
          });

          return ListView.builder(
            itemCount: sortedDocs.length,
            itemBuilder: (context, index) {
              var doc = sortedDocs[index];
              var data = doc.data() as Map<String, dynamic>;

              // Handle date display safely
              DateTime date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              String dateText = (data['timestamp'] == null)
                  ? "Saving..." // Show this while offline
                  : DateFormat('MMM d, h:mm a').format(date);

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.arrow_downward, color: Colors.green),
                  ),
                  title: Text("Deposit", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(dateText),
                  trailing: Text(
                    "+৳${data['amount']}",
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}