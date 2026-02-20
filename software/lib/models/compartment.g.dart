// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compartment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompartmentAdapter extends TypeAdapter<Compartment> {
  @override
  final int typeId = 0;

  @override
  Compartment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Compartment(
      day: fields[0] as String,
      slotIndex: fields[1] as int,
      slotName: fields[2] as String,
      medicineName: fields[3] as String,
      dosage: fields[4] as String,
      time: fields[5] as String,
      status: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Compartment obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.day)
      ..writeByte(1)
      ..write(obj.slotIndex)
      ..writeByte(2)
      ..write(obj.slotName)
      ..writeByte(3)
      ..write(obj.medicineName)
      ..writeByte(4)
      ..write(obj.dosage)
      ..writeByte(5)
      ..write(obj.time)
      ..writeByte(6)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompartmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
