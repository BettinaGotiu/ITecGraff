import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

class PosterRecognizer {
  final Map<String, Uint8List> _assetBytes = {};
  final Map<String, int> _assetHashes = {};
  final int hashSize; // dimensiune hash (implicit 8 -> 64 bits)

  PosterRecognizer({this.hashSize = 8});

  /// Încarcă și pregătește hash-urile pentru afis1..afis10.
  Future<void> preload() async {
    for (int i = 1; i <= 10; i++) {
      final name = 'afis$i';
      final bytes = await rootBundle.load('assets/posters/$name.png');
      final data = bytes.buffer.asUint8List();
      _assetBytes[name] = data;
      _assetHashes[name] = _computeAHash(data);
    }
  }

  /// Calculează hash pentru o poză (PNG/JPEG) și întoarce cea mai bună potrivire.
  Future<PosterMatch?> match(Uint8List photoBytes, {int threshold = 10}) async {
    final photoHash = _computeAHash(photoBytes);
    String? bestId;
    int bestDist = 1 << 30;

    _assetHashes.forEach((id, h) {
      final d = _hamming(photoHash, h);
      if (d < bestDist) {
        bestDist = d;
        bestId = id;
      }
    });

    if (bestId != null && bestDist <= threshold) {
      // extrage numărul din afisX
      final canvasNumber = bestId!.replaceAll(RegExp(r'[^0-9]'), '');
      return PosterMatch(
        posterId: bestId!,
        canvasLabel: 'you are joining canvas $canvasNumber',
        distance: bestDist,
      );
    }
    return null;
  }

  int _computeAHash(Uint8List bytes) {
    // decode
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) return 0;
    // resize la hashSize x hashSize, gray
    final resized = img.copyResize(image, width: hashSize, height: hashSize);
    final gray = img.grayscale(resized);
    // medie
    int sum = 0;
    for (final p in gray) {
      sum += img.getLuminance(p).toInt();
    }
    final avg = sum / (hashSize * hashSize);
    // bitmask
    int hash = 0;
    for (final p in gray) {
      hash = (hash << 1) | (img.getLuminance(p) > avg ? 1 : 0);
    }
    return hash;
  }

  int _hamming(int a, int b) =>
      (a ^ b).toRadixString(2).replaceAll('0', '').length;
}

class PosterMatch {
  final String posterId;
  final String canvasLabel;
  final int distance;
  PosterMatch({
    required this.posterId,
    required this.canvasLabel,
    required this.distance,
  });
}
