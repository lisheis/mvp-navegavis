// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nav_edge.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NavEdgeAdapter extends TypeAdapter<NavEdge> {
  @override
  final int typeId = 1;

  @override
  NavEdge read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NavEdge(
      id: fields[0] as String,
      fromNodeId: fields[1] as String,
      toNodeId: fields[2] as String,
      weight: fields[3] as double,
      bidirectional: fields[4] as bool,
      edgeTypeStr: fields[5] as String,
      accessible: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, NavEdge obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fromNodeId)
      ..writeByte(2)
      ..write(obj.toNodeId)
      ..writeByte(3)
      ..write(obj.weight)
      ..writeByte(4)
      ..write(obj.bidirectional)
      ..writeByte(5)
      ..write(obj.edgeTypeStr)
      ..writeByte(6)
      ..write(obj.accessible);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavEdgeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
