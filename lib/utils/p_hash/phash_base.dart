import 'dart:math';
import 'package:image/image.dart';

class Pixel {
  Pixel(this._red, this._green, this._blue, this._alpha);
  final int _red;
  final int _green;
  final int _blue;
  final int _alpha;

  @override
  String toString() {
    return 'red: $_red, green: $_green, blue: $_blue, alpha: $_alpha';
  }
}

class PHash {
  static const int _size = 32;

  static BigInt calculate(Image image) {
    image = copyResize(image, width: 32, height: 32);
    final List<Pixel> pixelList = [];
    const bytesPerPixel = 4;
    final bytes = image.getBytes();
    for (var i = 0; i <= bytes.length - bytesPerPixel; i += bytesPerPixel) {
      pixelList.add(Pixel(bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3]));
    }
    return calcPhash(pixelList);
  }

  ///Helper function to convert a Unit8List to a nD matrix
  static List<List<Pixel>> unit8ListToMatrix(List<Pixel> pixelList) {
    final copy = pixelList.sublist(0);
    // pixelList.clear();
    final pixelListDest = <List<Pixel>>[];

    for (int r = 0; r < _size; r++) {
      final res = <Pixel>[];
      for (var c = 0; c < _size; c++) {
        var i = r * _size + c;

        if (i < copy.length) {
          res.add(copy[i]);
        }
      }

      pixelListDest.add(res);
    }

    return pixelListDest;
  }

  /// Helper function which computes a binary hash of a [List] of [Pixel]
  static BigInt calcPhash(List<Pixel> pixelList) {
    String bitString = '';
    final matrix = List<List<num>>.filled(32, []);
    final row = List<num>.filled(32, 0);
    final rows = List<List<num>>.filled(32, []);
    final col = List<num>.filled(32, 0);

    final data = unit8ListToMatrix(pixelList); //returns a matrix used for DCT

    for (int y = 0; y < _size; y++) {
      for (int x = 0; x < _size; x++) {
        final color = data[x][y];

        row[x] = getLuminanceRgb(color._red, color._green, color._blue);
      }

      rows[y] = calculateDCT(row);
    }
    for (int x = 0; x < _size; x++) {
      for (int y = 0; y < _size; y++) {
        col[y] = rows[y][x];
      }

      matrix[x] = calculateDCT(col);
    }

    // Extract the top 8x8 pixels.
    var pixels = <num>[];

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        pixels.add(matrix[y][x]);
      }
    }

    // Calculate hash.
    final bits = <num>[];
    final compare = average(pixels);

    for (final pixel in pixels) {
      bits.add(pixel > compare ? 1 : 0);
    }

    bits.forEach((element) {
      bitString += (1 * element).toString();
    });

    return BigInt.parse(bitString, radix: 2);
  }

  ///Helper function to perform 1D discrete cosine tranformation on a matrix
  static List<num> calculateDCT(List<num> matrix) {
    final transformed = List<num>.filled(32, 0);
    final _size = matrix.length;

    for (int i = 0; i < _size; i++) {
      num sum = 0;

      for (int j = 0; j < _size; j++) {
        sum += matrix[j] * cos((i * pi * (j + 0.5)) / _size);
      }

      sum *= sqrt(2 / _size);

      if (i == 0) {
        sum *= 1 / sqrt(2);
      }

      transformed[i] = sum;
    }

    return transformed;
  }

  ///Helper funciton to compute the average of an array after dct caclulations
  static num average(List<num> pixels) {
    // Calculate the average value from top 8x8 pixels, except for the first one.
    final n = pixels.length - 1;
    return pixels.sublist(1, n).reduce((a, b) => a + b) / n;
  }

  static int hammingDistance(BigInt x, BigInt y) {
    BigInt s = x ^ y;
    int ret = 0;
    while (s != BigInt.zero) {
      s &= s - BigInt.one;
      ret++;
    }
    return ret;
  }
}
