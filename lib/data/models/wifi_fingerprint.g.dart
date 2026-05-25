// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wifi_fingerprint.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ApReadingAdapter extends TypeAdapter<ApReading> {
  @override
  final int typeId = 2;

  @override
  ApReading read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ApReading(
      bssid: fields[0] as String,
      ssid: fields[1] as String,
      rssi: fields[2] as int,
      frequency: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ApReading obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.bssid)
      ..writeByte(1)
      ..write(obj.ssid)
      ..writeByte(2)
      ..write(obj.rssi)
      ..writeByte(3)
      ..write(obj.frequency);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApReadingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WifiFingerprintAdapter extends TypeAdapter<WifiFingerprint> {
  @override
  final int typeId = 3;

  @override
  WifiFingerprint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WifiFingerprint(
      id: fields[0] as String,
      nodeId: fields[1] as String,
      buildingId: fields[2] as String,
      floor: fields[3] as int,
      readings: (fields[4] as List).cast<ApReading>(),
      collectedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, WifiFingerprint obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nodeId)
      ..writeByte(2)
      ..write(obj.buildingId)
      ..writeByte(3)
      ..write(obj.floor)
      ..writeByte(4)
      ..write(obj.readings)
      ..writeByte(5)
      ..write(obj.collectedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WifiFingerprintAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
