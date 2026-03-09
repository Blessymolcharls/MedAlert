import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../providers/ble_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _lastResetDate = "Never";

  @override
  void initState() {
    super.initState();
    _loadResetDate();
  }

  Future<void> _loadResetDate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastResetDate = prefs.getString('lastResetDate') ?? "Never";
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bleProvider = Provider.of<BleProvider>(context);

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
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF1F4D45),
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
                              : Icons.bluetooth_disabled,
                          color: bleProvider.isConnected
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          bleProvider.isConnected
                              ? "Connected to MedAlert Box"
                              : "Disconnected",
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
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
                            : "Reconnect Device",
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Daily Reset Logic Module
            _buildSectionHeader("System Status"),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history, color: Color(0xFF1F4D45)),
                title: Text(
                  "Last Daily Reset",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_lastResetDate, style: GoogleFonts.inter()),
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
