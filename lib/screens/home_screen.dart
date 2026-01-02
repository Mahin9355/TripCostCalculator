import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'tour_details_screen.dart';
import 'package:intl/intl.dart';
import 'profile_screen.dart'; // Import the new profile screen

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // 0 = Home, 1 = Create (Fake), 2 = Profile
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // --- UI: BOTTOM NAVIGATION BAR ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? "My Tours" : "My Profile"),
        centerTitle: true,
        elevation: 0,
      ),

      // SWITCH BODY BASED ON INDEX
      body: _selectedIndex == 0
          ? _buildTourList() // Tab 0: List
          : ProfileScreen(), // Tab 2: Profile (Tab 1 is skipped)

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1) {
            // IF MIDDLE BUTTON CLICKED -> OPEN DIALOG, DON'T SWITCH TABS
            _showCreateTourDialog(context);
          } else {
            // OTHERWISE SWITCH TABS
            setState(() => _selectedIndex = index);
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            // SPECIAL MIDDLE BUTTON STYLE
            icon: Container(
              padding: EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: Colors.teal,
                  shape: BoxShape.rectangle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
              ),
              child: Icon(Icons.add, color: Colors.white),
            ),
            label: "New Tour",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "My Profile",
          ),
        ],
      ),
    );
  }

  // --- TAB 0: TOUR LIST VIEW ---
  // --- TAB 0: TOUR LIST VIEW ---
  Widget _buildTourList() {
    final user = FirebaseAuth.instance.currentUser;
    // Safety check
    if (user == null) return Center(child: Text("Please login first"));

    return StreamBuilder<QuerySnapshot>(
      // SIMPLIFIED QUERY: Just check if my ID is in the list
      stream: FirebaseFirestore.instance
          .collection('tours')
          .where('access_ids', arrayContains: user.uid)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // 1. ERROR HANDLING
        if (snapshot.hasError) {
          // If this shows "Requires Index", click the link in your debug console!
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        // 2. LOADING STATE
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        // 3. EMPTY STATE
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.travel_explore, size: 60, color: Colors.grey),
                SizedBox(height: 10),
                Text("No tours found.", style: TextStyle(color: Colors.grey)),
                Text("Click + to create one.", style: TextStyle(color: Colors.grey)),
                //SizedBox(height: 20),
                // Debug Helper: Show ID so you can compare with Firestore
                //Text("Debug ID: ${user.uid}", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          );
        }

        // 4. LIST DATA
        return ListView.builder(
          padding: EdgeInsets.all(10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>; // Safe casting

            return Card(
              elevation: 3,
              margin: EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: Image.asset(
                    'assets/location.png',
                    width: 38,
                    height: 38,
                    color: Colors.teal.shade900,
                  ),
                ),
                title: Text(data['tour_name'] ?? "Unnamed"),
                subtitle: Text(
                  data['created_at'] == null
                      ? 'Unknown date'
                      : DateFormat('d MMMM yyyy')
                      .format((data['created_at'] as Timestamp).toDate()),
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TourDetailsScreen(tourId: doc.id, tourName: data['tour_name'] ?? "Tour"),
                  ));
                },
                onLongPress: () => _showDeleteDialog(doc.id),
              ),
            );
          },
        );
      },
    );
  }
  // --- HELPER: CREATE TOUR DIALOG (Same logic as before) ---
  void _showCreateTourDialog(BuildContext context) {
    final _tourNameController = TextEditingController();
    final _managerNameController = TextEditingController();

    // Auto-fill manager name if possible
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null) {
      _managerNameController.text = user.displayName!;
    }

    List<TextEditingController> _memberControllers = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Create New Tour"),
              content: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _tourNameController,
                        decoration: InputDecoration(labelText: "Tour Name"),
                      ),
                      TextField(
                        controller: _managerNameController,
                        decoration: InputDecoration(
                          labelText: "Manager Name (You)",
                          helperText: "You will be added as a member automatically.",
                          prefixIcon: Icon(Icons.star, color: Colors.orange),
                        ),
                      ),
                      Divider(),
                      Text("Other Members"),
                      ..._memberControllers.asMap().entries.map((entry) {
                        return Row(
                          children: [
                            Expanded(child: TextField(controller: entry.value, decoration: InputDecoration(labelText: "Member Name"))),
                            IconButton(
                              icon: Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => setState(() => _memberControllers.removeAt(entry.key)),
                            )
                          ],
                        );
                      }).toList(),
                      TextButton.icon(
                        icon: Icon(Icons.add),
                        label: Text("Add Member"),
                        onPressed: () => setState(() => _memberControllers.add(TextEditingController())),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context)),
                ElevatedButton(
                  child: Text("Create Tour"),
                  onPressed: () async {
                    if (_tourNameController.text.isEmpty || _managerNameController.text.isEmpty) return;

                    List<String> otherMembers = [];
                    for (var c in _memberControllers) {
                      if (c.text.isNotEmpty) otherMembers.add(c.text.trim());
                    }

                    // Create tour AND link the manager immediately to the current user
                    await DatabaseService().createTour(
                        _tourNameController.text.trim(),
                        _managerNameController.text.trim(),
                        otherMembers
                    );

                    // Note: Ideally, you should also update the manager's member doc with currentUserId here
                    // to save a step, but for now, the UI flow works fine.

                    Navigator.pop(context);
                  },
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(String tourId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Delete Tour?"),
        content: Text("This cannot be undone."),
        actions: [
          TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () {
              DatabaseService().deleteTour(tourId);
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }
}