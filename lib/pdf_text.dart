import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// True when [text] has letters the PDF's own font (DejaVu Sans) can't
/// write correctly: Devanagari, Bengali, Arabic, Chinese, Japanese, emoji…
/// Latin, Greek, Cyrillic and Armenian are fine.
bool needsPicture(String text) {
  for (final r in text.runes) {
    if (r < 0x20) continue; // tabs, new lines
    if (r <= 0x058F) continue; // Latin … Cyrillic, Armenian
    if (r >= 0x1E00 && r <= 0x1EFF) continue; // more Latin (Vietnamese…)
    if (r >= 0x2000 && r <= 0x206F) continue; // punctuation
    if (r >= 0x20A0 && r <= 0x20CF) continue; // currency signs
    if (r >= 0x2190 && r <= 0x22FF) continue; // arrows, math
    return true;
  }
  return false;
}

/// Writes text into a PDF. Text the PDF font can write becomes normal PDF
/// text; anything else is drawn by the phone's own text engine and fonts
/// (which know every script) and put in as a sharp picture.
class PdfText {
  PdfText({required this.rtl});

  /// Right-to-left report (Arabic, Urdu).
  final bool rtl;

  /// Pictures are drawn this many times bigger than shown, for print.
  static const double _scale = 3;

  final Map<String, (pw.MemoryImage, double, double)> _pictures = {};

  /// [text] at [size] points. With [maxWidth] (points) long text wraps.
  Future<pw.Widget> text(
    String text, {
    double size = 10,
    bool bold = false,
    PdfColor color = PdfColors.black,
    double? maxWidth,
    bool alignEnd = false,
  }) async {
    final textAlign = alignEnd != rtl ? pw.TextAlign.right : pw.TextAlign.left;
    if (!needsPicture(text)) {
      return pw.Text(
        text,
        textAlign: textAlign,
        // Numbers and Latin names read left to right, also in Arabic.
        textDirection: pw.TextDirection.ltr,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      );
    }
    final (image, width, height) =
        await _picture(text, size, bold, color, maxWidth);
    return pw.Container(
      alignment: alignEnd != rtl
          ? pw.Alignment.centerRight
          : pw.Alignment.centerLeft,
      child: pw.Image(image, width: width, height: height),
    );
  }

  Future<(pw.MemoryImage, double, double)> _picture(String text, double size,
      bool bold, PdfColor color, double? maxWidth) async {
    final key = '$size|$bold|${color.toInt()}|$maxWidth|$text';
    final cached = _pictures[key];
    if (cached != null) return cached;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size * _scale,
          height: 1.25,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: Color(color.toInt()),
        ),
      ),
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      textWidthBasis: TextWidthBasis.longestLine,
    )..layout(maxWidth: maxWidth == null ? double.infinity : maxWidth * _scale);
    final w = painter.width.ceil().clamp(1, 8000).toInt();
    final h = painter.height.ceil().clamp(1, 8000).toInt();
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    painter.dispose();
    final bytes = data == null ? Uint8List(0) : data.buffer.asUint8List();
    final result = (pw.MemoryImage(bytes), w / _scale, h / _scale);
    _pictures[key] = result;
    return result;
  }
}
