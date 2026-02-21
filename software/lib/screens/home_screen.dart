import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/compartment.dart';
import '../widgets/edit_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MedAlert'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Monday'),
              Tab(text: 'Tuesday'),
              Tab(text: 'Wednesday'),
            ],
          ),
          actions: [
            Consumer<AppState>(
              builder: (context, state, child) {
                return IconButton(
                  icon: Icon(
                    state.isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: state.isConnected ? Colors.green : Colors.red,
                  ),
                  onPressed: () {
                    if (state.isConnected) {
                      state.syncDevice();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Syncing with MedAlert via BLE...'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Not connected to MedAlert'),
                        ),
                      );
                    }
                  },
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: const TabBarView(
          children: [
            DayGrid(day: 'Monday'),
            DayGrid(day: 'Tuesday'),
            DayGrid(day: 'Wednesday'),
          ],
        ),
      ),
    );
  }
}

class DayGrid extends StatelessWidget {
  final String day;
  const DayGrid({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final compartments = state.getCompartmentsForDay(day);

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                2, // 2 columns for better layout, or maybe ListView since web doesn't require 6 cols on phones
            childAspectRatio: 1.2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: compartments.length,
          itemBuilder: (context, index) {
            final comp = compartments[index];
            return CompartmentCard(compartment: comp);
          },
        );
      },
    );
  }
}

class CompartmentCard extends StatefulWidget {
  final Compartment compartment;
  const CompartmentCard({super.key, required this.compartment});

  @override
  State<CompartmentCard> createState() => _CompartmentCardState();
}

class _CompartmentCardState extends State<CompartmentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 8.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'empty':
        return Colors.grey.shade400;
      case 'upcoming':
        return Colors.blue.shade400;
      case 'done':
        return Colors.green.shade400;
      case 'missed':
        return Colors.red.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canConfirm =
        (widget.compartment.status.toLowerCase() == 'upcoming' ||
            widget.compartment.status.toLowerCase() == 'missed') &&
        widget.compartment.medicineName.isNotEmpty;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Card(
            color: _getStatusColor(widget.compartment.status),
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (_) => EditDialog(compartment: widget.compartment),
                );
                if (mounted) {
                  setState(() {});
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.compartment.slotName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (widget.compartment.medicineName.isNotEmpty) ...[
                      Text(
                        widget.compartment.medicineName,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${widget.compartment.time} | ${widget.compartment.dosage}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ] else ...[
                      const Text('Empty', textAlign: TextAlign.center),
                    ],
                    const Spacer(),
                    if (canConfirm)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blueGrey,
                          padding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onPressed: () {
                          // Call markAsTaken via Provider
                          context.read<AppState>().markAsTaken(
                            widget.compartment,
                          );
                        },
                        child: const Text(
                          'Confirm Intake',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Text(
                        widget.compartment.status,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
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
