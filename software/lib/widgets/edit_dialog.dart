import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/compartment.dart';
import '../providers/app_state.dart';

class EditDialog extends StatefulWidget {
  final Compartment compartment;

  const EditDialog({super.key, required this.compartment});

  @override
  State<EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<EditDialog> {
  final _medicineController = TextEditingController();
  final _dosageController = TextEditingController();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _medicineController.text = widget.compartment.medicineName;
    _dosageController.text = widget.compartment.dosage;

    if (widget.compartment.time.isNotEmpty &&
        widget.compartment.time != '00:00') {
      final parts = widget.compartment.time.split(':');
      if (parts.length == 2) {
        _selectedTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _save() {
    final comp = widget.compartment;
    comp.medicineName = _medicineController.text.trim();
    comp.dosage = _dosageController.text.trim();
    final hStr = _selectedTime.hour.toString().padLeft(2, '0');
    final mStr = _selectedTime.minute.toString().padLeft(2, '0');
    comp.time = '$hStr:$mStr';

    // Status Logic
    if (comp.medicineName.isEmpty) {
      comp.status = 'Empty';
      comp.time = '00:00';
    } else if (comp.status == 'Empty') {
      comp.status = 'Upcoming';
    }

    Provider.of<AppState>(context, listen: false).saveCompartment(comp);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.compartment.slotName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _medicineController,
              decoration: const InputDecoration(labelText: 'Medicine Name'),
            ),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage (e.g., 1 pill)',
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Time'),
              subtitle: Text(
                "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}",
              ),
              trailing: const Icon(Icons.access_time),
              onTap: () => _selectTime(context),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
