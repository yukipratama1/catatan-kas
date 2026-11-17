import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';
import 'ui.dart';
import 'pdf_export.dart';

Future<String?> pickDate(BuildContext c, String init) async {
  final d = await showDatePicker(
    context: c,
    initialDate: init.isEmpty ? DateTime.now() : pd(init),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  return d == null ? null : ymd(d);
}

class DateField extends StatelessWidget {
  final String label, value;
  final ValueChanged<String> onChanged;
  final bool clearable;
  const DateField(this.label, this.value, this.onChanged, {super.key, this.clearable = false});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final v = await pickDate(context, value);
          if (v != null) onChanged(v);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: clearable && value.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => onChanged(''))
                : const Icon(Icons.calendar_today, size: 18),
          ),
          child: Text(value.isEmpty ? '-' : tgl(value)),
        ),
      );
}

// ───────────────────────── Ringkasan ─────────────────────────
class SummaryTab extends StatelessWidget {
  final Store s;
  const SummaryTab(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final inc = s.sum(s.inMonth(s.income)), out = s.sum(s.inMonth(s.expense));
    final ast = s.sum(s.asset);
    double utang = 0, piut = 0;
    for (final d in s.debt) {
      if (d.kind == 'utang') {
        utang += d.sisa;
      } else {
        piut += d.sisa;
      }
    }
    final plus = ast + piut, net = plus - utang, tot = (plus + utang) == 0 ? 1.0 : plus + utang;
    final by = s.byCat(s.inMonth(s.expense));
    final mx = by.isEmpty ? 1.0 : by.first.value;
    final soon = (s.debt.where((d) => d.sisa > 0 && d.due.isNotEmpty).toList()
          ..sort((a, b) => a.due.compareTo(b.due)))
        .take(3)
        .toList();
    const g1 = Color(0xFF6FD6AE), g2 = Color(0xFFF28BA5);
    int fl(double v) => math.max(1, (v / tot * 1000).round());

    return Column(children: [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Kekayaan bersih (aset + piutang - utang)', style: TextStyle(color: p.bg.withOpacity(.75))),
          const SizedBox(height: 4),
          Text(rp(net), style: TextStyle(color: p.bg, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 10,
              color: p.bg.withOpacity(.18),
              child: Row(children: [
                if (plus > 0) Expanded(flex: fl(plus), child: Container(color: g1)),
                if (utang > 0) Expanded(flex: fl(utang), child: Container(color: g2)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 16, runSpacing: 4, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Dot(g1),
              Text('Aset & piutang ${rp(plus)}', style: TextStyle(color: p.bg, fontWeight: FontWeight.w600)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Dot(g2),
              Text('Utang ${rp(utang)}', style: TextStyle(color: p.bg, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ]),
      ),
      Cols([
        Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Mute('Pendapatan bulan ini'), Big(rp(inc), c: p.inc)])),
        Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Mute('Pengeluaran bulan ini'), Big(rp(out), c: p.out)])),
        Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Mute('Sisa bulan ini'), Big(rp(inc - out))])),
      ]),
      Cols(minW: 300, [
        Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Pengeluaran per kategori'),
          if (by.isEmpty) const Empty('Belum ada pengeluaran bulan ini.'),
          for (final e in by) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text(e.key)),
              Text(rp(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            Bar(e.value / mx, p.out),
          ],
        ])),
        Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('Jatuh tempo terdekat'),
          if (soon.isEmpty) const Empty('Tidak ada utang atau piutang berjalan.'),
          if (soon.isNotEmpty)
            Rows([
              for (final d in soon)
                Item(d.who,
                    '${d.due.compareTo(s.today) < 0 ? 'Lewat · ' : ''}${tgl(d.due)} · ${d.kind == 'utang' ? 'bayar' : 'tagih'}',
                    rp(d.sisa),
                    subColor: d.due.compareTo(s.today) < 0 ? p.out : null),
            ]),
        ])),
      ]),
    ]);
  }
}

