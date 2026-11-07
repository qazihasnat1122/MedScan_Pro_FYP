import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// A single OCR text line with its bounding box geometry for visual prominence ranking.
class OcrTextLine {
  final String text;
  final Rect? boundingBox;
  final int blockIndex;
  final int lineIndex;

  const OcrTextLine({
    required this.text,
    this.boundingBox,
    this.blockIndex = 0,
    this.lineIndex = 0,
  });

  double get height => boundingBox?.height ?? 0.0;
  double get width => boundingBox?.width ?? 0.0;
  double get area => height * width;
  double get top => boundingBox?.top ?? 0.0;
}

/// Complete OCR recognition result containing raw text and bounding-box lines.
class OcrRecognitionResult {
  final String rawText;
  final List<OcrTextLine> lines;

  const OcrRecognitionResult({required this.rawText, this.lines = const []});
}

class OcrService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> extractTextFromImage(String imagePath) async {
    final result = await recognizeImage(imagePath);
    return result.rawText;
  }

  Future<OcrRecognitionResult> recognizeImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final extractedLines = <OcrTextLine>[];

    for (var bIdx = 0; bIdx < recognizedText.blocks.length; bIdx++) {
      final block = recognizedText.blocks[bIdx];
      for (var lIdx = 0; lIdx < block.lines.length; lIdx++) {
        final line = block.lines[lIdx];
        final trimmed = line.text.trim();
        if (trimmed.isNotEmpty) {
          extractedLines.add(
            OcrTextLine(
              text: trimmed,
              boundingBox: line.boundingBox,
              blockIndex: bIdx,
              lineIndex: lIdx,
            ),
          );
        }
      }
    }

    return OcrRecognitionResult(
      rawText: recognizedText.text,
      lines: extractedLines,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }
}
