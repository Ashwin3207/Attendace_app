import 'package:flutter/material.dart';

class GroupCreationPage extends StatefulWidget {
  final Function(String) onGroupCreated; // Callback to notify group creation
  const GroupCreationPage({super.key, required this.onGroupCreated});

  @override
  State<GroupCreationPage> createState() => _GroupCreationPageState();
}

class _GroupCreationPageState extends State<GroupCreationPage> {
  final TextEditingController _groupNameController = TextEditingController();

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name cannot be empty.')),
      );
      return;
    }

    widget.onGroupCreated(groupName); // Notify HomePage
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Group "$groupName" created successfully.')),
    );

    Navigator.pop(context); // Close the group creation page
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Group'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                labelStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                border: OutlineInputBorder(),
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _createGroup,
              icon: const Icon(Icons.group_add),
              label: const Text('Create Group'),
              style: Theme.of(context).elevatedButtonTheme.style,
            ),
          ],
        ),
      ),
    );
  }
}
