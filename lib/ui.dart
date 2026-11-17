import 'package:flutter/material.dart';

class Pal {
  final Color bg, surface, ink, mute, line, inc, out, debt, asset;
  const Pal(this.bg, this.surface, this.ink, this.mute, this.line, this.inc, this.out, this.debt, this.asset);
  static const light = Pal(Color(0xFFEDF1F0), Colors.white, Color(0xFF12302A), Color(0xFF5E726D),
      Color(0xFFD3DDDA), Color(0xFF1B7A5A), Color(0xFFB4234A), Color(0xFFA86A0C), Color(0xFF2F55A4));
  static const dark = Pal(Color(0xFF0F1B18), Color(0xFF17272A), Color(0xFFE6F0ED), Color(0xFF93A8A3),
      Color(0xFF294039), Color(0xFF4FC79B), Color(0xFFF07A9A), Color(0xFFE3A647), Color(0xFF7FA2EA));
  static Pal of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;
}

const palette = [
  Color(0xFF2F55A4), Color(0xFF1B7A5A), Color(0xFFA86A0C),
  Color(0xFFB4234A), Color(0xFF7B4FA3), Color(0xFF6B7C85),
];

class Box extends StatelessWidget {
  final Widget child;
  final double bottom;
  const Box({super.key, required this.child, this.bottom = 12});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: bottom),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class Mute extends StatelessWidget {
  final String t;
  final Color? c;
  final bool bold;
  const Mute(this.t, {super.key, this.c, this.bold = false});
  @override
  Widget build(BuildContext context) => Text(t,
      style: TextStyle(
          fontSize: 14, color: c ?? Pal.of(context).mute, fontWeight: bold ? FontWeight.w600 : FontWeight.normal));
}

class Big extends StatelessWidget {
  final String t;
  final Color? c;
  final double size;
  const Big(this.t, {super.key, this.c, this.size = 24});
  @override
  Widget build(BuildContext context) =>
      Text(t, style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: c, letterSpacing: -.5));
}

class H2 extends StatelessWidget {
  final String t;
  const H2(this.t, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)));
}

class Bar extends StatelessWidget {
  final double v;
  final Color c;
  const Bar(this.v, this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final x = v.isNaN || v.isInfinite ? 0.0 : v.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(value: x, minHeight: 8, backgroundColor: Pal.of(context).line, color: c),
      ),
    );
  }
}

class Empty extends StatelessWidget {
  final String t;
  const Empty(this.t, {super.key});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 22), child: Center(child: Mute(t)));
}

class Dot extends StatelessWidget {
  final Color c;
  const Dot(this.c, {super.key});
  @override
  Widget build(BuildContext context) => Container(
      width: 9, height: 9, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

/// Susunan kolom responsif (2 kolom di HP, 3 di layar lebar)
class Cols extends StatelessWidget {
  final List<Widget> children;
  final double minW;
  const Cols(this.children, {super.key, this.minW = 160});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final cnt = children.isEmpty ? 1 : children.length;
        final n = (c.maxWidth / minW).floor().clamp(1, cnt).toInt();
        final w = (c.maxWidth - (n - 1) * 12) / n;
        return Wrap(spacing: 12, children: [for (final e in children) SizedBox(width: w, child: e)]);
      });
}

/// Baris dengan garis pemisah
class Rows extends StatelessWidget {
  final List<Widget> children;
  const Rows(this.children, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) Divider(height: 1, color: p.line),
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: children[i]),
      ]
    ]);
  }
}

class Item extends StatelessWidget {
  final String title, sub;
  final String amount;
  final Color? amountColor, subColor;
  final VoidCallback? onDelete;
  const Item(this.title, this.sub, this.amount, {super.key, this.amountColor, this.subColor, this.onDelete});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Mute(sub, c: subColor),
        ])),
        Text(amount, style: TextStyle(fontWeight: FontWeight.w600, color: amountColor)),
        if (onDelete != null)
          IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: Icon(Icons.close, size: 18, color: Pal.of(context).mute),
              tooltip: 'Hapus'),
      ]);
}
