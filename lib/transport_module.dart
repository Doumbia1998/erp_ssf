import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'main.dart';

// --- 1. MODÈLES ---
class Truck {
  String plateNumber, driverName, driverPhone;
  Truck({required this.plateNumber, required this.driverName, required this.driverPhone});
}

class Prestation {
  String axis;
  Tiers client;
  double price;
  Prestation({required this.axis, required this.client, required this.price});
}

class TripExpense {
  String label;
  double amount;
  TripExpense({required this.label, required this.amount});
}

class Trip {
  Truck truck;
  List<Prestation> prestations;
  List<TripExpense> expenses;
  DateTime departureDate;
  DateTime? returnDate;
  bool isFinished;

  Trip({
    required this.truck,
    required this.prestations,
    required this.expenses,
    required this.departureDate,
    this.returnDate,
    this.isFinished = false,
  });

  double get totalRevenue => prestations.fold(0.0, (sum, p) => sum + p.price);
  double get totalExpenses => expenses.fold(0.0, (sum, e) => sum + e.amount);
  double get netProfit => totalRevenue - totalExpenses;
  String get mainAxis => prestations.isNotEmpty ? prestations.first.axis : "Axe non défini";
}

// --- 2. DONNÉES GLOBALES ---
List<Truck> globalTrucks = [];
List<Trip> globalTrips = [];

// --- 3. MODULE PRINCIPAL ---
class TransportModule extends StatefulWidget {
  const TransportModule({super.key});
  @override State<TransportModule> createState() => _TransportModuleState();
}

class _TransportModuleState extends State<TransportModule> with SingleTickerProviderStateMixin {
  String queryTruck = "";
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double totalProfit = globalTrips.fold(0.0, (sum, t) => sum + t.netProfit);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: TabBar(
          controller: _tabController,
          tabs: const [Tab(icon: Icon(Icons.route), text: "Voyages"), Tab(icon: Icon(Icons.local_shipping), text: "Nos Camions")],
          labelColor: const Color(0xFF1A237E),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTripsTab(totalProfit), _buildTrucksTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1A237E),
        onPressed: _tabController.index == 0 ? _showAddTripDialog : _showAddTruckDialog,
        label: Text(_tabController.index == 0 ? "DÉMARRER VOYAGE" : "AJOUTER CAMION"),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTripsTab(double profit) {
    return Column(children: [
      Container(
        width: double.infinity, padding: const EdgeInsets.all(16), margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.indigo.shade900, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          const Text("BÉNÉFICE GLOBAL TRANSPORT", style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text(formatPrice(profit), style: const TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
      ),
      Expanded(child: globalTrips.isEmpty ? const Center(child: Text("Aucun voyage enregistré")) : ListView.builder(
        itemCount: globalTrips.length,
        itemBuilder: (context, i) {
          final trip = globalTrips[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: Icon(Icons.circle, color: trip.isFinished ? Colors.green : Colors.orange, size: 12),
              title: Text(trip.mainAxis, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${trip.truck.plateNumber} • ${trip.prestations.length} prestation(s)"),
              trailing: Text(formatPrice(trip.netProfit), style: TextStyle(color: trip.netProfit >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TripDetailScreen(trip: trip))).then((_) => setState(() {})),
            ),
          );
        },
      )),
      const SizedBox(height: 80),
    ]);
  }

  Widget _buildTrucksTab() {
    final filtered = globalTrucks.where((t) => t.plateNumber.toLowerCase().contains(queryTruck.toLowerCase())).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.all(8.0), child: TextField(onChanged: (v) => setState(() => queryTruck = v), decoration: const InputDecoration(hintText: "Chercher n° camion...", prefixIcon: Icon(Icons.search)))),
      Expanded(child: filtered.isEmpty ? const Center(child: Text("Aucun camion")) : ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, i) => ListTile(
          leading: const Icon(Icons.local_shipping, color: Color(0xFF1A237E)),
          title: Text(filtered[i].plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Chauffeur: ${filtered[i].driverName}"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TruckHistoryScreen(truck: filtered[i]))),
        ),
      )),
      const SizedBox(height: 80),
    ]);
  }

  void _showAddTruckDialog() {
    final plate = TextEditingController(); final name = TextEditingController(); final tel = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Nouveau Camion"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: plate, decoration: const InputDecoration(labelText: "N° Matricule")),
        TextField(controller: name, decoration: const InputDecoration(labelText: "Nom Chauffeur")),
        TextField(controller: tel, decoration: const InputDecoration(labelText: "Tél")),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annuler")), ElevatedButton(onPressed: () {
        setState(() { globalTrucks.add(Truck(plateNumber: plate.text, driverName: name.text, driverPhone: tel.text)); Navigator.pop(c); });
      }, child: const Text("Enregistrer"))],
    ));
  }

  void _showAddTripDialog() {
    if (globalTrucks.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Créez d'abord un camion !"))); return; }
    Tiers? selC; Truck? selT; final axe = TextEditingController(); final prix = TextEditingController(text: "0");
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text("Nouveau Voyage"),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<Tiers>(decoration: const InputDecoration(labelText: "Client"), items: globalTiers.where((t)=>t.isClient).map((t) => DropdownMenuItem(value: t, child: Text(t.compteTiers))).toList(), onChanged: (v) => selC = v),
        DropdownButtonFormField<Truck>(decoration: const InputDecoration(labelText: "Camion"), items: globalTrucks.map((t) => DropdownMenuItem(value: t, child: Text(t.plateNumber))).toList(), onChanged: (v) => selT = v),
        TextField(controller: axe, decoration: const InputDecoration(labelText: "Axe")),
        TextField(controller: prix, decoration: const InputDecoration(labelText: "Prix"), keyboardType: TextInputType.number, inputFormatters: [ThousandsSeparatorInputFormatter()], onTap: () => {if(prix.text == "0") prix.clear()}),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annuler")), ElevatedButton(onPressed: () {
        if (selC != null && selT != null) {
          setState(() { globalTrips.add(Trip(truck: selT!, prestations: [Prestation(axis: axe.text, client: selC!, price: double.tryParse(prix.text.replaceAll(' ', '')) ?? 0)], departureDate: DateTime.now(), expenses: [])); Navigator.pop(c); });
        }
      }, child: const Text("Démarrer"))],
    )));
  }
}

