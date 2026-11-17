import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'store.dart';

pw.Widget _sec(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(t, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.Divider(thickness: .5),
    ]));

pw.Widget _row(String a, String? b, String c, {bool bold = false}) {
  final st = pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
  return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(children: [
        pw.Expanded(flex: 5, child: pw.Text(a, style: st)),
        pw.Expanded(flex: 3, child: pw.Text(b ?? '', style: st)),
        pw.Expanded(flex: 3, child: pw.Text(c, style: st, textAlign: pw.TextAlign.right)),
      ]));
}

pw.Widget _txt(String s) => pw.Text(s, style: const pw.TextStyle(fontSize: 10));
String _cut(String s, int n) => s.length > n ? s.substring(0, n) : s;

pw.Document _doc(List<pw.Widget> body) {
  final d = pw.Document();
  d.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    build: (_) => body,
    footer: (c) => pw.Center(
        child: pw.Text('Catatan Kas - Halaman ${c.pageNumber} dari ${c.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
  ));
  return d;
}

List<pw.Widget> _debts(Store s) {
  final od = s.debt.where((x) => x.sisa > 0).toList();
  return [
    _sec('Utang dan piutang berjalan'),
    if (od.isEmpty) _txt('Tidak ada.'),
    for (final x in od)
      _row('${_cut(x.who, 30)} (${x.kind == 'utang' ? 'utang' : 'piutang'})',
          x.due.isEmpty ? '' : 'Jatuh tempo ${tgl(x.due)}', rp(x.sisa)),
  ];
}

pw.Document invoice(Store s) {
  final m = s.month;
  final I = s.sum(s.inMonth(s.income)), E = s.sum(s.inMonth(s.expense));
  List<pw.Widget> part(String t, String title) {
    final a = s.inMonth(s.list(t))..sort((x, y) => x.date.compareTo(y.date));
    return [
      _sec(title),
      if (a.isEmpty) _txt('Tidak ada transaksi.'),
      for (final x in a) _row('${tgl(x.date)}  ${_cut(x.name, 34)}', _cut(x.cat, 22), rp(x.amount)),
      pw.SizedBox(height: 4),
      _row('Subtotal', null, rp(s.sum(a)), bold: true),
    ];
  }

  return _doc([
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('INVOICE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.Text('No. INV-${m.replaceAll('-', '')}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    ]),
    pw.SizedBox(height: 6),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      _txt('Catatan Kas - Rincian transaksi bulanan'),
      _txt('Diterbitkan ${tgl(s.today)}'),
    ]),
    pw.SizedBox(height: 4),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      _txt('Atas nama: ${s.name.isEmpty ? '-' : s.name}'),
      _txt('Periode: ${moL(m)}'),
    ]),
    ...part('income', 'Rincian pendapatan'),
    ...part('expense', 'Rincian pengeluaran'),
    _sec('Ringkasan'),
    _row('Total pendapatan', null, rp(I)),
    _row('Total pengeluaran', null, rp(E)),
    _row('Saldo bulan ini', null, rp(I - E), bold: true),
    ..._debts(s),
  ]);
}

pw.Document report(Store s) {
  final m = s.month;
  final ii = s.inMonth(s.income), ee = s.inMonth(s.expense);
  final I = s.sum(ii), E = s.sum(ee);
  final y = int.parse(m.substring(0, 4)), mm = int.parse(m.substring(5));
  final nd = m == s.today.substring(0, 7) ? int.parse(s.today.substring(8)) : DateTime(y, mm + 1, 0).day;
  final pk = ymd(DateTime(y, mm - 1, 1)).substring(0, 7);
  final PE = s.sum(s.inMonth(s.expense, pk));

  List<pw.Widget> br(String title, List<Entry> a, double tot) {
    final k = s.byCat(a);
    return [
      _sec(title),
      if (k.isEmpty) _txt('Tidak ada data.'),
      for (final e in k) _row(_cut(e.key, 28), '${(e.value / tot * 100).toStringAsFixed(0)}%', rp(e.value)),
    ];
  }

  return _doc([
    pw.Text('LAPORAN KEUANGAN BULANAN', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 4),
    _txt('${moL(m)}   |   Atas nama: ${s.name.isEmpty ? '-' : s.name}'),
    _sec('Ringkasan'),
    _row('Total pendapatan', null, rp(I)),
    _row('Total pengeluaran', null, rp(E)),
    _row('Saldo bulan ini', null, rp(I - E), bold: true),
    _row('Tingkat tabungan', null, I > 0 ? '${((I - E) / I * 100).toStringAsFixed(0)}%' : '-'),
    _row('Rata-rata pengeluaran per hari', null, rp(E / nd)),
    _row('Jumlah transaksi', null, '${ii.length + ee.length}'),
    _row('Perubahan pengeluaran vs bulan lalu', null, PE > 0 ? '${((E - PE) / PE * 100).toStringAsFixed(0)}%' : '-'),
    ...br('Pendapatan per sumber', ii, I),
    ...br('Pengeluaran per kategori', ee, E),
    _sec('Tren 6 bulan terakhir'),
    for (var i = 5; i >= 0; i--)
      () {
        final k = ymd(DateTime(y, mm - i, 1)).substring(0, 7);
        return _row(moL(k), 'Masuk ${rp(s.sum(s.inMonth(s.income, k)))}', 'Keluar ${rp(s.sum(s.inMonth(s.expense, k)))}');
      }(),
    _sec('Aset'),
    if (s.asset.isEmpty) _txt('Belum ada aset.'),
    for (final x in s.asset) _row(_cut(x.name, 34), _cut(x.cat, 22), rp(x.amount)),
    _row('Total aset', null, rp(s.sum(s.asset)), bold: true),
    ..._debts(s),
  ]);
}

Future<void> sharePdf(Store s, bool inv) async {
  final bytes = await (inv ? invoice(s) : report(s)).save();
  await Printing.sharePdf(bytes: bytes, filename: '${inv ? 'invoice' : 'laporan'}-${s.month}.pdf');
}
