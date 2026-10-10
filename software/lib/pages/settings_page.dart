import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/ble_provider.dart';
import '../providers/reminder_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bleProvider = Provider.of<BleProvider>(context);
    final reminderProvider = Provider.of<ReminderProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, // inherited from MainShell
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              "Settings",
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1F4D45),
              ),
            ),
            const SizedBox(height: 24),

            // Theme Mode Module
            _buildSectionHeader("Appearance"),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.dark_mode_outlined,
                  color: Color(0xFF1F4D45),
                ),
                title: Text(
                  "Dark Mode",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                trailing: Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (val) => themeProvider.toggleTheme(val),
                  activeThumbColor: const Color(0xFFF5C842),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bluetooth Module
            _buildSectionHeader("Device Connection"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          bleProvider.isConnected
                              ? Icons.bluetooth_connected
                              : (bleProvider.status == BleStatus.scanning
                                    ? Icons.bluetooth_searching
                                    : Icons.bluetooth_disabled),
                          color: bleProvider.isConnected
                              ? Colors.green
                              : (bleProvider.status == BleStatus.scanning
                                    ? Colors.orange
                                    : Colors.red),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bleProvider.isConnected
                                    ? (bleProvider.deviceName ??
                                          "Connected to MedAlert Box")
                                    : (bleProvider.status == BleStatus.scanning
                                          ? "Scanning for MedAlert..."
                                          : "Disconnected"),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (bleProvider.isConnected &&
                                  bleProvider.deviceId != null)
                                Text(
                                  "Device ID: ${bleProvider.deviceId}",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              if (bleProvider.lastSyncTime != null)
                                Text(
                                  "Last synced: ${TimeOfDay.fromDateTime(bleProvider.lastSyncTime!).format(context)}",
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (bleProvider.isConnected) {
                                bleProvider.disconnect();
                              } else {
                                bleProvider.connect();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: bleProvider.isConnected
                                  ? Colors.red.shade50
                                  : const Color(0xFF1F4D45),
                              foregroundColor: bleProvider.isConnected
                                  ? Colors.red
                                  : Colors.white,
                            ),
                            child: Text(
                              bleProvider.isConnected
                                  ? "Disconnect"
                                  : (bleProvider.status == BleStatus.scanning
                                        ? "Scanning..."
                                        : "Connect Device"),
                            ),
                          ),
                        ),
                        if (bleProvider.isConnected) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final ok = await bleProvider
                                  .sendRemindersToDevice(
                                    reminderProvider.reminders,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? "Schedules synced to ESP32!"
                                          : "Failed to sync schedules",
                                    ),
                                    backgroundColor: ok
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.sync, size: 16),
                            label: const Text("Sync Box"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F4D45),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Daily Maintenance Status Module
            _buildSectionHeader("System Status & Maintenance"),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.history,
                      color: Color(0xFF1F4D45),
                    ),
                    title: Text(
                      "Last Daily Maintenance",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      reminderProvider.lastResetDate,
                      style: GoogleFonts.inter(),
                    ),
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text("Check"),
                      onPressed: () async {
                        await reminderProvider.checkDailyReset();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Maintenance check completed"),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
