import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for Auth
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Controllers for ER Diagram Fields
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _districtController = TextEditingController();

  bool _isLoading = false;

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // 1. Create Auth User
        UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Save Extra Data to Firestore (Matches ER Diagram)
        if (cred.user != null) {
          await DatabaseService().createUserData(
            cred.user!,
            _nameController.text.trim(),
            _mobileController.text.trim(),
            _districtController.text.trim(),
          );
        }

        // 3. Navigate to Home
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen()));
        }
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Registration Failed")));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add, size: 80, color: Colors.teal),
                SizedBox(height: 10),
                Text("Create Account", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text("Join to manage your tour expenses", style: TextStyle(color: Colors.grey)),
                SizedBox(height: 30),

                // SECTION 1: PERSONAL INFO (ER Diagram Fields)
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration("Full Name", Icons.person),
                  validator: (val) => val!.isEmpty ? "Name is required" : null,
                ),
                SizedBox(height: 15),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration("Mobile Number", Icons.phone),
                  validator: (val) => val!.isEmpty ? "Mobile is required" : null,
                ),
                SizedBox(height: 15),
                TextFormField(
                  controller: _districtController,
                  decoration: _inputDecoration("Home District", Icons.location_city),
                  validator: (val) => val!.isEmpty ? "District is required" : null,
                ),
                SizedBox(height: 15),

                // SECTION 2: AUTH INFO
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration("Email", Icons.email),
                  validator: (val) => !val!.contains('@') ? "Invalid Email" : null,
                ),
                SizedBox(height: 15),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _inputDecoration("Password", Icons.lock),
                  validator: (val) => val!.length < 6 ? "Min 6 chars" : null,
                ),

                SizedBox(height: 30),

                _isLoading
                    ? CircularProgressIndicator()
                    : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16)
                    ),
                    onPressed: _register,
                    child: Text("REGISTER"),
                  ),
                ),

                SizedBox(height: 20),
                TextButton(
                  child: Text("Already have an account? Login"),
                  onPressed: () => Navigator.pop(context), // Go back to Login
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.teal),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }
}