import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';
import 'confirm_dialog.dart';
// import removed

class ReminderCard extends StatefulWidget {
  final Reminder reminder;

  const ReminderCard({super.key, required this.reminder});

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

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

    _manageAnimation();
  }

  void _manageAnimation() {
    final now = DateTime.now();
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      widget.reminder.time.hour,
      widget.reminder.time.minute,
    );
    final diff = now.difference(scheduled).inMinutes;
    final isTooLate = diff > 15;
    final displayAsTaken = widget.reminder.isTakenToday;
    final displayAsMissed =
        widget.reminder.isMissedToday || (!displayAsTaken && isTooLate);

    if (!displayAsTaken && !displayAsMissed && diff >= 0 && diff <= 15) {
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
        ).confirmIntake(widget.reminder.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    final now = DateTime.now();
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      widget.reminder.time.hour,
      widget.reminder.time.minute,
    );
    final diff = now.difference(scheduled).inMinutes;
    final isTooEarly = diff < 0;
    final isTooLate = diff > 15;

    final displayAsTaken = widget.reminder.isTakenToday;
    final displayAsMissed =
        widget.reminder.isMissedToday || (!displayAsTaken && isTooLate);

    Color leftAccent = const Color(0xFF1F4D45);
    Color backgroundColor = t.cardColor;
    String statusText = "Upcoming";
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
    }

    final formattedTime = widget.reminder.lastTakenAt != null
        ? TimeOfDay.fromDateTime(widget.reminder.lastTakenAt!).format(context)
        : "";

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: (isTooEarly && !displayAsTaken && !displayAsMissed)
              ? 0.6
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
                                    widget.reminder.lastTakenAt != null)
                                  Text(
                                    "Taken at $formattedTime",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (!displayAsTaken && !displayAsMissed)
                                  if (isTooEarly)
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
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        "Not Yet",
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else
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
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        "Confirm Intake",
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
