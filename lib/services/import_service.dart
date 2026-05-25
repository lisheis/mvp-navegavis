import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import '../data/models/building.dart';

/// Result of any import operation.
class ImportResult {
  final bool success;
  final String? error;
  final Building? building;       // set when JSON building was imported
  final String? savedImagePath;   // set when PDF floor plan was rendered

  const ImportResult._({
    required this.success,
    this.error,
    this.building,
    this.savedImagePath,
  });

  factory ImportResult.ok({Building? building, String? savedImagePath}) =>
      ImportResult._(success: true, building: building, savedImagePath: savedImagePath);

  factory ImportResult.fail(String error) =>
      ImportResult._(success: false, error: error);
}

class ImportService {
  // ── JSON building import ─────────────────────────────────────────────────

  /// Opens file picker, reads a JSON file and parses it as a [Building].
  Future<ImportResult> importBuildingJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return ImportResult.fail('Nenhum arquivo selecionado.');
      }

      final bytes = result.files.first.bytes;
      if (bytes == null) return ImportResult.fail('Não foi possível ler o arquivo.');

      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final building = Building.fromJson(json);
      return ImportResult.ok(building: building);
    } catch (e) {
      return ImportResult.fail('Erro ao importar JSON: $e');
    }
  }

  // ── PDF floor plan import ────────────────────────────────────────────────

  /// Opens file picker, renders the first page of a PDF to PNG bytes
  /// and saves to the app documents directory.
  /// Returns [ImportResult.savedImagePath] with the local file path.
  Future<ImportResult> importFloorPlanPdf({
    required String buildingId,
    required int floor,
    int renderWidth = 1200,
  }) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: false, // use path, not bytes, for large files
      );
      if (picked == null || picked.files.isEmpty) {
        return ImportResult.fail('Nenhum arquivo selecionado.');
      }

      final path = picked.files.first.path;
      if (path == null) return ImportResult.fail('Caminho do arquivo inválido.');

      // Render PDF page 1 → image bytes
      final document = await PdfDocument.openFile(path);
      final page = await document.getPage(1);

      final aspectRatio = page.height / page.width;
      final renderHeight = (renderWidth * aspectRatio).round();

      final pageImage = await page.render(
        width: renderWidth.toDouble(),
        height: renderHeight.toDouble(),
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );

      await page.close();
      await document.close();

      if (pageImage == null) {
        return ImportResult.fail('Não foi possível renderizar o PDF.');
      }

      // Save to documents directory
      final dir = await getApplicationDocumentsDirectory();
      final savePath =
          '${dir.path}/floorplan_${buildingId}_floor$floor.png';
      await File(savePath).writeAsBytes(pageImage.bytes);

      return ImportResult.ok(savedImagePath: savePath);
    } catch (e) {
      return ImportResult.fail('Erro ao importar PDF: $e');
    }
  }

  // ── Export building as JSON ──────────────────────────────────────────────

  Future<String?> exportBuildingJson(Building building) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/${building.id}.json';
      await File(path).writeAsString(jsonEncode(building.toJson()), flush: true);
      return path;
    } catch (_) {
      return null;
    }
  }
}
