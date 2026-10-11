import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/reminder.dart';
import '../../providers/reminder_provider.dart';
import '../../utils/calendar_utils.dart';

class EditReminderDialog extends StatefulWidget {
  final Reminder reminder;

  const EditReminderDialog({super.key, required this.reminder});

  @override
  State<EditReminderDialog> createState() => _EditReminderDialogState();
}

class _EditReminderDialogState extends State<EditReminderDialog> {
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TimeOfDay _selectedTime;
  late bool _isAfterFood;
  late List<bool> _selectedDays;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.reminder.name);
    _dosageController = TextEditingController(text: widget.reminder.dosage);
    _selectedTime = widget.reminder.time;
    _isAfterFood = widget.reminder.isAfterFood;
    _selectedDays = List.generate(
      7,
      (i) => widget.reminder.selectedDays.contains(i),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    final dosage = _dosageController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a medication name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final activeDayIndices = <int>[];
    for (int i = 0; i < 7; i++) {
      if (_selectedDays[i]) activeDayIndices.add(i);
    }

    if (activeDayIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Determine section (Morning, Noon, Night) based on hour
    String section = 'Morning';
    if (_selectedTime.hour >= 12 && _selectedTime.hour < 17) {
      section = 'Noon';
    } else if (_selectedTime.hour >= 17 || _selectedTime.hour < 4) {
      section = 'Night';
    }

    final updated = widget.reminder.copyWith(
      name: name,
      dosage: dosage.isEmpty ? '1 pill' : dosage,
      time: _selectedTime,
      isAfterFood: _isAfterFood,
      section: section,
      selectedDays: activeDayIndices,
    );

    Provider.of<ReminderProvider>(
      context,
      listen: false,
    ).updateReminder(updated);

    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated schedule for $name'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Text(
        'Edit Medication Schedule',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF1F4D45),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Name Field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Medication Name',
                prefixIcon: Icon(Icons.medication_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // Dosage Field
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage (e.g. 500mg, 1 pill)',
                prefixIcon: Icon(Icons.scale_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Time Selector
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.access_time_rounded,
                color: Color(0xFF1F4D45),
              ),
              title: Text(
                'Scheduled Time',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _selectedTime.format(context),
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
              trailing: ElevatedButton(
                onPressed: _pickTime,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4D45),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('Change', style: GoogleFonts.inter(fontSize: 12)),
              ),
            ),
            const Divider(height: 20),

            // Food Instruction Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'After Food',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _isAfterFood ? 'Take after meal' : 'Take before meal',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
              value: _isAfterFood,
              activeThumbColor: const Color(0xFFF5C842),
              onChanged: (val) => setState(() => _isAfterFood = val),
            ),
            const Divider(height: 20),

            // Weekday Chips
            Text(
              'Repeat On',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1F4D45),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(7, (i) {
                final isSelected = _selectedDays[i];
                final dayLabel = CalendarUtils.shortWeekdayNames[i];

                return FilterChip(
                  label: Text(dayLabel),
                  selected: isSelected,
                  selectedColor: const Color(0xFF1F4D45),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (val) {
                    setState(() => _selectedDays[i] = val);
                  },
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(color: Colors.grey.shade600),
          ),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F4D45),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Save Changes',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
