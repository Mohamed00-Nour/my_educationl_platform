import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../entities/parent_report_data.dart';

class PdfReportGeneratorService {
  static Future<Uint8List> generateReportPdf(ParentReportData report) async {
    final pdf = pw.Document();

    final cairoRegular = await PdfGoogleFonts.cairoRegular();
    final cairoBold = await PdfGoogleFonts.cairoBold();

    final primaryColor = PdfColor.fromHex('#1E3A8A');
    final secondaryColor = PdfColor.fromHex('#0D9488');
    final darkText = PdfColor.fromHex('#0F172A');
    final mutedText = PdfColor.fromHex('#64748B');
    final lightBg = PdfColor.fromHex('#F8FAFC');
    final borderCol = PdfColor.fromHex('#E2E8F0');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: cairoRegular, bold: cairoBold),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'أكاديمية البرمجة لطلاب الثانوية',
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'تقرير المتابعة الأكاديمية الدورية لولي الأمر',
                      style: pw.TextStyle(color: mutedText, fontSize: 10),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: lightBg,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: borderCol),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'تقرير مستوى الطالب',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                          color: primaryColor,
                        ),
                      ),
                      pw.Text(
                        'تاريخ التقرير: ${DateTimeUtils.toShortDate(DateTime.now())}',
                        style: pw.TextStyle(fontSize: 8, color: mutedText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Divider(color: borderCol, thickness: 1),
            pw.SizedBox(height: 10),

            // Student Information Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderCol),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'اسم الطالب',
                        style: pw.TextStyle(
                          color: mutedText,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        report.studentName,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'الصف الدراسي',
                        style: pw.TextStyle(
                          color: mutedText,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        report.studentGrade?.toArabicDisplay() ??
                            'المرحلة الثانوية',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'المقرر / المادة',
                        style: pw.TextStyle(
                          color: mutedText,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        report.courseName,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'فترة التقرير',
                        style: pw.TextStyle(
                          color: mutedText,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        report.reportingPeriod,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),

            // Section 1: Attendance
            _buildSectionHeader('١. كشف الحضور والغياب', primaryColor),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _buildMetricBox(
                  'إجمالي الحصص',
                  '${report.totalSessions}',
                  darkText,
                  borderCol,
                ),
                pw.SizedBox(width: 8),
                _buildMetricBox(
                  'حاضر',
                  '${report.presentCount}',
                  PdfColor.fromHex('#16A34A'),
                  borderCol,
                ),
                pw.SizedBox(width: 8),
                _buildMetricBox(
                  'غائب',
                  '${report.absentCount}',
                  PdfColor.fromHex('#DC2626'),
                  borderCol,
                ),
                pw.SizedBox(width: 8),
                _buildMetricBox(
                  'متأخر',
                  '${report.lateCount}',
                  PdfColor.fromHex('#D97706'),
                  borderCol,
                ),
                pw.SizedBox(width: 8),
                _buildMetricBox(
                  'نسبة الالتزام',
                  report.totalSessions == 0
                      ? '—'
                      : '${report.attendancePercentage}%',
                  primaryColor,
                  borderCol,
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // Section 2: Quizzes & Full Exams
            _buildSectionHeader('٢. نتائج الاختبارات والتقييمات', primaryColor),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: borderCol, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightBg),
                  children: [
                    _buildTableCell('عنوان الاختبار', isHeader: true),
                    _buildTableCell('النوع', isHeader: true),
                    _buildTableCell('التاريخ', isHeader: true),
                    _buildTableCell('الدرجة', isHeader: true),
                    _buildTableCell('النسبة', isHeader: true),
                  ],
                ),
                if (report.quizzes.isEmpty && report.exams.isEmpty)
                  pw.TableRow(
                    children: [
                      _buildTableCell('لم يتم تسجيل اختبارات خلال هذه الفترة'),
                      _buildTableCell('-'),
                      _buildTableCell('-'),
                      _buildTableCell('-'),
                      _buildTableCell('-'),
                    ],
                  )
                else ...[
                  ...report.quizzes.map(
                    (q) => pw.TableRow(
                      children: [
                        _buildTableCell(q['name']?.toString() ?? 'اختبار درس'),
                        _buildTableCell('كويز قصير'),
                        _buildTableCell(q['date']?.toString() ?? '-'),
                        _buildTableCell('${q['score']} / ${q['maxScore']}'),
                        _buildTableCell('${q['percentage']}%', isBold: true),
                      ],
                    ),
                  ),
                  ...report.exams.map(
                    (e) => pw.TableRow(
                      children: [
                        _buildTableCell(e['name']?.toString() ?? 'امتحان شامل'),
                        _buildTableCell('امتحان رئيسي', isBold: true),
                        _buildTableCell(e['date']?.toString() ?? '-'),
                        _buildTableCell('${e['score']} / ${e['maxScore']}'),
                        _buildTableCell('${e['percentage']}%', isBold: true),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            pw.SizedBox(height: 18),

            // Section 3: Conduct & Teacher Adjustments
            _buildSectionHeader(
              '٣. نقاط التفاعل والسلوك والمكافآت',
              primaryColor,
            ),
            pw.SizedBox(height: 8),
            if (report.adjustments.isEmpty)
              pw.Text(
                'لا توجد مكافآت أو خصومات مسجلة خلال هذه الفترة.',
                style: pw.TextStyle(color: mutedText, fontSize: 10),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: borderCol, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBg),
                    children: [
                      _buildTableCell('النقاط', isHeader: true),
                      _buildTableCell('السبب / النشاط', isHeader: true),
                      _buildTableCell('التاريخ', isHeader: true),
                    ],
                  ),
                  ...report.adjustments.map((a) {
                    final isBonus =
                        (a['type']?.toString().toLowerCase() ?? '') == 'bonus';
                    final pts = a['points'] ?? 0;
                    return pw.TableRow(
                      children: [
                        _buildTableCell(
                          '${isBonus ? '+' : '-'}$pts نقطة',
                          color:
                              isBonus
                                  ? PdfColor.fromHex('#059669')
                                  : PdfColor.fromHex('#DC2626'),
                          isBold: true,
                        ),
                        _buildTableCell(a['reason']?.toString() ?? ''),
                        _buildTableCell(a['date']?.toString() ?? '-'),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 18),

            // Section 4: Teacher Remarks
            if (report.teacherNotes != null &&
                report.teacherNotes!.isNotEmpty) ...[
              _buildSectionHeader('٤. ملاحظات وتوجيهات المعلم', primaryColor),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderCol),
                ),
                child: pw.Text(
                  report.teacherNotes!,
                  style: pw.TextStyle(color: darkText, fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 18),
            ],

            // Section 5: Overall Summary Box
            _buildSectionHeader(
              'التقييم الشامل والنتيجة المركبة',
              secondaryColor,
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderCol, width: 1),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryCol(
                    'متوسط الكويزات',
                    report.quizzes.isEmpty ? '—' : '${report.quizAverage}%',
                  ),
                  _buildSummaryCol(
                    'متوسط الامتحانات',
                    report.exams.isEmpty ? '—' : '${report.examAverage}%',
                  ),
                  _buildSummaryCol(
                    'نسبة الحضور',
                    report.totalSessions == 0
                        ? '—'
                        : '${report.attendancePercentage}%',
                  ),
                  _buildSummaryCol(
                    'صافي التقييم',
                    '${report.netAdjustments >= 0 ? '+' : ''}${report.netAdjustments} نقطة',
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'المجموع المركب النهائي',
                        style: pw.TextStyle(
                          color: mutedText,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${report.overallEvaluation}%',
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        report.standingRemarks,
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: secondaryColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'يُحسب التقييم من الأقسام المنجزة فقط، وتُعاد موازنة أوزانها. الرمز — يعني أن القسم لم يدخل في التقييم.',
              style: pw.TextStyle(color: mutedText, fontSize: 8),
            ),
            pw.SizedBox(height: 26),

            // Footer Signature
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'اعتماد معلم المادة:',
                      style: pw.TextStyle(color: mutedText, fontSize: 8),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Container(width: 140, height: 1, color: borderCol),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'التوقيع / الختم',
                      style: pw.TextStyle(color: darkText, fontSize: 9),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'توقيع ولي الأمر بالعلم:',
                      style: pw.TextStyle(color: mutedText, fontSize: 8),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Container(width: 140, height: 1, color: borderCol),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'توقيع ولي الأمر',
                      style: pw.TextStyle(color: darkText, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildSectionHeader(String title, PdfColor color) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  static pw.Widget _buildMetricBox(
    String label,
    String value,
    PdfColor textColor,
    PdfColor borderCol,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: borderCol),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight:
              isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.grey800 : PdfColors.grey900),
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryCol(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static Future<void> shareOrPrintReport(ParentReportData report) async {
    final pdfBytes = await generateReportPdf(report);
    final filename = 'Report_${report.studentName.replaceAll(' ', '_')}.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }
}