// ───────────────────── Form input (pendapatan/pengeluaran/aset/utang) ─────────────────────
class FormCard extends StatefulWidget {
  final Store s;
  final String t;
  const FormCard(this.s, this.t, {super.key});
  @override
  State<FormCard> createState() => _FormCardState();
}

class _FormCardState extends State<FormCard> {
  final key = GlobalKey<FormState>();
  final name = TextEditingController(), cat = TextEditingController(), amt = TextEditingController();
  late String date = widget.s.formDate;
  String due = '', kind = 'utang';

  @override
  void dispose() {
    name.dispose();
    cat.dispose();
    amt.dispose();
    super.dispose();
  }

  String? req(String? v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;
  String? amtV(String? v) => (v == null || (double.tryParse(v) ?? 0) <= 0) ? 'Isi jumlah > 0' : null;

  void submit() {
    if (!key.currentState!.validate()) return;
    final s = widget.s, t = widget.t;
    final id = DateTime.now().millisecondsSinceEpoch;
    final a = double.parse(amt.text);
    if (t == 'debt') {
      s.commit(() => s.debt.add(Debt(id: id, kind: kind, who: name.text.trim(), amount: a, due: due)));
    } else {
      s.commit(() => s.list(t).add(Entry(
          id: id, name: name.text.trim(), cat: cat.text.trim(), amount: a, date: t == 'asset' ? '' : date)));
    }
    key.currentState!.reset();
    setState(() => due = '');
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t, asset = t == 'asset';
    final label = {'income': 'Sumber pendapatan', 'expense': 'Kategori', 'asset': 'Jenis aset'}[t];
    final hint = {'income': 'Mis. Gaji bulanan', 'expense': 'Mis. Makan', 'asset': 'Mis. Emas'}[t];
    final btn = {'income': 'Simpan pendapatan', 'expense': 'Simpan pengeluaran', 'asset': 'Simpan aset', 'debt': 'Simpan utang'}[t]!;
    const gap = SizedBox(height: 12);
    return Box(
      child: Form(
        key: key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (t == 'debt') ...[
            DropdownButtonFormField<String>(
              value: kind,
              decoration: const InputDecoration(labelText: 'Jenis'),
              items: const [
                DropdownMenuItem(value: 'utang', child: Text('Saya berutang')),
                DropdownMenuItem(value: 'piutang', child: Text('Orang berutang ke saya')),
              ],
              onChanged: (v) => setState(() => kind = v ?? 'utang'),
            ),
            gap,
            TextFormField(controller: name, validator: req, decoration: const InputDecoration(labelText: 'Nama pihak', hintText: 'Mis. Budi')),
            gap,
            TextFormField(
                controller: amt, validator: amtV, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Jumlah (Rp)')),
            gap,
            DateField('Jatuh tempo (opsional)', due, (v) => setState(() => due = v), clearable: true),
          ] else ...[
            if (!asset) ...[DateField('Tanggal', date, (v) => setState(() => date = v)), gap],
            TextFormField(
                controller: name, validator: req,
                decoration: InputDecoration(
                    labelText: asset ? 'Nama aset' : 'Keterangan',
                    hintText: asset ? 'Mis. Emas 10 gram' : 'Mis. Makan siang')),
            gap,
            TextFormField(
                controller: cat, validator: req,
                decoration: InputDecoration(labelText: '$label (ketik baru untuk menambah)', hintText: hint)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              for (final c in widget.s.cats(t))
                ActionChip(label: Text(c), visualDensity: VisualDensity.compact, onPressed: () => cat.text = c),
            ]),
            gap,
            TextFormField(
                controller: amt, validator: amtV, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: asset ? 'Nilai (Rp)' : 'Jumlah (Rp)')),
          ],
          gap,
          FilledButton(onPressed: submit, child: Text(btn)),
        ]),
      ),
    );
  }
}

