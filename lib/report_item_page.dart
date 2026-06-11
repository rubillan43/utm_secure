import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportItemPage extends StatefulWidget {
  const ReportItemPage({super.key});

  @override
  State<ReportItemPage> createState() => _ReportItemPageState();
}

class _ReportItemPageState extends State<ReportItemPage> {
  final _descriptionController = TextEditingController();
  String _type = 'Lost';

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _descriptionController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('Reports').add({
      'uid': user.uid,
      'type': _type,
      'description': _descriptionController.text.trim(),
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
    _descriptionController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reported Securely")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Secure Report"), backgroundColor: const Color(0xFF800000), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _type,
              items: ['Lost', 'Found'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _type = val!),
            ),
            TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: "Description")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _submit, child: const Text("Submit Report")),
          ],
        ),
      ),
    );
  }
}