import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../pages/add_reminder_page.dart';

class EmptyScheduleState extends StatelessWidget {
  final DateTime date;

  const EmptyScheduleState({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1F4D45).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_outlined,
                size: 52,
                color: Color(0xFF1F4D45),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No medications scheduled',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1F4D45),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You have no scheduled doses for this day.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              key: const Key('empty_state_add_button'),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Add Reminder',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F4D45),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddReminderPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
