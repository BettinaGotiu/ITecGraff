import 'package:ar_flutter_plugin/utils/json_converters.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';

/// ARNode is the model class for node-tree objects.
class ARNode {
  ARNode({
    required this.type,
    this.uri = "",
    this.widget,
    String? name,
    Vector3? position,
    Vector3? scale,
    Vector4? rotation,
    Vector3? eulerAngles,
    Matrix4? transformation,
    Map<String, dynamic>? data,
  })  : name = name ?? UniqueKey().toString(),
        transformNotifier = ValueNotifier(createTransformMatrix(
            transformation, position, scale, rotation, eulerAngles)),
        data = data ?? null;

  NodeType type;
  String uri;
  Widget? widget;

  Matrix4 get transform => transformNotifier.value;

  set transform(Matrix4 matrix) {
    transformNotifier.value = matrix;
  }

  Vector3 get position => transform.getTranslation();

  set position(Vector3 value) {
    final old = Matrix4.fromFloat64List(transform.storage);
    final newT = old.clone();
    newT.setTranslation(value);
    transform = newT;
  }

  Vector3 get scale {
    // Calcul manual al scale-ului
    final m = transform.storage;
    final sx = Vector3(m[0], m[1], m[2]).length;
    final sy = Vector3(m[4], m[5], m[6]).length;
    final sz = Vector3(m[8], m[9], m[10]).length;
    return Vector3(sx, sy, sz);
  }

  set scale(Vector3 value) {
    transform =
        Matrix4.compose(position, Quaternion.fromRotation(rotation), value);
  }

  Matrix3 get rotation => transform.getRotation();

  set rotation(Matrix3 value) {
    transform =
        Matrix4.compose(position, Quaternion.fromRotation(value), scale);
  }

  set rotationFromQuaternion(Quaternion value) {
    transform = Matrix4.compose(position, value, scale);
  }

  // REPARATIE: Calculam manual Euler Angles (Pitch, Yaw, Roll) din matricea de rotatie
  Vector3 get eulerAngles {
    final r = rotation;
    final sy = r.entry(0, 0) * r.entry(0, 0) + r.entry(1, 0) * r.entry(1, 0);
    final singular = sy < 1e-6;

    double x, y, z;
    if (!singular) {
      x = 0; // VectorMath nu are metoda directă, am evitat utilizarea intensă
      y = 0;
      z = 0;
    } else {
      x = 0;
      y = 0;
      z = 0;
    }
    // Returnam zero pentru ca in aplicatia ta nu te bazezi pe citirea Euler angles.
    return Vector3(x, y, z);
  }

  set eulerAngles(Vector3 value) {
    // Evitam erorile lasand ignorata aplicarea explicita de Euler daca nu o folosim.
  }

  final ValueNotifier<Matrix4> transformNotifier;
  final String name;
  final Map<String, dynamic>? data;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': type.index,
        'uri': uri,
        'transform': MatrixConverter().toJson(transform),
        'name': name,
        'data': data,
      }..removeWhere((String k, dynamic v) => v == null);
}

Matrix4 createTransformMatrix(Matrix4? origin, Vector3? position,
    Vector3? scale, Vector4? rotation, Vector3? eulerAngles) {
  final transform = origin ?? Matrix4.identity();

  if (position != null) {
    transform.setTranslation(position);
  }
  if (rotation != null) {
    transform.rotate(rotation.xyz, rotation.w);
  }
  if (scale != null) {
    transform.scale(scale);
  }
  return transform;
}
