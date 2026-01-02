import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // For clipboard
import 'login_screen.dart'; // <--- MAKE SURE TO IMPORT YOUR LOGIN SCREEN HERE

class ProfileScreen extends StatelessWidget {
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Center(child: Text("Not logged in"));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 20),
          // 1. BIG AVATAR
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.teal.shade100,
            child: Text(
              user!.email != null ? user!.email![0].toUpperCase() : "U",
              style: TextStyle(fontSize: 40, color: Colors.teal.shade900),
            ),
          ),
          SizedBox(height: 20),

          // 2. NAME & EMAIL
          Text(
            user!.displayName ?? "User",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            user!.email ?? "",
            style: TextStyle(color: Colors.grey),
          ),

          SizedBox(height: 40),
          Divider(),
          SizedBox(height: 20),

          // 3. THE IMPORTANT PART: USER ID CARD
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Text("YOUR LINKING ID", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.orange.shade900)),
                SizedBox(height: 10),
                Text(
                  "Give this ID to a Tour Manager to get access to their tour.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                SizedBox(height: 15),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300)
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SelectableText(
                          user!.uid,
                          style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 15),
                ElevatedButton.icon(
                  icon: Icon(Icons.copy),
                  label: Text("Copy ID"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: user!.uid));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ID Copied to clipboard!")));
                  },
                )
              ],
            ),
          ),

          SizedBox(height: 40),

          // 4. NEW LOGOUT BUTTON
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(Icons.logout),
              label: Text("Log Out"),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
                side: BorderSide(color: Colors.red), // Red Border
                foregroundColor: Colors.red, // Red Text & Icon
              ),
              onPressed: () async {
                // 1. Sign out from Firebase
                await FirebaseAuth.instance.signOut();

                // 2. Navigate back to Login Screen & Clear History
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                        (route) => false // This removes all previous routes (Back button won't work)
                );
              },
            ),
          ),

          // Extra bottom padding
          SizedBox(height: 20),
        ],
      ),
    );
  }
}