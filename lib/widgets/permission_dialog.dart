import 'package:flutter/material.dart';

class UsageAccessPermissionDialog extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const UsageAccessPermissionDialog({
    Key? key,
    required this.onOpenSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    
    return AlertDialog(
      title: Text(
        'Usage Access Permission Required',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MindTrack needs usage access permission to track your screen time and app usage.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'How to enable:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            _buildInstructionStep(
              number: 1,
              text: 'Tap the "Open Settings" button below',
              color: primaryColor,
            ),
            _buildInstructionStep(
              number: 2,
              text: 'Find and select "MindTrack" from the list',
              color: primaryColor,
            ),
            _buildInstructionStep(
              number: 3,
              text: 'Toggle "Allow usage access" to ON',
              color: primaryColor,
            ),
            _buildInstructionStep(
              number: 4,
              text: 'Return to MindTrack',
              color: primaryColor,
            ),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Note: Without this permission, MindTrack cannot provide accurate insights about your digital wellbeing.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'Later',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: onOpenSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
          ),
          child: Text(
            'Open Settings',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep({
    required int number,
    required String text,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
