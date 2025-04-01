import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'dart:convert'; // For JSON encoding

class DeleteGroupPage extends StatefulWidget {
  final List<String> groups;
  final Map<String, List<Map<String, String>>> groupStudents; // Pass groupStudents
  final Function(String)? onDeleteGroup; // Callback for deleting the group
  final Function(String, String)? onDeleteStudent; // Callback for deleting individual students

  const DeleteGroupPage({
    super.key,
    required this.groups,
    required this.groupStudents,
    this.onDeleteGroup,
    this.onDeleteStudent,
  });

  @override
  _DeleteGroupPageState createState() => _DeleteGroupPageState();
}

class _DeleteGroupPageState extends State<DeleteGroupPage> {
  Future<void> _saveGroupsToJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('groups', jsonEncode(widget.groups));
      await prefs.setString('groupStudents', jsonEncode(widget.groupStudents));
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
  }

  void _confirmDeleteGroup(BuildContext context, String groupName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete the group "$groupName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                widget.groups.remove(groupName); // Remove group from the list
                widget.groupStudents.remove(groupName); // Clear all associated data
              });
              _saveGroupsToJson(); // Save changes persistently
              if (widget.onDeleteGroup != null) {
                widget.onDeleteGroup!(groupName); // Notify parent widget
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStudent(BuildContext context, String groupName, String studentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete the student "$studentName" from "$groupName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                final students = widget.groupStudents[groupName];
                if (students != null) {
                  students.removeWhere((student) => student['name'] == studentName);
                  if (students.isEmpty) {
                    widget.groupStudents.remove(groupName); // Remove group if no students remain
                  }
                }
              });
              _saveGroupsToJson(); // Save changes persistently
              if (widget.onDeleteStudent != null) {
                widget.onDeleteStudent!(groupName, studentName); // Notify parent widget
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Groups or Students'),
      ),
      body: ListView.builder(
        itemCount: widget.groups.length,
        itemBuilder: (context, index) {
          final groupName = widget.groups[index];
          final students = widget.groupStudents[groupName] ?? [];

          return Card(
            child: ExpansionTile(
              leading: Icon(Icons.group, color: Theme.of(context).colorScheme.primary),
              title: Text(groupName),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                onPressed: () => _confirmDeleteGroup(context, groupName),
              ),
              children: students.map((student) {
                final studentName = student['name']!;
                final regNo = student['regNo']!;
                return ListTile(
                  leading: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                  title: Text('$studentName ($regNo)'), // Display name and registration number without "Reg No" label
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                    onPressed: () => _confirmDeleteStudent(context, groupName, studentName),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
