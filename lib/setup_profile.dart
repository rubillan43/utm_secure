import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

class SetupProfilePage extends StatefulWidget {
  const SetupProfilePage({super.key});

  @override
  State<SetupProfilePage> createState() => _SetupProfilePageState();
}

class _SetupProfilePageState extends State<SetupProfilePage> {
  final _nameController = TextEditingController();
  final _matrixController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty || _matrixController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields required")));
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      if (user != null) {
        await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
          'name': _nameController.text.trim(),
          'matrixNumber': _matrixController.text.trim().toUpperCase(),
          'email': user.email,
          'role': 'student',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Profile"), backgroundColor: const Color(0xFF800000), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const Text("Register your details for UTM Lost & Found", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            TextField(controller: _matrixController, decoration: const InputDecoration(labelText: "Matrix Number", border: OutlineInputBorder())),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF800000)),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SAVE & CONTINUE", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}