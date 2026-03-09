import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';

class AddReminderPage extends StatefulWidget {
  const AddReminderPage({super.key});

  @override
  State<AddReminderPage> createState() => _AddReminderPageState();
}

class _AddReminderPageState extends State<AddReminderPage>
    with SingleTickerProviderStateMixin {
  final List<String> _days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  late List<bool> _selectedDays;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _selectedDays = List.generate(7, (_) => false);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  final GlobalKey<_SectionCardState> _morningKey = GlobalKey();
  final GlobalKey<_SectionCardState> _noonKey = GlobalKey();
  final GlobalKey<_SectionCardState> _nightKey = GlobalKey();

  Future<void> _saveReminder() async {
    // Collect selected days indices
    final List<int> selectedDayIndices = [];
    for (int i = 0; i < _selectedDays.length; i++) {
      if (_selectedDays[i]) {
        selectedDayIndices.add(i);
      }
    }

    if (selectedDayIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one day"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Try to get data from cards
    final List<_SectionCardState?> cards = [
      _morningKey.currentState,
      _noonKey.currentState,
      _nightKey.currentState,
    ];

    bool addedAny = false;

    for (var card in cards) {
      if (card != null &&
          card._medicineController.text.isNotEmpty &&
          card._selectedTime != null) {
        final t = card._selectedTime!;
        final section = card.widget.title;
        bool isValidTime = false;

        if (section == "Morning" && t.hour >= 4 && t.hour < 12) {
          isValidTime = true;
        } else if (section == "Noon" && t.hour >= 12 && t.hour < 17) {
          isValidTime = true;
        } else if (section == "Night" &&
            (t.hour >= 17 && t.hour < 24 || t.hour < 4)) {
          // Allow night up to 3:59 AM if needed but prompt says 5:00 PM - 11:59 PM
          if (t.hour >= 17) isValidTime = true;
        }

        if (!isValidTime) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Selected time does not match Morning/Noon/Night period",
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final reminder = Reminder(
          id:
              DateTime.now().millisecondsSinceEpoch.toString() +
              card.widget.title,
          name: card._medicineController.text,
          dosage: card._dosageController.text.isEmpty
              ? "1 pill"
              : card._dosageController.text,
          time: t,
          isAfterFood: card._isAfterFood,
          section: section,
          isTakenToday: false,
          isMissedToday: false,
          selectedDays: selectedDayIndices,
          createdAt: DateTime.now(),
        );
        Provider.of<ReminderProvider>(
          context,
          listen: false,
        ).addReminder(reminder);
        addedAny = true;
      }
    }

    if (!addedAny) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill at least one section with name and time"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Saving your reminder...",
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2, milliseconds: 500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
      ),
    );

    // Show Success Dialog
    _animController.forward(from: 0.0);
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: _animController,
              curve: Curves.easeOutBack,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Reminder Added\nSuccessfully!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F4D45),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Delay for 2.5 seconds
    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      // Close dialog
      Navigator.of(context, rootNavigator: true).pop();
      // Pass Data Back to Home
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F2),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1F4D45),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Add Reminder',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F4D45),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select Days",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F4D45),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8.0,
                runSpacing: 12.0,
                children: List.generate(_days.length, (index) {
                  final isSelected = _selectedDays[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDays[index] = !_selectedDays[index];
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1F4D45)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _days[index],
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              _SectionCard(key: _morningKey, title: "Morning", emoji: "🌅"),
              const SizedBox(height: 16),
              _SectionCard(key: _noonKey, title: "Noon", emoji: "☀️"),
              const SizedBox(height: 16),
              _SectionCard(key: _nightKey, title: "Night", emoji: "🌙"),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveReminder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F4D45),
                    shape: const StadiumBorder(),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    "Save Reminder",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatefulWidget {
  final String title;
  final String emoji;

  const _SectionCard({super.key, required this.title, required this.emoji});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  TimeOfDay? _selectedTime;
  final TextEditingController _medicineController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  bool _isAfterFood = false;

  @override
  void dispose() {
    _medicineController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _selectedTime = null;
      _medicineController.clear();
      _dosageController.clear();
      _isAfterFood = false;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Text(widget.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F4D45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Time Picker
              ElevatedButton(
                onPressed: _pickTime,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1F4D45),
                  elevation: 0,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _selectedTime != null
                          ? _selectedTime!.format(context)
                          : "Select Time",
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Medicine Name Field
              TextFormField(
                controller: _medicineController,
                decoration: InputDecoration(
                  hintText: "e.g. Paracetamol",
                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF1F4D45),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                style: GoogleFonts.inter(color: Colors.black87),
              ),
              const SizedBox(height: 16),

              // Dosage Field
              TextFormField(
                controller: _dosageController,
                decoration: InputDecoration(
                  hintText: "e.g. 500mg",
                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF1F4D45),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                style: GoogleFonts.inter(color: Colors.black87),
              ),
              const SizedBox(height: 16),

              // Before / After Food Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Before",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isAfterFood,
                    onChanged: (val) {
                      setState(() {
                        _isAfterFood = val;
                      });
                    },
                    activeThumbColor: const Color(0xFFF5C842),
                    activeTrackColor: const Color(0xFFF5C842).withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "After",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Reset Button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _reset,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    "Reset",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
