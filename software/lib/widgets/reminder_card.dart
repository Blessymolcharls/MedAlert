import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../models/dose_occurrence.dart';
import '../providers/reminder_provider.dart';
import 'confirm_dialog.dart';

class ReminderCard extends StatefulWidget {
  final Reminder reminder;
  final DateTime? occurrenceDate;

  const ReminderCard({super.key, required this.reminder, this.occurrenceDate});

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  DateTime get _effectiveDate => widget.occurrenceDate ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _manageAnimation();
    });
  }

  void _manageAnimation() {
    final now = DateTime.now();
    final isToday =
        DoseOccurrence.toDateKey(_effectiveDate) ==
        DoseOccurrence.toDateKey(now);

    if (!isToday) {
      _controller.value = 1.0;
      _controller.stop();
      return;
    }

    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      widget.reminder.time.hour,
      widget.reminder.time.minute,
    );
    final diff = now.difference(scheduled).inMinutes;

    final provider = Provider.of<ReminderProvider>(context, listen: false);
    final status = provider.getDoseStatus(widget.reminder, _effectiveDate);

    if (status == DoseStatus.pending ||
        (diff >= 0 && diff <= 15 && status != DoseStatus.taken)) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.value = 1.0;
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(ReminderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _manageAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const ConfirmDialog(),
    );

    if (result == true) {
      if (context.mounted) {
        Provider.of<ReminderProvider>(
          context,
          listen: false,
        ).confirmIntake(widget.reminder.id, date: _effectiveDate);
      }
    }
  }

  void _showDeleteDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDarkTheme = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red.shade400, size: 24),
              const SizedBox(width: 8),
              Text(
                "Delete Task",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            "Are you sure you want to delete '${widget.reminder.name}'?",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDarkTheme ? Colors.grey.shade300 : Colors.grey.shade800,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                "Cancel",
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Delete",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      Provider.of<ReminderProvider>(
        context,
        listen: false,
      ).removeReminder(widget.reminder.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Deleted reminder for ${widget.reminder.name}"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final provider = Provider.of<ReminderProvider>(context);
    final status = provider.getDoseStatus(widget.reminder, _effectiveDate);
    final takenAt = provider.getDoseTakenAt(widget.reminder.id, _effectiveDate);

    final displayAsTaken = status == DoseStatus.taken;
    final displayAsMissed = status == DoseStatus.missed;
    final isPending = status == DoseStatus.pending;
    final isUpcoming = status == DoseStatus.upcoming;

    Color leftAccent = const Color(0xFF1F4D45);
    Color backgroundColor =
        isDark ? t.cardColor : const Color(0xFFFDF0F2);
    String statusText = status.displayName;
    Color statusColor = Colors.orange.withValues(alpha: 0.15);
    Color statusTextColor = Colors.orange.shade800;

    if (displayAsTaken) {
      leftAccent = Colors.green;
      backgroundColor = isDark
          ? Colors.green.withValues(alpha: 0.1)
          : const Color(0xFFF1F8E9);
      statusText = "Taken";
      statusColor = Colors.green.withValues(alpha: 0.2);
      statusTextColor = Colors.green.shade800;
    } else if (displayAsMissed) {
      leftAccent = Colors.red;
      backgroundColor = isDark
          ? Colors.red.withValues(alpha: 0.1)
          : const Color(0xFFFFEBEE);
      statusText = "Missed";
      statusColor = Colors.red.withValues(alpha: 0.2);
      statusTextColor = Colors.red.shade800;
    } else if (isPending) {
      leftAccent = const Color(0xFF1F4D45);
      statusText = "Pending";
      statusColor = Colors.orange.withValues(alpha: 0.25);
      statusTextColor = Colors.orange.shade900;
    }

    final formattedTakenTime = takenAt != null
        ? TimeOfDay.fromDateTime(takenAt).format(context)
        : "";

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: (isUpcoming && !displayAsTaken && !displayAsMissed)
              ? 0.75
              : _animation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Card(
              color: backgroundColor,
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Accent
                    Container(
                      width: 5,
                      decoration: BoxDecoration(
                        color: leftAccent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                    // Main Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.reminder.dosage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.reminder.time.format(context),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      key: Key(
                                        'delete_reminder_${widget.reminder.id}',
                                      ),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                      ),
                                      color: isDark
                                          ? Colors.red.shade300
                                          : Colors.red.shade400,
                                      tooltip: "Delete task",
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      splashRadius: 18,
                                      onPressed: () =>
                                          _showDeleteDialog(context),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Food Badge
                                Opacity(
                                  opacity: displayAsMissed ? 0.6 : 1.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
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
                                ),
                                // Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: statusTextColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (displayAsTaken &&
                                    formattedTakenTime.isNotEmpty)
                                  Text(
                                    "Taken at $formattedTakenTime",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (isPending)
                                  ElevatedButton(
                                    onPressed: () =>
                                        _showConfirmDialog(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      "Confirm Intake",
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else if (isUpcoming)
                                  ElevatedButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Confirmation allowed only at scheduled time",
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade400,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      "Not Yet",
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
