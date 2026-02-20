import 'package:hive_flutter/hive_flutter.dart';
import '../models/compartment.dart';

class StorageService {
  static const String boxName = 'compartmentsBox';

  Future<void> init() async {
    await Hive.openBox<Compartment>(boxName);
    _initializeEmptyCompartments();
  }

  Box<Compartment> get box => Hive.box<Compartment>(boxName);

  void _initializeEmptyCompartments() {
    if (box.isEmpty) {
      final days = ['Monday', 'Tuesday', 'Wednesday'];
      final slots = [
        'Morning Before Food',
        'Morning After Food',
        'Noon Before Food',
        'Noon After Food',
        'Night Before Food',
        'Night After Food',
      ];

      for (var day in days) {
        for (int i = 0; i < slots.length; i++) {
          final compartment = Compartment.empty(day, i + 1, slots[i]);
          box.put('${day}_${i + 1}', compartment);
        }
      }
    }
  }

  List<Compartment> getAllCompartments() {
    return box.values.toList();
  }

  Future<void> updateCompartment(Compartment compartment) async {
    await box.put('${compartment.day}_${compartment.slotIndex}', compartment);
  }

  List<Compartment> getCompartmentsForDay(String day) {
    return box.values.where((c) => c.day == day).toList()
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
  }
}