// ───────────────────── Riwayat ─────────────────────
class ListTab extends StatelessWidget {
  final Store s;
  final String t;
  const ListTab(this.s, this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final arr = (t == 'asset' ? s.asset : s.inMonth(s.list(t))).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final color = {'income': p.inc, 'expense': p.out, 'asset': p.asset}[t]!;
    final empty = {
      'income': 'Belum ada pendapatan bulan ini. Catat gaji atau pemasukan lain di atas.',
      'expense': 'Belum ada pengeluaran bulan ini.',
      'asset': 'Belum ada aset. Tambahkan tabungan, emas, atau lainnya.',
    }[t]!;
    return Column(children: [
      FormCard(s, t),
      Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('Riwayat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Big('${t == 'asset' ? 'Total aset' : 'Total bulan ini'}: ${rp(s.sum(arr))}', c: color, size: 17),
        ]),
        const SizedBox(height: 8),
        if (arr.isEmpty) Empty(empty),
        if (arr.isNotEmpty)
          Rows([
            for (final x in arr)
              Item(x.name, '${x.cat}${x.date.isEmpty ? '' : ' · ${tgl(x.date)}'}', rp(x.amount),
                  amountColor: color, onDelete: () => s.commit(() => s.list(t).removeWhere((e) => e.id == x.id))),
          ]),
      ])),
    ]);
  }
}

// ───────────────────── Utang ─────────────────────
class DebtTab extends StatelessWidget {
  final Store s;
  const DebtTab(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final arr = s.debt.toList()
      ..sort((a, b) {
        final c = (a.sisa <= 0 ? 1 : 0) - (b.sisa <= 0 ? 1 : 0);
        if (c != 0) return c;
        return (a.due.isEmpty ? '9' : a.due).compareTo(b.due.isEmpty ? '9' : b.due);
      });
    return Column(children: [
      FormCard(s, 'debt'),
      Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Daftar utang & piutang'),
        if (arr.isEmpty) const Empty('Belum ada catatan utang.'),
        if (arr.isNotEmpty) Rows([for (final d in arr) DebtTile(s, d, key: ValueKey(d.id))]),
      ])),
    ]);
  }
}

class DebtTile extends StatefulWidget {
  final Store s;
  final Debt d;
  const DebtTile(this.s, this.d, {super.key});
  @override
  State<DebtTile> createState() => _DebtTileState();
}

class _DebtTileState extends State<DebtTile> {
  final c = TextEditingController();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context), s = widget.s, d = widget.d;
    final done = d.sisa <= 0, late = !done && d.due.isNotEmpty && d.due.compareTo(s.today) < 0;
    final col = d.kind == 'utang' ? p.debt : p.asset;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(d.who, style: const TextStyle(fontWeight: FontWeight.w600)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(border: Border.all(color: col), borderRadius: BorderRadius.circular(99)),
            child: Text(d.kind == 'utang' ? 'Saya berutang' : 'Piutang',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: col)),
          ),
        ])),
        Text(done ? 'Lunas' : rp(d.sisa), style: const TextStyle(fontWeight: FontWeight.w600)),
        IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => s.commit(() => s.debt.removeWhere((e) => e.id == d.id)),
            icon: Icon(Icons.close, size: 18, color: p.mute)),
      ]),
      Mute(
          'Total ${rp(d.amount)} · terbayar ${rp(d.paid)}${d.due.isEmpty ? '' : ' · jatuh tempo ${tgl(d.due)}${late ? ' (lewat)' : ''}'}',
          c: late ? p.out : null),
      Bar(d.paid / d.amount, col),
      if (!done)
        Row(children: [
          Expanded(
              child: TextField(
                  controller: c,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: 'Jumlah cicilan', isDense: true))),
          const SizedBox(width: 8),
          OutlinedButton(
              onPressed: () {
                final v = double.tryParse(c.text) ?? 0;
                if (v <= 0) return;
                s.commit(() => d.paid = math.min(d.amount, d.paid + v));
                c.clear();
              },
              child: Text('Catat ${d.kind == 'utang' ? 'bayar' : 'terima'}')),
        ]),
    ]);
  }
}

