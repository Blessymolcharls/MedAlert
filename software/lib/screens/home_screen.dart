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

class CompartmentCard extends StatelessWidget {
  final Compartment compartment;
  const CompartmentCard({super.key, required this.compartment});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'empty':
        return Colors.grey.shade400;
      case 'upcoming':
        return Colors.blue.shade400;
      case 'taken':
        return Colors.green.shade400;
      case 'missed':
        return Colors.red.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _getStatusColor(compartment.status),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => EditDialog(compartment: compartment),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                compartment.slotName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (compartment.medicineName.isNotEmpty) ...[
                Text(
                  compartment.medicineName,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '\${compartment.time} | \${compartment.dosage}',
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const Text('Empty', textAlign: TextAlign.center),
              ],
              const Spacer(),
              Text(
                compartment.status,
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
