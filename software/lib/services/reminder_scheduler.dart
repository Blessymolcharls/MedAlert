import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/reminder_provider.dart';

class ReminderScheduler with WidgetsBindingObserver {
  final ReminderProvider provider;
  Timer? _timer;

  ReminderScheduler(this.provider);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _onPulse();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _onPulse();
    });
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onPulse();
    }
  }

  void _onPulse() {
    provider.checkDailyReset();
    provider.updateMissedStatuses();
  }
}
