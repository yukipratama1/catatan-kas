import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens.dart';
import 'store.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final s = Store();
  await s.load();
  runApp(App(s));
}

ThemeData _theme(Pal p, Brightness b) => ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: p.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: p.asset, brightness: b)
          .copyWith(primary: p.ink, onPrimary: p.bg, surface: p.surface),
      appBarTheme: AppBarTheme(backgroundColor: p.bg, foregroundColor: p.ink, elevation: 0, scrolledUnderElevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.line)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: p.ink, foregroundColor: p.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: p.ink, side: BorderSide(color: p.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
    );

class App extends StatelessWidget {
  final Store s;
  const App(this.s, {super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Catatan Kas',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: _theme(Pal.light, Brightness.light),
        darkTheme: _theme(Pal.dark, Brightness.dark),
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Home(s),
      );
}

const tabs = [
  ['ringkasan', 'Ringkasan'], ['cal', 'Kalender'], ['income', 'Pendapatan'],
  ['expense', 'Pengeluaran'], ['debt', 'Utang'], ['asset', 'Aset'], ['stat', 'Statistik'],
];

class Home extends StatefulWidget {
  final Store s;
  const Home(this.s, {super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String tab = 'ringkasan';
  Store get s => widget.s;

  void go(String t, {bool useDay = false}) {
    s.formDate = useDay ? s.day : s.today;
    setState(() => tab = t);
  }

  Widget content() {
    switch (tab) {
      case 'cal':
        return CalendarTab(s, (t) => go(t, useDay: true));
      case 'income':
      case 'expense':
      case 'asset':
        return ListTab(s, tab);
      case 'debt':
        return DebtTab(s);
      case 'stat':
        return StatsTab(s);
      default:
        return SummaryTab(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Kas', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          ListenableBuilder(
              listenable: s,
              builder: (_, __) {
                void step(int n) {
                  final d = pd('${s.month}-01');
                  s.setMonth(ymd(DateTime(d.year, d.month + n, 1)).substring(0, 7));
                }

                return Row(children: [
                  IconButton(onPressed: () => step(-1), icon: const Icon(Icons.chevron_left)),
                  Text(moL(s.month), style: const TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(onPressed: () => step(1), icon: const Icon(Icons.chevron_right)),
                ]);
              }),
        ],
      ),
      body: ListenableBuilder(
        listenable: s,
        builder: (_, __) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: SingleChildScrollView(
              key: ValueKey(tab),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: content(),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.line))),
        child: SafeArea(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(6),
            child: Row(children: [
              for (final t in tabs)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => go(t[0]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: tab == t[0] ? p.bg : null, borderRadius: BorderRadius.circular(10)),
                    child: Text(t[1],
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13, color: tab == t[0] ? p.ink : p.mute)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
