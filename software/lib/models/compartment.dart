import 'package:hive/hive.dart';

part 'compartment.g.dart';

@HiveType(typeId: 0)
class Compartment extends HiveObject {
  @HiveField(0)
  String day;

  @HiveField(1)
  int slotIndex;

  @HiveField(2)
  String slotName;

  @HiveField(3)
  String medicineName;

  @HiveField(4)
  String dosage;

  @HiveField(5)
  String time;

  @HiveField(6)
  String status;

  Compartment({
    required this.day,
    required this.slotIndex,
    required this.slotName,
    required this.medicineName,
    required this.dosage,
    required this.time,
    required this.status,
  });

  factory Compartment.empty(String day, int slotIndex, String slotName) {
    return Compartment(
      day: day,
      slotIndex: slotIndex,
      slotName: slotName,
      medicineName: '',
      dosage: '',
      time: '00:00',
      status: 'Empty',
    );
  }
}
