// The itinerary document (itinerary_doc.dart) as an A4 PDF. Fonts are
// bundled (assets/fonts): Roboto for text, a small DejaVu subset as fallback
// for arrows and symbols Roboto lacks ("Colombo → Kandy").
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/style.dart';
import 'itinerary_doc.dart';

class PdfFonts {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font symbols;
  const PdfFonts(this.regular, this.bold, this.symbols);

  static PdfFonts? _cached;

  /// Loads the bundled fonts once.
  static Future<PdfFonts> load() async {
    if (_cached != null) return _cached!;
    Future<pw.Font> font(String name) async => pw.Font.ttf(await rootBundle.load('assets/fonts/$name'));
    return _cached = PdfFonts(
      await font('Roboto-Regular.ttf'),
      await font('Roboto-Bold.ttf'),
      await font('DejaVuSans-Symbols.ttf'),
    );
  }
}

/// Lines under an entry start where its title starts. The padding keeps
/// MultiPage from splitting a text across pages, so a long paragraph (a
/// pasted booking mail) is cut into pieces that each fit on a page.
List<pw.Widget> _indented(String text, pw.TextStyle style) => [
      for (final piece in pdfChunks(text))
        pw.Padding(padding: const pw.EdgeInsets.only(left: 101), child: pw.Text(piece, style: style)),
    ];

/// [text] in pieces of at most [max] characters, cut at spaces where
/// possible.
List<String> pdfChunks(String text, {int max = 500}) {
  final out = <String>[];
  var rest = text;
  while (rest.length > max) {
    var cut = rest.lastIndexOf(' ', max);
    if (cut <= 0) cut = max;
    out.add(rest.substring(0, cut).trimRight());
    rest = rest.substring(cut).trimLeft();
  }
  out.add(rest);
  return out;
}

PdfColor _kindColor(ItemKind k) => PdfColor.fromInt(kindColor(k).toARGB32());

/// Renders [doc] as PDF bytes.
Future<Uint8List> itineraryPdf(ItineraryDoc doc, AppLocalizations l, PdfFonts fonts) {
  final theme = pw.ThemeData.withFont(
    base: fonts.regular,
    bold: fonts.bold,
    italic: fonts.regular,
    boldItalic: fonts.bold,
    fontFallback: [fonts.symbols],
  );
  const grey = PdfColors.grey700;
  final pdf = pw.Document(title: doc.title, creator: 'Tripboard', theme: theme);

  pw.Widget heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(text.toUpperCase(),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: grey, letterSpacing: 1)),
      );

  // Every line is its own widget, so MultiPage can break a long day (or a
  // long note) across pages.
  List<pw.Widget> entry(DocEntry e) => [
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(
              width: 3,
              height: 12,
              margin: const pw.EdgeInsets.only(top: 1, right: 6),
              color: _kindColor(e.kind),
            ),
            pw.SizedBox(width: 92, child: pw.Text(e.time, style: const pw.TextStyle(fontSize: 10))),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: e.title, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                  if (e.tag != null)
                    pw.TextSpan(text: '  ${e.tag}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.green800)),
                ]),
              ),
            ),
          ]),
        ),
        for (final d in e.details) ..._indented(d, const pw.TextStyle(fontSize: 9.5)),
        for (final n in e.notes) ..._indented(n, const pw.TextStyle(fontSize: 9, color: grey)),
      ];

  List<pw.Widget> day(DocDay d) => [
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 10),
          padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: d.heading, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              if (d.places.isNotEmpty)
                pw.TextSpan(text: '   ${d.places}', style: const pw.TextStyle(fontSize: 11, color: grey)),
            ]),
          ),
        ),
        for (final e in d.entries) ...entry(e),
        for (final r in d.remarks)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 9, top: 3),
            child: pw.Text(r, style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic, color: grey)),
          ),
      ];

  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 36),
    footer: (c) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(doc.footer, style: const pw.TextStyle(fontSize: 8, color: grey)),
      pw.Text(l.sharePdfPage('${c.pageNumber}', '${c.pagesCount}'), style: const pw.TextStyle(fontSize: 8, color: grey)),
    ]),
    build: (c) => [
      pw.Text(doc.title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text(doc.subtitle, style: const pw.TextStyle(fontSize: 11, color: grey)),
      if (doc.dateHint != null) pw.Text(doc.dateHint!, style: const pw.TextStyle(fontSize: 9, color: grey)),
      if (doc.route.isNotEmpty) ...[
        heading(l.shareRoute),
        for (final r in doc.route) pw.Bullet(text: r, style: const pw.TextStyle(fontSize: 10)),
      ],
      heading(l.shareDayByDay),
      for (final d in doc.days) ...day(d),
      if (doc.notes.isNotEmpty) ...[
        heading(l.notesLabel),
        for (final n in doc.notes) ...[
          if (n.title.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(n.title, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
            ),
          for (final x in n.lines) pw.Text(x, style: const pw.TextStyle(fontSize: 9.5)),
        ],
      ],
    ],
  ));
  return pdf.save();
}
