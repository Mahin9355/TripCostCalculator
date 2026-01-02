// lib/widgets/member_selector_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MemberSelectorDialog extends StatelessWidget {
  final String tourId;

  MemberSelectorDialog({required this.tourId});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Select Member"),
      content: Container(
        width: double.maxFinite,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tours')
              .doc(tourId)
              .collection('members')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

            var members = snapshot.data!.docs;

            if (members.isEmpty) return Text("No members found.");

            return ListView.builder(
              shrinkWrap: true,
              itemCount: members.length,
              itemBuilder: (context, index) {
                var member = members[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(member['name'][0])),
                  title: Text(member['name']),
                  onTap: () {
                    // Return the selected member details to the parent screen
                    Navigator.pop(context, {
                      'id': member.id,
                      'name': member['name']
                    });
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}