import 'dart:io';
import 'package:archive/archive.dart';

void extractZip(String zipFilePath, String outputDir) async {
  // Baca fail ZIP
  final bytes = File(zipFilePath).readAsBytesSync();

  // Dekompres fail ZIP
  final archive = ZipDecoder().decodeBytes(bytes);

  // Pastikan output directory wujud
  final outputDirPath = Directory(outputDir);
  if (!outputDirPath.existsSync()) {
    outputDirPath.createSync(recursive: true);
  }

  // Menyimpan fail yang diekstrak
  for (var file in archive) {
    final filename = '$outputDir/${file.name}';
    if (file.isFile) {
      File(filename)
        ..createSync(recursive: true)
        ..writeAsBytesSync(file.content as List<int>);
    }
  }

  print('Extraction selesai di $outputDir');
}

void main() {
  // Gantikan dengan laluan fail ZIP dan direktori output yang anda mahu
  String zipFilePath = 'path/to/your/file.zip'; // Gantikan dengan laluan ZIP anda
  String outputDir = 'path/to/output/folder';  // Gantikan dengan laluan output

  extractZip(zipFilePath, outputDir);
}
