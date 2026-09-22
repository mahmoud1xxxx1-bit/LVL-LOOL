
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileDialog extends StatefulWidget {
  const ProfileDialog({super.key});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  final TextEditingController _nameController = TextEditingController();
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  String _currentName = '';
  int _gems = 0;
  bool _freeNameUsed = false;
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _currentName = data['displayName'] ?? '';
        _nameController.text = _currentName;
        _gems = data['gems'] ?? 0;
        _freeNameUsed = data['freeNameChangeUsed'] ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.length < 3 || newName.length > 14) {
      setState(() => _errorText = 'الاسم يجب أن يكون بين 3 و 14 حرف');
      return;
    }
    if (newName == _currentName) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final bool freeUsed = snapshot.data()?['freeNameChangeUsed'] ?? false;
        final int currentGems = snapshot.data()?['gems'] ?? 0;

        if (!freeUsed) {
          transaction.update(docRef, {
            'displayName': newName,
            'freeNameChangeUsed': true,
          });
        } else {
          if (currentGems < 50) {
            throw Exception('not_enough_gems');
          }
          transaction.update(docRef, {
            'displayName': newName,
            'gems': currentGems - 50,
          });
        }
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (e.toString().contains('not_enough_gems')) {
          _errorText = 'لا تملك 50 جوهرة لتغيير الاسم!';
        } else {
          _errorText = 'حدث خطأ أثناء حفظ الاسم';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blueAccent, width: 3),
        ),
        child: _isLoading 
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('الملف الشخصي', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 20),
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blueGrey,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'اسم اللاعب',
                      labelStyle: const TextStyle(color: Colors.white70),
                      errorText: _errorText.isEmpty ? null : _errorText,
                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    !_freeNameUsed 
                        ? 'تغيير الاسم متاح مجاناً للمرة الأولى!' 
                        : 'تكلفة تغيير الاسم: 50 جوهرة (رصيدك: \)',
                    style: TextStyle(color: !_freeNameUsed ? Colors.greenAccent : Colors.orangeAccent),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء', style: TextStyle(color: Colors.redAccent)),
                      ),
                      ElevatedButton(
                        onPressed: _saveName,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                        child: const Text('حفظ التعديلات', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                ],
              ),
      ),
    );
  }
}

