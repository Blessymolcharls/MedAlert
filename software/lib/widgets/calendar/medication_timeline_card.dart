import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/reminder.dart';
import '../../models/dose_occurrence.dart';
import '../../providers/reminder_provider.dart';
import '../confirm_dialog.dart';
import 'medication_details_dialog.dart';
import 'edit_reminder_dialog.dart';
import 'skip_dose_dialog.dart';

class MedicationTimelineCard extends StatefulWidget {
  final Reminder reminder;
  final DateTime occurrenceDate;

  const MedicationTimelineCard({
    super.key,
    required this.reminder,
    required this.occurrenceDate,
  });

  @override
  State<MedicationTimelineCard> createState() => _MedicationTimelineCardState();
}

class _MedicationTimelineCardState extends State<MedicationTimelineCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkPulse();
    });
  }

  void _checkPulse() {
    final provider = Provider.of<ReminderProvider>(context, listen: false);
    final status = provider.getDoseStatus(
      widget.reminder,
      widget.occurrenceDate,
    );

    if (status == DoseStatus.pending) {
      if (!_animController.isAnimating) {
        _animController.repeat(reverse: true);
      }
    } else {
      _animController.value = 1.0;
      _animController.stop();
    }
  }

  @override
  void didUpdateWidget(MedicationTimelineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkPulse();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _confirmTakeNow() async {
    final provider = Provider.of<ReminderProvider>(context, listen: false);
    final status = provider.getDoseStatus(
      widget.reminder,
      widget.occurrenceDate,
    );

    // If upcoming, require deliberate confirmation to avoid accidental intake
    if (status == DoseStatus.upcoming) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Confirm Early Intake',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            content: Text(
              "This dose is scheduled for ${widget.reminder.time.format(ctx)}. Are you sure you want to mark it as taken now?",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel', style: GoogleFonts.inter()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4D45),
                  foregroundColor: Colors.white,
                ),
                child: Text('Confirm', style: GoogleFonts.inter()),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;
    } else if (status == DoseStatus.pending) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => const ConfirmDialog(),
      );
      if (confirmed != true) return;
    }

    if (mounted) {
      provider.confirmIntake(
        widget.reminder.id,
        date: widget.occurrenceDate,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Marked ${widget.reminder.name} as taken!"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _skipDose() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SkipDoseDialog(medicineName: widget.reminder.name),
    );

    if (reason != null && mounted) {
      Provider.of<ReminderProvider>(
        context,
        listen: false,
      ).skipDose(widget.reminder.id, date: widget.occurrenceDate, reason: reason);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Skipped dose for ${widget.reminder.name}"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDetails() {
    showDialog(
      context: context,
      builder: (ctx) => MedicationDetailsDialog(
        reminder: widget.reminder,
        occurrenceDate: widget.occurrenceDate,
      ),
    );
  }

  void _showEdit() {
    showDialog(
      context: context,
      builder: (ctx) => EditReminderDialog(reminder: widget.reminder),
    );
  }

  void _showDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red.shade400, size: 24),
              const SizedBox(width: 8),
              Text(
                'Delete Medication',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            "Are you sure you want to delete '${widget.reminder.name}'? This will cancel all upcoming reminders.",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      Provider.of<ReminderProvider>(
        context,
        listen: false,
      ).removeReminder(widget.reminder.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Deleted ${widget.reminder.name}"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<ReminderProvider>(context);

    final status = provider.getDoseStatus(
      widget.reminder,
      widget.occurrenceDate,
    );
    final takenAt = provider.getDoseTakenAt(
      widget.reminder.id,
      widget.occurrenceDate,
    );
    final skipReason = provider.getDoseSkipReason(
      widget.reminder.id,
      widget.occurrenceDate,
    );

    // Styling configurations preserving MedAlert identity
    Color leftAccent = const Color(0xFF1F4D45);
    Color cardBg = isDark
        ? const Color(0xFF231C20)
        : const Color(0xFFFDF0F2); // Soft pastel-pink medication card
    Color borderColor = isDark
        ? const Color(0xFF382C32)
        : const Color(0xFFF7D9DC); // Subtle pink border
    String statusLabel = status.displayName;
    Color statusBadgeBg = Colors.orange.withValues(alpha: 0.15);
    Color statusTextColor = Colors.orange.shade800;

    switch (status) {
      case DoseStatus.taken:
        leftAccent = const Color(0xFF2E7D32);
        statusBadgeBg = Colors.green.withValues(alpha: 0.2);
        statusTextColor = Colors.green.shade800;
        break;
      case DoseStatus.missed:
        leftAccent = const Color(0xFFD32F2F);
        cardBg = isDark
            ? Colors.red.withValues(alpha: 0.1)
            : const Color(0xFFFFEBEE);
        borderColor = isDark ? Colors.red.shade900 : const Color(0xFFFFCDD2);
        statusBadgeBg = Colors.red.withValues(alpha: 0.2);
        statusTextColor = Colors.red.shade800;
        break;
      case DoseStatus.pending:
        leftAccent = const Color(0xFFF57F17);
        statusLabel = "Due Now";
        statusBadgeBg = Colors.orange.withValues(alpha: 0.25);
        statusTextColor = Colors.orange.shade900;
        break;
      case DoseStatus.upcoming:
        leftAccent = const Color(0xFF1F4D45);
        statusBadgeBg = Colors.blue.withValues(alpha: 0.12);
        statusTextColor = Colors.blue.shade900;
        break;
      case DoseStatus.skipped:
        leftAccent = Colors.grey.shade500;
        statusBadgeBg = Colors.grey.withValues(alpha: 0.2);
        statusTextColor = Colors.grey.shade800;
        break;
    }

    final formattedTakenTime = takenAt != null
        ? TimeOfDay.fromDateTime(takenAt).format(context)
        : null;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: status == DoseStatus.pending ? _pulseAnimation.value : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left status accent line
                    Container(width: 5, color: leftAccent),

                    // Main card body
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Medicine Name, Scheduled Time, Menu
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.reminder.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1F4D45),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.reminder.dosage,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Scheduled Time
                                Text(
                                  widget.reminder.time.format(context),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF1F4D45),
                                  ),
                                ),

                                // Actions Popup Menu
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    size: 20,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  splashRadius: 18,
                                  onSelected: (val) {
                                    if (val == 'details') _showDetails();
                                    if (val == 'edit') _showEdit();
                                    if (val == 'skip') _skipDose();
                                    if (val == 'delete') _showDelete();
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'details',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 18,
                                            color: Color(0xFF1F4D45),
                                          ),
                                          SizedBox(width: 8),
                                          Text('View Details'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                            color: Color(0xFF1F4D45),
                                          ),
                                          SizedBox(width: 8),
                                          Text('Edit Schedule'),
                                        ],
                                      ),
                                    ),
                                    if (status != DoseStatus.taken &&
                                        status != DoseStatus.skipped)
                                      const PopupMenuItem(
                                        value: 'skip',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.skip_next_rounded,
                                              size: 18,
                                              color: Colors.orange,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Skip Dose'),
                                          ],
                                        ),
                                      ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.red.shade400,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: Colors.red.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Badges & Action Buttons Wrap
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Food Instruction Badge (Yellow)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.reminder.isAfterFood
                                        ? const Color(0xFFF5C842)
                                        : const Color(0xFFE6C87C),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: Text(
                                    widget.reminder.isAfterFood
                                        ? "After Food"
                                        : "Before Food",
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),

                                // Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBadgeBg,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: statusTextColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                // Taken timestamp
                                if (status == DoseStatus.taken &&
                                    formattedTakenTime != null)
                                  Text(
                                    "Taken at $formattedTakenTime",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                // Skipped reason note
                                if (status == DoseStatus.skipped &&
                                    skipReason != null)
                                  Text(
                                    "Reason: $skipReason",
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),

                                // Action: Confirm Intake Button
                                if (status == DoseStatus.pending ||
                                    status == DoseStatus.upcoming ||
                                    status == DoseStatus.missed)
                                  ElevatedButton.icon(
                                    key: Key(
                                      'take_dose_${widget.reminder.id}_${widget.occurrenceDate.day}',
                                    ),
                                    onPressed: _confirmTakeNow,
                                    icon: const Icon(Icons.check, size: 14),
                                    label: Text(
                                      status == DoseStatus.pending
                                          ? "Confirm Intake"
                                          : (status == DoseStatus.missed
                                              ? "Mark Taken (Late)"
                                              : "Take Now"),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          status == DoseStatus.missed
                                              ? Colors.red.shade700
                                              : (status == DoseStatus.pending
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFF1F4D45)),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),

                                // Action: Skip Button
                                if (status == DoseStatus.pending ||
                                    status == DoseStatus.upcoming)
                                  OutlinedButton(
                                    onPressed: _skipDose,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey.shade700,
                                      side: BorderSide(
                                        color: Colors.grey.shade400,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(
                                      "Skip",
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
