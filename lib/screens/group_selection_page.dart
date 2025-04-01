import 'package:flutter/material.dart';

class GroupSelectionPage extends StatefulWidget {
  final List<String> groups;
  final Map<String, List<Map<String, String>>> groupStudents;

  const GroupSelectionPage({
    Key? key,
    required this.groups,
    required this.groupStudents,
  }) : super(key: key);

  @override
  _GroupSelectionPageState createState() => _GroupSelectionPageState();
}

class _GroupSelectionPageState extends State<GroupSelectionPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Group')),
      body: ListView.builder(
        itemCount: widget.groups.length,
        itemBuilder: (context, index) {
          final group = widget.groups[index];
          return ListTile(
            title: Text(group),
            subtitle: Text('${widget.groupStudents[group]?.length ?? 0} students'),
            onTap: () {
              setState(() {
                widget.groupStudents[group]?.removeWhere((student) => student.isEmpty); // Remove deleted students
              });
              Navigator.pop(context, group); // Pass the selected group back
            },
          );
        },
      ),
    );
  }
}