// ───────────────────── Statistik ─────────────────────
class StatsTab extends StatelessWidget {
  final Store s;
  const StatsTab(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final d = pd('${s.month}-01');
    final ms = [for (var i = 5; i >= 0; i--) ymd(DateTime(d.year, d.month - i, 1)).substring(0, 7)];
    final inc = [for (final m in ms) s.sum(s.inMonth(s.income, m))];
    final exp = [for (final m in ms) s.sum(s.inMonth(s.expense, m))];
    final ci = inc[5], co = exp[5];
    var active = 0;
    for (var i = 0; i < 6; i++) {
      if (inc[i] > 0 || exp[i] > 0) active++;
    }
    if (active == 0) active = 1;
    final avgI = inc.fold(0.0, (a, b) => a + b) / active, avgO = exp.fold(0.0, (a, b) => a + b) / active;
    final rate = ci > 0 ? (ci - co) / ci * 100 : null;
    final chg = exp[4] > 0 ? (co - exp[4]) / exp[4] * 100 : null;
    final mi = s.inMonth(s.expense);
    final big = mi.isEmpty ? null : (mi.toList()..sort((a, b) => b.amount.compareTo(a.amount))).first;
    final keys = s.byCat(mi);
    final items = keys.take(5).toList();
    final rest = keys.skip(5).fold(0.0, (a, e) => a + e.value);
    if (rest > 0) items.add(MapEntry('Lainnya', rest));
    final days = s.month == s.today.substring(0, 7) ? int.parse(s.today.substring(8)) : DateTime(d.year, d.month + 1, 0).day;
    final ast = <String, double>{};
    for (final a in s.asset) {
      ast[a.cat] = (ast[a.cat] ?? 0) + a.amount;
    }
    final ak = ast.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final at = s.sum(s.asset);
    double dt = 0, dp = 0;
    for (final x in s.debt.where((x) => x.kind == 'utang')) {
      dt += x.amount;
      dp += x.paid;
    }
    final mo = moL(s.month);
    final tip = chg == null
        ? 'Catat pengeluaran dua bulan berturut-turut untuk melihat perbandingan.'
        : 'Pengeluaran $mo ${chg >= 0 ? 'naik' : 'turun'} ${chg.abs().toStringAsFixed(0)}% dibanding bulan sebelumnya.';
    Widget card(String l, String v, [Color? c]) => Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Mute(l), Big(v, c: c)]));

    return Column(children: [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: p.surface,
            border: Border(left: BorderSide(color: p.asset, width: 4)),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(14))),
        child: Text(tip),
      ),
      Cols([
        card('Rata-rata pendapatan per bulan', rp(avgI), p.inc),
        card('Rata-rata pengeluaran per bulan', rp(avgO), p.out),
        card('Tingkat tabungan bulan ini', rate == null ? '-' : '${rate.toStringAsFixed(0)}%'),
        card('Pengeluaran rata-rata per hari', rp(co / days)),
      ]),
      Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Pendapatan vs pengeluaran, 6 bulan terakhir'),
        SizedBox(
            height: 200,
            width: double.infinity,
            child: CustomPaint(
                painter: BarsPainter(inc, exp, [for (final m in ms) shortMonth(m)], p.inc, p.out, p.mute, p.line))),
        const SizedBox(height: 8),
        Wrap(spacing: 14, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [Dot(p.inc), const Mute('Pendapatan')]),
          Row(mainAxisSize: MainAxisSize.min, children: [Dot(p.out), const Mute('Pengeluaran')]),
        ]),
      ])),
      Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Komposisi pengeluaran'),
        if (items.isEmpty) Empty('Belum ada pengeluaran di $mo.'),
        if (items.isNotEmpty) ...[
          Row(children: [
            SizedBox(
                width: 140,
                height: 140,
                child: Stack(alignment: Alignment.center, children: [
                  CustomPaint(size: const Size(140, 140), painter: DonutPainter([for (final e in items) e.value])),
                  Text(cp(co), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ])),
            const SizedBox(width: 16),
            Expanded(
                child: Column(children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Dot(palette[i]),
                      Expanded(child: Text(items[i].key, overflow: TextOverflow.ellipsis)),
                      Text('${(items[i].value / co * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ])),
            ])),
          ]),
          if (big != null) Padding(padding: const EdgeInsets.only(top: 12), child: Mute('Terbesar: ${big.name} (${rp(big.amount)})')),
        ],
      ])),
      Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Komposisi aset'),
        if (ak.isEmpty) const Empty('Belum ada aset.'),
        for (var i = 0; i < ak.length; i++) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text(ak[i].key)),
            Text('${rp(ak[i].value)} (${(ak[i].value / at * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          Bar(ak[i].value / at, palette[i % 6]),
        ],
      ])),
      Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Kondisi utang'),
        if (dt == 0) const Empty('Tidak ada utang tercatat.'),
        if (dt > 0) ...[
          Big('${(dp / dt * 100).toStringAsFixed(0)}% lunas', size: 28),
          Bar(dp / dt, p.debt),
          Mute('Sisa utang ${rp(dt - dp)}${at > 0 ? ' · ${((dt - dp) / at * 100).toStringAsFixed(0)}% dari total aset' : ''}'),
        ],
      ])),
    ]);
  }
}

