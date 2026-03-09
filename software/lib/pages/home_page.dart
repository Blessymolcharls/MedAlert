import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/reminder_provider.dart';
import '../widgets/reminder_card.dart';
import 'add_reminder_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Inherit from main shell wrapper
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 300),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const AddReminderPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;
                    final tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
            ),
          );
        },
        backgroundColor: const Color(0xFF1F4D45),
        shape: const StadiumBorder(),
        label: Text(
          '+ Add Reminder',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: Consumer<ReminderProvider>(
          builder: (context, provider, child) {
            final allReminders = provider.reminders;
            final todayIndex =
                DateTime.now().weekday - 1; // 0 for Monday, 6 for Sunday

            final reminders = allReminders
                .where((r) => r.selectedDays.contains(todayIndex))
                .toList();
            reminders.sort((a, b) {
              if (a.time.hour != b.time.hour) {
                return a.time.hour.compareTo(b.time.hour);
              }
              return a.time.minute.compareTo(b.time.minute);
            });

            final totalCount = reminders.length;
            final takenCount = reminders.where((r) => r.isTakenToday).length;
            final missedCount = reminders.where((r) => r.isMissedToday).length;
            final pendingCount = totalCount - takenCount - missedCount;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Area
                Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Here are today's reminders",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$totalCount total · $takenCount taken · $pendingCount pending · $missedCount missed",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Reminder List Section
                Expanded(
                  child: reminders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.medication_outlined,
                                size: 80,
                                color: Colors.green.shade100,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No matching reminders today",
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF1F4D45),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Tap + to add your first reminder",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 8.0,
                          ),
                          itemCount:
                              reminders.length +
                              1, // +1 for the bottom padding spacer
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            if (index == reminders.length) {
                              return const SizedBox(
                                height: 80,
                              ); // Padding to avoid FAB overlap
                            }
                            return ReminderCard(reminder: reminders[index]);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
