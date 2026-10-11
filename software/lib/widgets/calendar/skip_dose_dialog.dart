import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SkipDoseDialog extends StatefulWidget {
  final String medicineName;

  const SkipDoseDialog({super.key, required this.medicineName});

  @override
  State<SkipDoseDialog> createState() => _SkipDoseDialogState();
}

class _SkipDoseDialogState extends State<SkipDoseDialog> {
  String _selectedReason = "Doctor advised";
  final _customReasonController = TextEditingController();

  final List<String> _predefinedReasons = [
    "Doctor advised",
    "Fasting required",
    "Feeling nauseous",
    "Medication unavailable",
    "Other",
  ];

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Row(
        children: [
          Icon(Icons.skip_next_rounded, color: Colors.orange.shade700, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Skip Dose',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1F4D45),
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Are you sure you want to skip '${widget.medicineName}' for this schedule?",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Reason (optional):",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF1F4D45),
              ),
            ),
            const SizedBox(height: 8),
            ..._predefinedReasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return InkWell(
                onTap: () => setState(() => _selectedReason = reason),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 20,
                        color: isSelected
                            ? const Color(0xFF1F4D45)
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        reason,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (_selectedReason == "Other") ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customReasonController,
                decoration: const InputDecoration(
                  labelText: "Enter reason",
                  hintText: "e.g. Felt fine without it",
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(color: Colors.grey.shade600),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = _selectedReason == "Other" &&
                    _customReasonController.text.trim().isNotEmpty
                ? _customReasonController.text.trim()
                : _selectedReason;
            Navigator.of(context).pop(reason);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Confirm Skip',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