String shortMonth(String m) {
  const n = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  return n[int.parse(m.substring(5)) - 1];
}

void _text(Canvas c, String s, Offset o, Color col, double anchor) {
  final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: col, fontSize: 11)), textDirection: TextDirection.ltr)..layout();
  tp.paint(c, Offset(o.dx - tp.width * anchor, o.dy - tp.height / 2));
}

class BarsPainter extends CustomPainter {
  final List<double> a, b;
  final List<String> labels;
  final Color ca, cb, text, grid;
  BarsPainter(this.a, this.b, this.labels, this.ca, this.cb, this.text, this.grid);
  @override
  void paint(Canvas c, Size sz) {
    const left = 44.0;
    final bottom = sz.height - 22, h = bottom - 8;
    final mx = [...a, ...b, 1.0].reduce(math.max);
    for (final f in [0.0, .5, 1.0]) {
      final y = bottom - h * f;
      c.drawLine(Offset(left, y), Offset(sz.width, y), Paint()..color = grid);
      _text(c, cp(mx * f), Offset(left - 6, y), text, 1);
    }
    final slot = (sz.width - left) / a.length, bw = math.min(22.0, (slot - 10) / 2);
    for (var i = 0; i < a.length; i++) {
      final gx = left + i * slot + (slot - 2 * bw - 4) / 2;
      for (final k in [0, 1]) {
        final v = (k == 0 ? a : b)[i] / mx * h;
        c.drawRRect(
            RRect.fromRectAndCorners(Rect.fromLTWH(gx + k * (bw + 4), bottom - v, bw, v),
                topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
            Paint()..color = k == 0 ? ca : cb);
      }
      _text(c, labels[i], Offset(gx + bw + 2, sz.height - 8), text, .5);
    }
  }

  @override
  bool shouldRepaint(covariant BarsPainter o) => true;
}

class DonutPainter extends CustomPainter {
  final List<double> v;
  DonutPainter(this.v);
  @override
  void paint(Canvas c, Size sz) {
    final tot = v.fold(0.0, (a, b) => a + b);
    if (tot <= 0) return;
    final rect = Rect.fromCircle(center: Offset(sz.width / 2, sz.height / 2), radius: 52);
    var start = -math.pi / 2;
    for (var i = 0; i < v.length; i++) {
      final sw = v[i] / tot * 2 * math.pi;
      c.drawArc(rect, start, sw, false,
          Paint()..style = PaintingStyle.stroke..strokeWidth = 22..color = palette[i % 6]);
      start += sw;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter o) => true;
}

// ───────────────────── Kalender ─────────────────────
class CalendarTab extends StatefulWidget {
  final Store s;
  final void Function(String tab) onGo;
  const CalendarTab(this.s, this.onGo, {super.key});
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  String cv = 'bulan', msg = '';
  bool cfm = false, busy = false;
  late final nm = TextEditingController(text: widget.s.name);
  Store get s => widget.s;

