import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/recipe.dart';

/// Builds a clean, printable PDF of a recipe. Callers can either open the print
/// dialog (to save to the device) or share it as a file.
class PdfService {
  static const _tomato = PdfColor.fromInt(0xFFF04E37);
  static const _forest = PdfColor.fromInt(0xFF1E3A31);
  static const _ink = PdfColor.fromInt(0xFF1E1F1A);
  static const _tint = PdfColor.fromInt(0xFFF3F1EB);

  /// Opens the system print dialog where the user can pick "Save as PDF".
  static Future<void> printOrSave(Recipe recipe) async {
    await Printing.layoutPdf(
      name: _safeName(recipe.title),
      onLayout: (_) => _build(recipe),
    );
  }

  /// Opens the share sheet to send the PDF as a file to another app.
  static Future<void> share(Recipe recipe) async {
    final bytes = await _build(recipe);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${_safeName(recipe.title)}.pdf',
    );
  }

  static Future<Uint8List> _build(Recipe recipe) async {
    final doc = pw.Document();

    pw.ImageProvider? image;
    try {
      if (recipe.imageUrl.startsWith('http')) {
        image = await networkImage(recipe.imageUrl);
      } else if (recipe.imageUrl.startsWith('/') ||
          recipe.imageUrl.contains(':\\')) {
        image = pw.MemoryImage(await File(recipe.imageUrl).readAsBytes());
      }
    } catch (_) {
      image = null; // Fall back to a text-only PDF if the image can't load.
    }

    final total = recipe.prepTime + recipe.cookTime;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Sizzle Recipes · ${_today()} · Page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text(recipe.category.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 11,
                  color: _tomato,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2)),
          pw.SizedBox(height: 6),
          pw.Text(recipe.title,
              style: pw.TextStyle(
                  fontSize: 30, fontWeight: pw.FontWeight.bold, color: _ink)),
          if (recipe.authorName != null) ...[
            pw.SizedBox(height: 6),
            pw.Text('Made by ${recipe.authorName}',
                style:
                    const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          ],
          pw.SizedBox(height: 18),
          if (image != null)
            pw.Container(
              height: 240,
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(12),
                image: pw.DecorationImage(image: image, fit: pw.BoxFit.cover),
              ),
            ),
          pw.SizedBox(height: 20),
          pw.Row(
            children: [
              _statBox('Prep', '${recipe.prepTime} min'),
              pw.SizedBox(width: 10),
              _statBox('Cook', '${recipe.cookTime} min'),
              pw.SizedBox(width: 10),
              _statBox('Total', '$total min'),
              pw.SizedBox(width: 10),
              _statBox('Serves', '${recipe.feeds}'),
            ],
          ),
          pw.SizedBox(height: 24),
          _heading('About this recipe'),
          pw.SizedBox(height: 8),
          pw.Text(recipe.description,
              style: const pw.TextStyle(
                  fontSize: 12, color: _ink, lineSpacing: 4)),
          if (recipe.ingredients.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            _heading('Ingredients'),
            pw.SizedBox(height: 10),
            ...recipe.ingredients.map(_bullet),
          ],
          if (recipe.steps.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            _heading('Method'),
            pw.SizedBox(height: 10),
            for (int i = 0; i < recipe.steps.length; i++)
              _step(i + 1, recipe.steps[i]),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _heading(String text) => pw.Text(text,
      style: pw.TextStyle(
          fontSize: 16, fontWeight: pw.FontWeight.bold, color: _forest));

  static pw.Widget _statBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: _tint,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold, color: _ink)),
            pw.SizedBox(height: 2),
            pw.Text(label,
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _bullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 5,
            height: 5,
            margin: const pw.EdgeInsets.only(top: 5, right: 8),
            decoration: const pw.BoxDecoration(
                color: _tomato, shape: pw.BoxShape.circle),
          ),
          pw.Expanded(
            child: pw.Text(text,
                style: const pw.TextStyle(fontSize: 12, color: _ink)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _step(int number, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 20,
            height: 20,
            margin: const pw.EdgeInsets.only(right: 10),
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _tomato,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text('$number',
                style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(text,
                style: const pw.TextStyle(
                    fontSize: 12, color: _ink, lineSpacing: 3)),
          ),
        ],
      ),
    );
  }

  static String _today() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  static String _safeName(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '')
        .trim()
        .replaceAll(' ', '_');
    return cleaned.isEmpty ? 'recipe' : cleaned;
  }
}
