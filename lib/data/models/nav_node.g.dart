// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nav_node.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NavNodeAdapter extends TypeAdapter<NavNode> {
  @override
  final int typeId = 0;

  @override
  NavNode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NavNode(
      id: fields[0] as String,
      label: fields[1] as String,
      x: fields[2] as double,
      y: fields[3] as double,
      floor: fields[4] as int,
      nodeTypeStr: fields[5] as String,
      buildingId: fields[6] as String,
      metadata: (fields[7] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, NavNode obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.x)
      ..writeByte(3)
      ..write(obj.y)
      ..writeByte(4)
      ..write(obj.floor)
      ..writeByte(5)
      ..write(obj.nodeTypeStr)
      ..writeByte(6)
      ..write(obj.buildingId)
      ..writeByte(7)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavNodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
