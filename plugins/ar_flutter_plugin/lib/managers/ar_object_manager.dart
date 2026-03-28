import 'package:ar_flutter_plugin/utils/json_converters.dart';
import 'package:flutter/services.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';

class ARObjectManager {
  late MethodChannel _channel;

  // REZOLVAT: Acum primeste `int id` la fel ca ceilalti manageri
  ARObjectManager(int id) {
    _channel = MethodChannel('arobjects_$id'); // Cream canalul intern
  }

  void onInitialize() {
    _channel.invokeMethod<void>('initObjectManager');
  }

  Future<bool?> addNode(ARNode node, {ARAnchor? parentAnchor}) async {
    try {
      node.transformNotifier.addListener(() {
        _channel.invokeMethod<void>('transformationChanged', {
          'name': node.name,
          'transformation': const MatrixConverter().toJson(node.transform)
        });
      });
      // Am schimbat planeAnchor cu parentAnchor ca sa suportam si ImageAnchor
      bool? didAddNode = await _channel.invokeMethod<bool>('addNode', {
        'dict': node.toMap(),
      });
      return didAddNode;
    } on PlatformException catch (e) {
      print('Error adding node: $e');
      return false;
    }
  }

  Future<void> removeNode(ARNode node) async {
    try {
      node.transformNotifier.removeListener(() {});
      await _channel.invokeMethod<void>('removeNode', {'name': node.name});
    } on PlatformException catch (e) {
      print('Error removing node: $e');
    }
  }
}
