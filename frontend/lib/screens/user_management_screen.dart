import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final res = await ApiService().getUsers();
      if (mounted) {
        setState(() {
          _users = res.data['users'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load users: $e\n\nHint: Have you deployed the new backend updates to your server?';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateRole(int id, String newRole) async {
    try {
      await ApiService().updateUserRole(id, newRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role updated successfully'), backgroundColor: Colors.green),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update role'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'worker': return 'Worker';
      case 'supervisor': return 'Supervisor';
      case 'k3_officer': return 'Ahli K3';
      case 'k3_umum': return 'Ahli K3 Umum';
      case 'mill_assistant': return 'Mill Assistant';
      case 'mill_manager': return 'Mill Manager';
      case 'admin': return 'Admin';
      default: return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Users')),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7))),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Users')),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: () {
                  setState(() { _isLoading = true; _error = null; });
                  _loadUsers();
                }, child: const Text('Retry'))
              ],
            ),
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Users')),
        body: const Center(child: Text('No users found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final u = _users[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF4FC3F7),
                    child: Text(u['name'][0].toUpperCase(), style: const TextStyle(color: Color(0xFF0F1923), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(u['email'], style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        if (u['department'] != null) 
                          Text(u['department'], style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                  DropdownButton<String>(
                    value: u['role'],
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF4FC3F7)),
                    items: ['worker', 'supervisor', 'k3_officer', 'k3_umum', 'mill_assistant', 'mill_manager', 'admin']
                        .map((r) => DropdownMenuItem(value: r, child: Text(_getRoleLabel(r), style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null && val != u['role']) {
                        _updateRole(u['id'], val);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
