import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime pd(String s) => DateTime.parse(s);
String rp(num n) => 'Rp${NumberFormat('#,##0', 'id_ID').format(n.round())}';
String tgl(String? d) =>
    (d == null || d.isEmpty) ? '' : DateFormat('d MMM y', 'id_ID').format(pd(d));
String moL(String m) => DateFormat('MMMM y', 'id_ID').format(pd('$m-01'));
String _t(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String cp(num n) {
  n = n.abs();
  if (n >= 1e9) return '${_t(n / 1e9)} M';
  if (n >= 1e6) return '${_t(n / 1e6)} jt';
  if (n >= 1e3) return '${(n / 1e3).round()} rb';
  return '${n.round()}';
}

String addD(String s, int n) {
  final d = pd(s);
  return ymd(DateTime(d.year, d.month, d.day + n));
}

String weekStart(String s) => addD(s, -(pd(s).weekday - 1));

const defCats = {
  'income': ['Gaji', 'Bonus', 'Usaha', 'Freelance', 'Pendapatan lain'],
  'expense': ['Makan', 'Transport', 'Tagihan', 'Belanja', 'Hiburan', 'Kesehatan'],
  'asset': ['Tabungan', 'Emas', 'Properti', 'Kendaraan', 'Investasi'],
};

class Entry {
  int id;
  String name, cat, date;
  double amount;
  Entry({required this.id, required this.name, required this.cat, required this.amount, this.date = ''});
  factory Entry.fromJson(Map j) => Entry(
        id: (j['id'] as num).toInt(),
        name: '${j['name']}',
        cat: '${j['cat']}',
        amount: (j['amount'] as num).toDouble(),
        date: '${j['date'] ?? ''}',
      );
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'cat': cat, 'amount': amount, 'date': date};
}

class Debt {
  int id;
  String kind, who, due;
  double amount, paid;
  Debt({required this.id, required this.kind, required this.who, required this.amount, this.due = '', this.paid = 0});
  double get sisa => amount - paid;
  factory Debt.fromJson(Map j) => Debt(
        id: (j['id'] as num).toInt(),
        kind: '${j['kind']}',
        who: '${j['who']}',
        amount: (j['amount'] as num).toDouble(),
        due: '${j['due'] ?? ''}',
        paid: ((j['paid'] ?? 0) as num).toDouble(),
      );
  Map<String, dynamic> toJson() =>
      {'id': id, 'kind': kind, 'who': who, 'amount': amount, 'due': due, 'paid': paid};
}

class Store extends ChangeNotifier {
  static const _k = 'catatan-kas-v1';
  List<Entry> income = [], expense = [], asset = [];
  List<Debt> debt = [];
  String name = '';
  final String today = ymd(DateTime.now());
  late String month = today.substring(0, 7);
  late String day = today;
  late String formDate = today;
  SharedPreferences? _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    try {
      final j = jsonDecode(_p!.getString(_k) ?? '{}') as Map;
      List<T> l<T>(String k, T Function(Map) f) =>
          ((j[k] ?? []) as List).map((e) => f(e as Map)).toList();
      income = l('income', Entry.fromJson);
      expense = l('expense', Entry.fromJson);
      asset = l('asset', Entry.fromJson);
      debt = l('debt', Debt.fromJson);
      name = '${j['name'] ?? ''}';
    } catch (_) {}
  }

  void _save() => _p?.setString(
      _k,
      jsonEncode({
        'income': income.map((e) => e.toJson()).toList(),
        'expense': expense.map((e) => e.toJson()).toList(),
        'asset': asset.map((e) => e.toJson()).toList(),
        'debt': debt.map((e) => e.toJson()).toList(),
        'name': name,
      }));

  void commit([VoidCallback? f]) {
    f?.call();
    _save();
    notifyListeners();
  }

  void setName(String v) {
    name = v.trim();
    _save();
  }

  void setDay(String s) {
    day = s;
    month = s.substring(0, 7);
    notifyListeners();
  }

  void setMonth(String m) {
    month = m;
    day = m == today.substring(0, 7) ? today : '$m-01';
    notifyListeners();
  }

  List<Entry> list(String t) => t == 'income' ? income : (t == 'expense' ? expense : asset);
  List<Entry> inMonth(List<Entry> a, [String? m]) =>
      a.where((x) => x.date.startsWith(m ?? month)).toList();
  double sum(Iterable<Entry> a) => a.fold(0.0, (t, x) => t + x.amount);

  List<String> cats(String t) =>
      {...defCats[t]!, ...list(t).map((x) => x.cat)}.where((e) => e.isNotEmpty).toList();

  List<MapEntry<String, double>> byCat(Iterable<Entry> a) {
    final m = <String, double>{};
    for (final x in a) {
      m[x.cat] = (m[x.cat] ?? 0) + x.amount;
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// [masuk, keluar] pada tanggal tertentu
  List<double> dayTot(String s) => [
        sum(income.where((x) => x.date == s)),
        sum(expense.where((x) => x.date == s)),
      ];
}
