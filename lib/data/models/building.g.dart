// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'building.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FloorPlanAdapter extends TypeAdapter<FloorPlan> {
  @override
  final int typeId = 4;

  @override
  FloorPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FloorPlan(
      floor: fields[0] as int,
      imageUrl: fields[1] as String?,
      widthMeters: fields[2] as double,
      heightMeters: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, FloorPlan obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.floor)
      ..writeByte(1)
      ..write(obj.imageUrl)
      ..writeByte(2)
      ..write(obj.widthMeters)
      ..writeByte(3)
      ..write(obj.heightMeters);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FloorPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BuildingAdapter extends TypeAdapter<Building> {
  @override
  final int typeId = 5;

  @override
  Building read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Building(
      id: fields[0] as String,
      name: fields[1] as String,
      address: fields[2] as String,
      floorPlans: (fields[3] as List).cast<FloorPlan>(),
      nodes: (fields[4] as List).cast<NavNode>(),
      edges: (fields[5] as List).cast<NavEdge>(),
      fingerprints: (fields[6] as List).cast<WifiFingerprint>(),
      lastSynced: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Building obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.floorPlans)
      ..writeByte(4)
      ..write(obj.nodes)
      ..writeByte(5)
      ..write(obj.edges)
      ..writeByte(6)
      ..write(obj.fingerprints)
      ..writeByte(7)
      ..write(obj.lastSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuildingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