  @override
  void dispose() {
    nm.dispose();
    super.dispose();
  }

  void nav(int n) {
    final d = pd(s.day);
    if (cv == 'hari') {
      s.setDay(ymd(DateTime(d.year, d.month, d.day + n)));
    } else if (cv == 'minggu') {
      s.setDay(ymd(DateTime(d.year, d.month, d.day + 7 * n)));
    } else {
      s.setDay(ymd(DateTime(d.year, d.month + n, 1)));
    }
  }

  List<Widget> entries(String ds) {
    final p = Pal.of(context);
    final out = <Widget>[];
    for (final t in ['income', 'expense']) {
      for (final x in s.list(t).where((e) => e.date == ds)) {
        final pl = t == 'income';
        out.add(Item(x.name, x.cat, '${pl ? '+' : '-'}${rp(x.amount)}',
            amountColor: pl ? p.inc : p.out, onDelete: () => s.commit(() => s.list(t).removeWhere((e) => e.id == x.id))));
      }
    }
    for (final d in s.debt.where((d) => d.due == ds && d.sisa > 0)) {
      out.add(Item(d.who, 'Jatuh tempo ${d.kind == 'utang' ? 'utang' : 'piutang'}', rp(d.sisa)));
    }
    return out;
  }

  Widget dayCard(String ds) {
    final t = s.dayTot(ds), e = entries(ds);
    return Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tgl(ds), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      Mute('Masuk ${rp(t[0])} · Keluar ${rp(t[1])}'),
      if (e.isEmpty) const Empty('Belum ada catatan di tanggal ini.'),
      if (e.isNotEmpty) Rows(e),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton(onPressed: () => widget.onGo('income'), child: const Text('Tambah pendapatan')),
        OutlinedButton(onPressed: () => widget.onGo('expense'), child: const Text('Tambah pengeluaran')),
      ]),
    ]));
  }

  Widget stat3(double a, double b) {
    final p = Pal.of(context);
    Widget c(String l, String v, [Color? col]) =>
        Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Mute(l), Big(v, c: col)]));
    return Cols([c('Masuk', rp(a), p.inc), c('Keluar', rp(b), p.out), c('Selisih', rp(a - b))]);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cd = s.day;
    final title = cv == 'hari'
        ? tglLong(cd)
        : cv == 'minggu'
            ? '${tgl(weekStart(cd))} - ${tgl(addD(weekStart(cd), 6))}'
            : moL(s.month);
    final body = <Widget>[];

    if (cv == 'hari') {
      body.add(dayCard(cd));
    } else if (cv == 'minggu') {
      final st = weekStart(cd);
      final days = [for (var i = 0; i < 7; i++) addD(st, i)];
      final ts = [for (final d in days) s.dayTot(d)];
      final mx = ts.fold(1.0, (m, t) => math.max(m, math.max(t[0], t[1])));
      body.add(stat3(ts.fold(0.0, (a, t) => a + t[0]), ts.fold(0.0, (a, t) => a + t[1])));
      body.add(Box(
          child: Column(children: [
        for (var i = 0; i < 7; i++)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(tglLong(days[i], short: true), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Mute('+${rp(ts[i][0])} / -${rp(ts[i][1])}'),
                ]),
                Bar(ts[i][0] / mx, p.inc),
                Bar(ts[i][1] / mx, p.out),
                ...entries(days[i]),
              ])),
      ])));
    } else {
      final y = int.parse(s.month.substring(0, 4)), m = int.parse(s.month.substring(5));
      final off = DateTime(y, m, 1).weekday - 1, nd = DateTime(y, m + 1, 0).day;
      body.add(Row(children: [
        for (final n in ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'])
          Expanded(child: Center(child: Mute(n))),
      ]));
      body.add(const SizedBox(height: 4));
      body.add(GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: .62,
        children: [
          for (var i = 0; i < off; i++) const SizedBox(),
          for (var d = 1; d <= nd; d++)
            () {
              final ds = '${s.month}-${d.toString().padLeft(2, '0')}', t = s.dayTot(ds);
              return InkWell(
                onTap: () => s.setDay(ds),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ds == cd ? p.asset : p.line, width: ds == cd ? 2 : 1),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$d', style: TextStyle(fontWeight: FontWeight.w700, color: ds == s.today ? p.asset : null)),
                    if (t[0] > 0) Text('+${cp(t[0])}', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 9, color: p.inc)),
                    if (t[1] > 0) Text('-${cp(t[1])}', maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 9, color: p.out)),
                  ]),
                ),
              );
            }(),
        ],
      ));
      body.add(const SizedBox(height: 14));
      body.add(stat3(s.sum(s.inMonth(s.income)), s.sum(s.inMonth(s.expense))));
      body.add(dayCard(cd));
      body.add(Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        H2('Dokumen ${moL(s.month)}'),
        TextField(
            controller: nm,
            onChanged: s.setName,
            decoration: const InputDecoration(labelText: 'Nama pada invoice', hintText: 'Nama kamu')),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: busy ? null : () => pdf(true),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Unduh invoice (PDF)')),
          FilledButton.icon(
              onPressed: busy ? null : () => pdf(false),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Unduh laporan (PDF)')),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          OutlinedButton(
              onPressed: () {
                if (!cfm) {
                  setState(() => cfm = true);
                } else {
                  s.commit(() {
                    s.income.removeWhere((x) => x.date.startsWith(s.month));
                    s.expense.removeWhere((x) => x.date.startsWith(s.month));
                  });
                  setState(() => cfm = false);
                }
              },
              child: Text(cfm ? 'Klik lagi untuk menghapus semua' : 'Hapus semua catatan bulan ini')),
          if (cfm) OutlinedButton(onPressed: () => setState(() => cfm = false), child: const Text('Batal')),
        ]),
        if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Mute(msg)),
      ])));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: p.surface, border: Border.all(color: p.line), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          for (final v in [['hari', 'Hari'], ['minggu', 'Minggu'], ['bulan', 'Bulan']])
            Expanded(
                child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => setState(() => cv = v[0]),
                    child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: cv == v[0] ? p.ink : null, borderRadius: BorderRadius.circular(9)),
                        child: Center(
                            child: Text(v[1],
                                style: TextStyle(fontWeight: FontWeight.w600, color: cv == v[0] ? p.bg : p.mute)))))),
        ]),
      ),
      Row(children: [
        OutlinedButton(onPressed: () => nav(-1), child: const Icon(Icons.chevron_left)),
        Expanded(child: Center(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))),
        OutlinedButton(onPressed: () => nav(1), child: const Icon(Icons.chevron_right)),
      ]),
      Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => s.setDay(s.today), child: const Text('Hari ini'))),
      ...body,
    ]);
  }

  Future<void> pdf(bool inv) async {
    setState(() {
      busy = true;
      msg = '';
    });
    try {
      await sharePdf(s, inv);
    } catch (_) {
      msg = 'Gagal membuat PDF.';
    }
    if (mounted) setState(() => busy = false);
  }
}

String tglLong(String d, {bool short = false}) {
  const hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  final x = pd(d), h = hari[x.weekday - 1];
  return short ? '$h, ${x.day} ${shortMonth(d.substring(0, 7))}' : '$h, ${tgl(d)}';
}
