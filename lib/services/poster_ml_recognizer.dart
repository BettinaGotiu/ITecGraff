import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class PosterMatch {
  final String posterId;
  final double score;
  PosterMatch(this.posterId, this.score);
}

class PosterMlRecognizer {
  late Interpreter _interpreter;
  late Map<String, List<List<double>>> _embeddings;
  bool _ready = false;

  Future<void> init({
    String modelPath = 'assets/models/mobilenet_v3_small.tflite',
  }) async {
    _interpreter = await Interpreter.fromAsset(modelPath);
    final jsonStr = await rootBundle.loadString(
      'assets/posters/posters_embeddings.json',
    );
    final Map<String, dynamic> decoded = json.decode(jsonStr);
    _embeddings = decoded.map(
      (k, v) => MapEntry(
        k,
        (v as List)
            .map(
              (lst) => (lst as List).map((e) => (e as num).toDouble()).toList(),
            )
            .toList(),
      ),
    );
    _ready = true;
  }

  bool get isReady => _ready;

  Future<PosterMatch?> match(
    Uint8List photoBytes, {
    double threshold = 0.55,
  }) async {
    if (!_ready) return null;
    const inputSize = 224;
    return compute(
      _runModel,
      _Payload(
        bytes: photoBytes,
        modelAddress: _interpreter.address,
        inputSize: inputSize,
        embeddings: _embeddings,
        threshold: threshold,
      ),
    );
  }
}

class _Payload {
  final Uint8List bytes;
  final int modelAddress;
  final int inputSize;
  final Map<String, List<List<double>>> embeddings;
  final double threshold;
  _Payload({
    required this.bytes,
    required this.modelAddress,
    required this.inputSize,
    required this.embeddings,
    required this.threshold,
  });
}

double _l2norm(List<double> v) {
  double s = 0;
  for (final x in v) s += x * x;
  final n = math.sqrt(s);
  if (n == 0) return 1.0;
  for (var i = 0; i < v.length; i++) v[i] /= n;
  return n;
}

List<double> _runEmbedding(
  Interpreter interpreter,
  img.Image image,
  int inputSize,
) {
  final resized = img.copyResize(image, width: inputSize, height: inputSize);
  final input = List.generate(
    inputSize,
    (y) => List.generate(inputSize, (x) {
      final px = resized.getPixel(x, y);
      return [px.r / 255.0, px.g / 255.0, px.b / 255.0];
    }),
  );
  final outTensor = interpreter.getOutputTensors().first;
  final outLen = outTensor.shape.reduce((a, b) => a * b);
  final out = List.filled(1, List.filled(outLen, 0.0));
  interpreter.run([input], out);
  final emb = (out[0] as List).map((e) => (e as num).toDouble()).toList();
  _l2norm(emb);
  return emb;
}

Future<PosterMatch?> _runModel(_Payload p) async {
  final interpreter = Interpreter.fromAddress(p.modelAddress);
  final img.Image? decoded = img.decodeImage(p.bytes);
  if (decoded == null) return null;

  final variants = <img.Image>[];
  // full
  variants.add(decoded);

  // center square + scale crops (0.6, 0.8, 1.0)
  final minSide = math.min(decoded.width, decoded.height);
  for (final frac in [1.0, 0.8, 0.6]) {
    final c = (minSide * frac).toInt();
    final x = (decoded.width - c) ~/ 2;
    final y = (decoded.height - c) ~/ 2;
    final crop = img.copyCrop(decoded, x: x, y: y, width: c, height: c);
    variants.add(crop);
    // rotații moderate pe crop
    for (final angle in [15, -15, 25, -25]) {
      variants.add(img.copyRotate(crop, angle: angle));
    }
  }

  String? bestId;
  double bestScore = -1;

  void check(List<double> emb) {
    p.embeddings.forEach((id, vecs) {
      for (final ref in vecs) {
        final s = _cosine(emb, ref);
        if (s > bestScore) {
          bestScore = s;
          bestId = id;
        }
      }
    });
  }

  for (final v in variants) {
    final emb = _runEmbedding(interpreter, v, p.inputSize);
    check(emb);
  }

  if (bestId != null && bestScore >= p.threshold) {
    return PosterMatch(bestId!, bestScore);
  }
  return null;
}

double _cosine(List<double> a, List<double> b) {
  final len = math.min(a.length, b.length);
  double dot = 0, na = 0, nb = 0;
  for (var i = 0; i < len; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  final denom = (math.sqrt(na) * math.sqrt(nb));
  if (denom == 0) return -1;
  return dot / denom;
}