// --- 4. HISTORIQUE CAMION ---
class TruckHistoryScreen extends StatefulWidget {
  final Truck truck;
  const TruckHistoryScreen({super.key, required this.truck});
  @override State<TruckHistoryScreen> createState() => _TruckHistoryScreenState();
}

class _TruckHistoryScreenState extends State<TruckHistoryScreen> {
  DateTimeRange? selectedRange;

  @override
  Widget build(BuildContext context) {
    List<Trip> filtered = globalTrips.where((t) => t.truck.plateNumber == widget.truck.plateNumber).toList();
    if (selectedRange != null) {
      filtered = filtered.where((t) => t.departureDate.isAfter(selectedRange!.start.subtract(const Duration(days: 1))) && t.departureDate.isBefore(selectedRange!.end.add(const Duration(days: 1)))).toList();
    }
    double total = filtered.fold(0.0, (s, t) => s + t.netProfit);
    return Scaffold(
      appBar: AppBar(title: Text(widget.truck.plateNumber), backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, actions: [
        IconButton(icon: const Icon(Icons.calendar_month), onPressed: () async {
          final range = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDateRange: selectedRange);
          if (range != null) setState(() => selectedRange = range);
        }),
        IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () => _printReport(context, filtered)),
      ]),
      body: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(20), color: Colors.blue.shade50, child: Column(children: [
          Text(selectedRange == null ? "BÉNÉFICE TOTAL (TOUTE PÉRIODE)" : "BÉNÉFICE PÉRIODE SÉLECTIONNÉE", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          Text(formatPrice(total), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: total >= 0 ? Colors.green : Colors.red)),
        ])),
        Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (c, i) => ListTile(title: Text(filtered[i].mainAxis), subtitle: Text("Départ : ${DateFormat('dd/MM/yy').format(filtered[i].departureDate)}"), trailing: Text(formatPrice(filtered[i].netProfit), style: const TextStyle(fontWeight: FontWeight.bold))))),
      ]),
    );
  }

  Future<void> _printReport(BuildContext context, List<Trip> trips) async {
    final pdf = pw.Document(); final dateFormat = DateFormat('dd/MM/yyyy');
    final period = selectedRange == null ? "Toute la période" : "Du ${dateFormat.format(selectedRange!.start)} au ${dateFormat.format(selectedRange!.end)}";
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (pw.Context context) => [
      pw.Header(level: 0, child: pw.Text("RAPPORT D'ACTIVITE - ${widget.truck.plateNumber}", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
      pw.Text("Chauffeur : ${widget.truck.driverName} | Période : $period"),
      pw.SizedBox(height: 20),
      for (var trip in trips) ...[
        pw.Container(padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(color: PdfColors.grey200), child: pw.Text("Voyage : ${trip.mainAxis} (${dateFormat.format(trip.departureDate)})", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.TableHelper.fromTextArray(headers: ['Client', 'Axe', 'Prix'], data: trip.prestations.map((p) => [p.client.compteTiers, p.axis, formatPrice(p.price)]).toList()),
        pw.TableHelper.fromTextArray(headers: ['Dépense', 'Montant'], data: trip.expenses.map((e) => [e.label, formatPrice(e.amount)]).toList()),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Bénéfice : ${formatPrice(trip.netProfit)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 15),
      ],
      pw.Divider(),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("TOTAL PÉRIODE : ${formatPrice(trips.fold(0.0, (s, t) => s + t.netProfit))}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
    ]));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }
}

// --- 5. DÉTAIL VOYAGE ---
class TripDetailScreen extends StatefulWidget {
  final Trip trip;
  const TripDetailScreen({super.key, required this.trip});
  @override State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Suivi : ${widget.trip.truck.plateNumber}"), backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(20), color: Colors.indigo.shade50, child: Column(children: [
          _rowS("Revenus", formatPrice(widget.trip.totalRevenue)),
          _rowS("Dépenses", "- ${formatPrice(widget.trip.totalExpenses)}", red: true),
          const Divider(height: 30),
          _rowS("BÉNÉFICE NET", formatPrice(widget.trip.netProfit), bold: true, green: widget.trip.netProfit >= 0),
        ])),
        Expanded(child: SingleChildScrollView(child: Column(children: [
          const Padding(padding: EdgeInsets.all(8), child: Text("PRESTATIONS", style: TextStyle(fontWeight: FontWeight.bold))),
          ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: widget.trip.prestations.length, itemBuilder: (c, i) => ListTile(dense: true, title: Text(widget.trip.prestations[i].axis), subtitle: Text(widget.trip.prestations[i].client.compteTiers), trailing: Text(formatPrice(widget.trip.prestations[i].price)))),
          const Divider(),
          const Padding(padding: EdgeInsets.all(8), child: Text("DÉPENSES", style: TextStyle(fontWeight: FontWeight.bold))),
          ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: widget.trip.expenses.length, itemBuilder: (c, i) => ListTile(dense: true, title: Text(widget.trip.expenses[i].label), trailing: Text(formatPrice(widget.trip.expenses[i].amount), style: const TextStyle(color: Colors.red)))),
        ]))),
      ]),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!widget.trip.isFinished) Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: _addPrestation, icon: const Icon(Icons.add_box), label: const Text("Prestation"), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(onPressed: _addExp, icon: const Icon(Icons.add_circle), label: const Text("Dépense"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white))),
          ]),
          if (!widget.trip.isFinished) const SizedBox(height: 8),
          if (!widget.trip.isFinished)
          // --- BOUTON CLÔTURER EN VERT ---
            _roundedButton("CLÔTURER LE VOYAGE (RETOUR)", () {
              setState(() { widget.trip.isFinished = true; widget.trip.returnDate = DateTime.now(); });
              Navigator.pop(context);
            }, isFullWidth: true, color: Colors.green.shade700)
          else
            Container(padding: const EdgeInsets.all(8), width: double.infinity, color: Colors.grey.shade200, child: Text("Voyage terminé le ${DateFormat('dd/MM/yy HH:mm').format(widget.trip.returnDate!)}", textAlign: TextAlign.center)),
        ])),
      ),
    );
  }

  void _addExp() {
    final l = TextEditingController(); final a = TextEditingController(text: "0");
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Ajouter Dépense"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: l, decoration: const InputDecoration(labelText: "Nature")), TextField(controller: a, decoration: const InputDecoration(labelText: "Montant"), keyboardType: TextInputType.number)]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annuler")), ElevatedButton(onPressed: () { setState(() { widget.trip.expenses.add(TripExpense(label: l.text, amount: double.tryParse(a.text) ?? 0)); Navigator.pop(c); }); }, child: const Text("Ajouter"))]));
  }

  void _addPrestation() {
    Tiers? selC; final axe = TextEditingController(); final px = TextEditingController(text: "0");
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(title: const Text("Nouvelle Prestation"), content: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<Tiers>(decoration: const InputDecoration(labelText: "Client"), items: globalTiers.where((t)=>t.isClient).map((t)=>DropdownMenuItem(value: t, child: Text(t.compteTiers))).toList(), onChanged: (v)=>selC=v),
      TextField(controller: axe, decoration: const InputDecoration(labelText: "Axe")),
      TextField(controller: px, decoration: const InputDecoration(labelText: "Prix"), keyboardType: TextInputType.number),
    ]), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Annuler")), ElevatedButton(onPressed: (){ if(selC != null){ setState((){ widget.trip.prestations.add(Prestation(axis: axe.text, client: selC!, price: double.tryParse(px.text.replaceAll(' ', '')) ?? 0)); Navigator.pop(c); }); } }, child: const Text("Ajouter"))])));
  }

  Widget _rowS(String l, String v, {bool bold = false, bool red = false, bool green = false}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)), Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: red ? Colors.red : (green ? Colors.green : Colors.black)))]);
}

// --- WIDGET BOUTON ---
Widget _roundedButton(String label, VoidCallback onTap, {bool isFullWidth = false, Color color = const Color(0xFF1A237E)}) {
  return SizedBox(width: isFullWidth ? double.infinity : null, child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)), child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))));
}