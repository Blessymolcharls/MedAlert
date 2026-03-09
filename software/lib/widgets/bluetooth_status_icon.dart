import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';

class BluetoothStatusIcon extends StatefulWidget {
  const BluetoothStatusIcon({super.key});

  @override
  State<BluetoothStatusIcon> createState() => _BluetoothStatusIconState();
}

class _BluetoothStatusIconState extends State<BluetoothStatusIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, ble, child) {
        IconData iconData;
        Color foregroundColor;
        Color backgroundColor;
        bool isPulsing = false;

        switch (ble.status) {
          case BleStatus.disconnected:
            iconData = Icons.bluetooth_disabled;
            foregroundColor = Colors.red;
            backgroundColor = Colors.red.withOpacity(0.15);
            _animController.stop();
            _animController.value = 0.0;
            break;

          case BleStatus.scanning:
          case BleStatus.connecting:
            iconData = Icons.bluetooth_searching;
            foregroundColor = Colors.orange;
            backgroundColor = Colors.orange.withOpacity(0.15);
            isPulsing = true;
            if (!_animController.isAnimating) {
              _animController.repeat(reverse: true);
            }
            break;

          case BleStatus.connected:
            iconData = Icons.bluetooth_connected;
            foregroundColor = Colors.green;
            backgroundColor = Colors.green.withOpacity(0.15); // soft glow

            // bounce once
            if (_animController.isAnimating || _animController.value == 0.0) {
              _animController.stop();
              _animController.forward(from: 0.0);
            }
            break;
        }

        Widget iconWidget = AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
          ),
          child: Icon(iconData, color: foregroundColor, size: 20),
        );

        if (isPulsing) {
          iconWidget = AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Opacity(opacity: _pulseAnimation.value, child: child);
            },
            child: iconWidget,
          );
        } else if (ble.status == BleStatus.connected) {
          iconWidget = AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _animController.isAnimating
                    ? _bounceAnimation.value
                    : 1.0,
                child: child,
              );
            },
            child: iconWidget,
          );
        }

        return GestureDetector(
          onTap: () {
            if (ble.isConnected) {
              ble.disconnect();
            } else {
              ble.connect();
            }
          },
          child: iconWidget,
        );
      },
    );
  }
}
