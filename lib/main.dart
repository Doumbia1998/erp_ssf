import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dashboard_home.dart';
import 'transport_module.dart';

void main() => runApp(const SSFApp());

// --- UTILITAIRES ---
String formatPrice(double price) => NumberFormat('#,###', 'fr_FR').format(price).replaceAll(',', ' ') + " FCFA";

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      int index = text.length - i - 1;
      if (index % 3 == 0 && index != 0) buffer.write(' ');
    }
    return newValue.copyWith(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.toString().length));
  }
}

// --- 1. MODÈLES DE DONNÉES ---
class CompteComptable {
  final String numero, intitule, nature;
  CompteComptable({required this.numero, required this.intitule, required this.nature});
  @override String toString() => '$numero - $intitule';
}

class Product {
  String designation;
  double prixAchat, prixVente, stock;
  CompteComptable? compteComptable;
  Product({required this.designation, this.prixAchat = 0, this.prixVente = 0, this.stock = 0, this.compteComptable});
}

class Tiers {
  String compteTiers, intitule, adresse, telephone;
  bool isClient;
  CompteComptable? compteCollectif;
  Tiers({required this.compteTiers, required this.intitule, this.compteCollectif, this.adresse = "", this.telephone = "", required this.isClient});
}

class InvoiceLine {
  Product? product;
  double quantite, prixUnitaire, remise;
  InvoiceLine({this.product, this.quantite = 0, this.prixUnitaire = 0, this.remise = 0});
  double get montantHT => (quantite * prixUnitaire) - remise;
}

class Invoice {
  String numero, modePaiement, motifPaiement;
  DateTime date;
  Tiers client;
  List<InvoiceLine> lignes;
  double acompte;
  Invoice({required this.numero, required this.date, required this.client, required this.lignes, this.acompte = 0, this.modePaiement = "Espèces", this.motifPaiement = ""});
  double get totalHT => lignes.fold(0.0, (sum, item) => sum + item.montantHT);
  double get netAPayer => totalHT - acompte;
}

class Payment {
  final String clientTiers, mode, motif;
  final double montant;
  final DateTime date;
  Payment({required this.clientTiers, required this.montant, required this.date, required this.mode, this.motif = ""});
}

// --- 2. DONNÉES GLOBALES ---
List<CompteComptable> globalPlanComptable = [
  CompteComptable(numero: "70110000", intitule: "Ventes", nature: "Produit"),
  CompteComptable(numero: "41100000", intitule: "Clients", nature: "Tiers"),
  CompteComptable(numero: "40100000", intitule: "Fournisseurs", nature: "Tiers"),
];
List<Product> globalProducts = [];
List<Tiers> globalTiers = [];
List<Invoice> globalInvoices = [];
List<Invoice> globalPurchases = [];
List<Payment> globalPayments = [];
List<String> globalDepots = [];

// --- 3. UI PRINCIPALE ---
class SSFApp extends StatelessWidget {
  const SSFApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'VENTES', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)), useMaterial3: true),
    home: const MainNavigation(),
  );
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  bool isTransportMode = false;
  String currentModule = "Dashboard";

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(isTransportMode ? "TRANSPORT" : "SSF VENTE", style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white,
      actions: [
        DropdownButton<String>(
          value: isTransportMode ? "Transport" : "Ventes",
          dropdownColor: const Color(0xFF1A237E), underline: const SizedBox(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          items: const [
            DropdownMenuItem(value: "Ventes", child: Text("SSF VENTE")),
            DropdownMenuItem(value: "Transport", child: Text("TRANSPORT")),
          ],
          onChanged: (val) => setState(() => isTransportMode = val == "Transport"),
        ),
        const SizedBox(width: 10),
      ],
    ),
    drawer: Drawer(child: ListView(children: [
      DrawerHeader(decoration: const BoxDecoration(color: Color(0xFF1A237E)), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.asset('assets/logo_ssf.png', height: 60, errorBuilder: (c,e,s) => const Icon(Icons.business, color: Colors.white, size: 50)),
        Text(isTransportMode ? "TRANSPORT" : "SSF VENTE", style: const TextStyle(color: Colors.white, fontSize: 18)),
      ]))),
      _drawerItem(Icons.dashboard, "Dashboard"),
      _drawerItem(Icons.settings, "Structure"),
      _drawerItem(Icons.assignment, "Documents des Ventes"),
      _drawerItem(Icons.shopping_cart, "Documents des Achats"),
    ])),
    body: isTransportMode ? TransportModule() : _buildBody(),
  );

  Widget _drawerItem(IconData i, String t) => ListTile(leading: Icon(i), title: Text(t), selected: currentModule == t, onTap: () { setState(() => currentModule = t); Navigator.pop(context); });

  Widget _buildBody() {
    switch (currentModule) {
      case "Structure": return const StructureModule();
      case "Documents des Ventes": return SalesDocumentsModule();
      case "Documents des Achats": return PurchaseDocumentsModule();
      default: return const DashboardHome();
    }
  }
}

class StructureModule extends StatelessWidget {
  const StructureModule({super.key});
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    _card(context, "Plan Comptable", Icons.account_tree, PlanComptableListScreen()),
    _card(context, "Articles", Icons.inventory_2, ArticlesListScreen()),
    _card(context, "Clients", Icons.people, TiersListScreen(isClient: true)),
    _card(context, "Fournisseurs", Icons.business_center, TiersListScreen(isClient: false)),
    _card(context, "Dépôts", Icons.warehouse, DepotsListScreen()),
  ]);
  Widget _card(BuildContext ctx, String t, IconData i, Widget s) => Card(child: ListTile(leading: Icon(i, color: const Color(0xFF1A237E)), title: Text(t), onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (c) => s))));
}

// --- 4. LISTES ---
class ArticlesListScreen extends StatefulWidget {
  @override State<ArticlesListScreen> createState() => _ArticlesListScreenState();
}
class _ArticlesListScreenState extends State<ArticlesListScreen> {
  String q = "";
  @override Widget build(BuildContext context) {
    final list = globalProducts.where((p) => p.designation.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
        appBar: AppBar(title: const Text("Articles")),
        body: Column(children: [
          Padding(padding: const EdgeInsets.all(8), child: TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: "Rechercher...", prefixIcon: Icon(Icons.search)))),
          Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (context, i) => ListTile(
            title: Text(list[i].designation),
            subtitle: Text("Stock: ${list[i].stock.toStringAsFixed(0)}"),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(formatPrice(list[i].prixVente)),
              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateArticleScreen(productToEdit: list[i]))).then((_) => setState(() {}))),
            ]),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProductDetailScreen(product: list[i]))),
          ))),
        ]),
        floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateArticleScreen())).then((_) => setState(() {})), child: const Icon(Icons.add))
    );
  }
}

class TiersListScreen extends StatefulWidget {
  final bool isClient; TiersListScreen({required this.isClient});
  @override State<TiersListScreen> createState() => _TiersListScreenState();
}
class _TiersListScreenState extends State<TiersListScreen> {
  String q = "";
  @override Widget build(BuildContext context) {
    final list = globalTiers.where((t) => t.isClient == widget.isClient && t.compteTiers.toLowerCase().contains(q.toLowerCase())).toList();
    double tA = 0, tP = 0;
    for (var t in list) {
      final invs = (widget.isClient ? globalInvoices : globalPurchases).where((i) => i.client.compteTiers == t.compteTiers);
      final pays = globalPayments.where((p) => p.clientTiers == t.compteTiers);
      tA += invs.fold(0.0, (s, i) => s + i.totalHT);
      tP += invs.fold(0.0, (s, i) => s + i.acompte) + pays.fold(0.0, (s, p) => s + p.montant);
    }
    return Scaffold(appBar: AppBar(title: Text(widget.isClient ? "Clients" : "Fournisseurs")), body: Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: "Rechercher...", prefixIcon: Icon(Icons.search)))),
      if (widget.isClient) Container(width: double.infinity, margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(12)), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL ACHATS", style: TextStyle(color: Colors.white, fontSize: 12)), Text(formatPrice(tA), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL IMPAYÉS", style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)), Text(formatPrice(tA - tP), style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))]),
      ])),
      Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(
        leading: Icon(widget.isClient ? Icons.person : Icons.business),
        title: Text(list[i].compteTiers),
        trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateTiersScreen(isClient: widget.isClient, tiersToEdit: list[i]))).then((_) => setState(() {}))),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TiersDetailScreen(tiers: list[i]))),
      ))),
    ]), floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateTiersScreen(isClient: widget.isClient))).then((_) => setState(() {})), child: const Icon(Icons.add)));
  }
}

// --- 5. DÉTAILS PRODUIT ET TIERS ---
class ProductDetailScreen extends StatelessWidget {
  final Product product; ProductDetailScreen({required this.product});
  @override Widget build(BuildContext context) {
    double tQ = 0, tCA = 0, tC = 0;
    for (var i in globalInvoices) {
      for (var l in i.lignes) { if (l.product?.designation == product.designation) { tQ += l.quantite; tCA += l.montantHT; tC += (l.quantite * product.prixAchat); } }
    }
    return Scaffold(appBar: AppBar(title: Text(product.designation)), body: Column(children: [
      Container(width: double.infinity, margin: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFDFF0D8), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        _rowDetail("Quantités Vendues", tQ.toStringAsFixed(0)), _rowDetail("Chiffre d'affaires", formatPrice(tCA)), _rowDetail("Marge", formatPrice(tCA - tC)), _rowDetail("Stock Actuel", product.stock.toStringAsFixed(0)),
      ]))),
      const Padding(padding: EdgeInsets.all(8), child: Text("HISTORIQUE DES VENTES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
      Expanded(child: ListView(children: globalInvoices.where((i) => i.lignes.any((l) => l.product?.designation == product.designation)).map((i) => ListTile(title: Text(i.client.compteTiers), subtitle: Text(DateFormat('dd/MM/yyyy').format(i.date)), trailing: Text(formatPrice(i.totalHT)))).toList())),
    ]));
  }
  Widget _rowDetail(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]);
}

class TiersDetailScreen extends StatefulWidget {
  final Tiers tiers; TiersDetailScreen({required this.tiers});
  @override State<TiersDetailScreen> createState() => _TiersDetailScreenState();
}
class _TiersDetailScreenState extends State<TiersDetailScreen> {
  @override Widget build(BuildContext context) {
    final invList = widget.tiers.isClient ? globalInvoices : globalPurchases;
    final invoices = invList.where((i) => i.client.compteTiers == widget.tiers.compteTiers).toList();
    final payments = globalPayments.where((p) => p.clientTiers == widget.tiers.compteTiers).toList();
    double tA = invoices.fold(0.0, (s, i) => s + i.totalHT), tP = invoices.fold(0.0, (s, i) => s + i.acompte) + payments.fold(0.0, (s, p) => s + p.montant);
    return Scaffold(appBar: AppBar(title: Text(widget.tiers.compteTiers)), body: Column(children: [
      Container(padding: const EdgeInsets.all(15), color: const Color(0xFF1A237E).withOpacity(0.05), child: Column(children: [_rSummary("Total", formatPrice(tA)), _rSummary("Payé", formatPrice(tP)), _rSummary("Reste à Payer", formatPrice(tA - tP), red: tA - tP > 0)])),
      Padding(padding: const EdgeInsets.all(10), child: _roundedButton("Effectuer un règlement", () => _pay(context))),
      Expanded(child: ListView(children: [...invoices.map((i) => ListTile(title: Text("Facture ${i.numero}"), trailing: Text(formatPrice(i.totalHT)))), ...payments.map((p) => ListTile(title: Text("Règlement (${p.mode})"), subtitle: Text(p.motif), trailing: Text("- ${formatPrice(p.montant)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))))])),
    ]));
  }
  void _pay(BuildContext ctx) {
    final ctrl = TextEditingController(text: "0"); final mCtrl = TextEditingController(); String mode = "Espèces";
    showDialog(context: ctx, builder: (c) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(title: const Text("Nouveau Règlement"), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: ctrl, decoration: const InputDecoration(labelText: "Montant"), keyboardType: TextInputType.number, inputFormatters: [ThousandsSeparatorInputFormatter()], onTap: () => {if(ctrl.text=="0") ctrl.clear()}),
      DropdownButtonFormField<String>(value: mode, items: ["Espèces", "Chèque", "Virement"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) => setS(() => mode = v!), decoration: const InputDecoration(labelText: "Mode")),
      if (mode != "Espèces") TextField(controller: mCtrl, decoration: const InputDecoration(labelText: "Motif / Banque"))
    ]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annuler")), ElevatedButton(onPressed: () { if(ctrl.text.isNotEmpty) { setState(() { globalPayments.add(Payment(clientTiers: widget.tiers.compteTiers, montant: double.parse(ctrl.text.replaceAll(' ', '')), date: DateTime.now(), mode: mode, motif: mCtrl.text)); }); Navigator.pop(c); } }, child: const Text("Valider"))])));
  }
  Widget _rSummary(String l, String v, {bool red = false}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l), Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: red ? Colors.red : Colors.black))]);
}

// --- 6. DOCUMENTS ET FACTURATION ---
class SalesDocumentsModule extends StatefulWidget { @override State<SalesDocumentsModule> createState() => _SDMState(); }
class _SDMState extends State<SalesDocumentsModule> {
  String q = "";
  @override Widget build(BuildContext context) {
    final list = globalInvoices.where((i) => i.numero.toLowerCase().contains(q.toLowerCase()) || i.client.compteTiers.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(appBar: AppBar(title: const Text("Ventes"), automaticallyImplyLeading: false), body: Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: "Rechercher...", prefixIcon: Icon(Icons.search)))),
      Container(width: double.infinity, margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL CA VENTES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(formatPrice(list.fold(0.0, (sum, inv) => sum + inv.totalHT)), style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))])),
      Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(leading: const Icon(Icons.description, color: Colors.blue), title: Text("Facture ${list[i].numero}"), subtitle: Text(list[i].client.compteTiers), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateInvoiceScreen(isAchat: false, invoiceToEdit: list[i]))).then((_) => setState(() {}))), IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red), onPressed: () => _printProfessionalInvoice(context, list[i]))]))))
    ]), floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateInvoiceScreen(isAchat: false))).then((_) => setState(() {})), label: const Text("Nouvelle Vente"), icon: const Icon(Icons.add)));
  }
}

class PurchaseDocumentsModule extends StatefulWidget { @override State<PurchaseDocumentsModule> createState() => _PDMState(); }
class _PDMState extends State<PurchaseDocumentsModule> {
  String q = "";
  @override Widget build(BuildContext context) {
    final list = globalPurchases.where((i) => i.numero.toLowerCase().contains(q.toLowerCase()) || i.client.compteTiers.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(appBar: AppBar(title: const Text("Achats"), automaticallyImplyLeading: false), body: Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: "Rechercher...", prefixIcon: Icon(Icons.search)))),
      Container(width: double.infinity, margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL ACHATS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(formatPrice(list.fold(0.0, (sum, inv) => sum + inv.totalHT)), style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold))])),
      Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(leading: const Icon(Icons.shopping_basket, color: Colors.teal), title: Text("Achat ${list[i].numero}"), subtitle: Text(list[i].client.compteTiers), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateInvoiceScreen(isAchat: true, invoiceToEdit: list[i]))).then((_) => setState(() {}))), IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red), onPressed: () => _printProfessionalInvoice(context, list[i]))]))))
    ]), floatingActionButton: FloatingActionButton.extended(backgroundColor: Colors.teal, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateInvoiceScreen(isAchat: true))).then((_) => setState(() {})), label: const Text("Nouvel Achat"), icon: const Icon(Icons.add, color: Colors.white)));
  }
}

class CreateInvoiceScreen extends StatefulWidget { final bool isAchat; final Invoice? invoiceToEdit; CreateInvoiceScreen({required this.isAchat, this.invoiceToEdit}); @override State<CreateInvoiceScreen> createState() => _CISState(); }
class _CISState extends State<CreateInvoiceScreen> {
  late String s; Tiers? selC; List<InvoiceLine> l = []; late TextEditingController ac; String m = "Espèces";
  @override void initState() {
    super.initState();
    s = widget.invoiceToEdit?.numero ?? "FA${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
    selC = widget.invoiceToEdit?.client; ac = TextEditingController(text: widget.invoiceToEdit?.acompte.toString().replaceAll('.0', '') ?? "0");
    m = widget.invoiceToEdit?.modePaiement ?? "Espèces";
    l = widget.invoiceToEdit != null ? List.from(widget.invoiceToEdit!.lignes) : [InvoiceLine()];
  }
  double get totalHT => l.fold(0.0, (sum, item) => sum + item.montantHT);
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.isAchat ? "Achat $s" : "Vente $s"), backgroundColor: widget.isAchat ? Colors.teal : const Color(0xFF1A237E)), body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    DropdownButtonFormField<Tiers>(value: selC, decoration: const InputDecoration(labelText: "Tiers"), items: globalTiers.where((t) => t.isClient == !widget.isAchat).map((t) => DropdownMenuItem(value: t, child: Text(t.compteTiers))).toList(), onChanged: (v) => setState(() => selC = v)),
    const SizedBox(height: 20), const Text("Articles / Produits", style: TextStyle(fontWeight: FontWeight.bold)),
    ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: l.length, itemBuilder: (ctx, i) => InvoiceLineRow(line: l[i], isAchat: widget.isAchat, onUpdate: () => setState(() {}))),
    TextButton.icon(onPressed: () => setState(() => l.add(InvoiceLine())), icon: const Icon(Icons.add), label: const Text("Ajouter ligne")),
    const Divider(), DropdownButtonFormField<String>(value: m, items: ["Espèces", "Chèque", "Virement", "MobiCash", "Orange Money"].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => m = v!), decoration: const InputDecoration(labelText: "Mode")),
    TextField(controller: ac, decoration: const InputDecoration(labelText: "Acompte"), inputFormatters: [ThousandsSeparatorInputFormatter()], keyboardType: TextInputType.number, onTap: () => {if(ac.text=="0") ac.clear()}, onChanged: (v) => setState(() {})),
    const SizedBox(height: 20), Align(alignment: Alignment.centerRight, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text("Total HT : ${formatPrice(totalHT)}"),
      Text("NET À PAYER : ${formatPrice(totalHT - (double.tryParse(ac.text.replaceAll(' ', '')) ?? 0))}", style: const TextStyle(fontSize: 18, color: Colors.lightBlue, fontWeight: FontWeight.bold)),
    ])),
    const SizedBox(height: 30), _roundedButton("VALIDER", () { if (selC != null) { setState(() {
      if (widget.invoiceToEdit != null) { for (var line in widget.invoiceToEdit!.lignes) { if (line.product != null) { if (widget.isAchat) line.product!.stock -= line.quantite; else line.product!.stock += line.quantite; } } }
      for (var line in l) { if (line.product != null) { if (widget.isAchat) line.product!.stock += line.quantite; else line.product!.stock -= line.quantite; } }
      final newInv = Invoice(numero: s, date: DateTime.now(), client: selC!, lignes: List.from(l), acompte: double.tryParse(ac.text.replaceAll(' ', '')) ?? 0, modePaiement: m);
      if (widget.invoiceToEdit != null) { if (widget.isAchat) globalPurchases[globalPurchases.indexOf(widget.invoiceToEdit!)] = newInv; else globalInvoices[globalInvoices.indexOf(widget.invoiceToEdit!)] = newInv; }
      else { if (widget.isAchat) globalPurchases.add(newInv); else globalInvoices.add(newInv); }
    }); Navigator.pop(context); } }, isFullWidth: true),
  ])));
}

class InvoiceLineRow extends StatefulWidget {
  final InvoiceLine line; final bool isAchat; final VoidCallback onUpdate;
  InvoiceLineRow({required this.line, required this.isAchat, required this.onUpdate});
  @override State<InvoiceLineRow> createState() => _ILRState();
}
class _ILRState extends State<InvoiceLineRow> {
  late TextEditingController q, p, r;
  @override void initState() { super.initState(); q = TextEditingController(text: widget.line.quantite.toString().replaceAll('.0', '')); p = TextEditingController(text: widget.line.prixUnitaire.toString().replaceAll('.0', '')); r = TextEditingController(text: widget.line.remise.toString().replaceAll('.0', '')); }
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      DropdownButtonFormField<Product>(value: widget.line.product, decoration: const InputDecoration(labelText: "Article", border: InputBorder.none), items: globalProducts.map((p) => DropdownMenuItem(value: p, child: Text(p.designation))).toList(), onChanged: (v) => setState(() { widget.line.product = v; widget.line.prixUnitaire = widget.isAchat ? (v?.prixAchat ?? 0) : (v?.prixVente ?? 0); p.text = widget.line.prixUnitaire.toString().replaceAll('.0', ''); widget.onUpdate(); })),
      Row(children: [
        Expanded(child: TextField(controller: q, decoration: const InputDecoration(labelText: "Qté"), keyboardType: TextInputType.number, onTap: () => {if(q.text=="0") q.clear()}, onChanged: (v) { widget.line.quantite = double.tryParse(v) ?? 0; widget.onUpdate(); })),
        const SizedBox(width: 8), Expanded(child: TextField(controller: p, decoration: const InputDecoration(labelText: "PU"), keyboardType: TextInputType.number, inputFormatters: [ThousandsSeparatorInputFormatter()], onTap: () => {if(p.text=="0") p.clear()}, onChanged: (v) { widget.line.prixUnitaire = double.tryParse(v.replaceAll(' ', '')) ?? 0; widget.onUpdate(); })),
        if (!widget.isAchat) const SizedBox(width: 8), if (!widget.isAchat) Expanded(child: TextField(controller: r, decoration: const InputDecoration(labelText: "Remise"), inputFormatters: [ThousandsSeparatorInputFormatter()], keyboardType: TextInputType.number, onTap: () => {if(r.text=="0") r.clear()}, onChanged: (v) { widget.line.remise = double.tryParse(v.replaceAll(' ', '')) ?? 0; widget.onUpdate(); })),
      ])
    ]),
  );
}

// --- 7. CRÉATIONS ET PDF ---
class CreateArticleScreen extends StatefulWidget { final Product? productToEdit; CreateArticleScreen({this.productToEdit}); @override State<CreateArticleScreen> createState() => _CASState(); }
class _CASState extends State<CreateArticleScreen> {
  late TextEditingController d, pa, pv, st; CompteComptable? s;
  @override void initState() { super.initState(); d = TextEditingController(text: widget.productToEdit?.designation ?? ""); pa = TextEditingController(text: widget.productToEdit?.prixAchat.toString().replaceAll('.0', '') ?? "0"); pv = TextEditingController(text: widget.productToEdit?.prixVente.toString().replaceAll('.0', '') ?? "0"); st = TextEditingController(text: widget.productToEdit?.stock.toString().replaceAll('.0', '') ?? "0"); s = widget.productToEdit?.compteComptable; }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.productToEdit == null ? "Nouvel Article" : "Modifier Article")), body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_sectionHeader(Icons.shopping_cart, "Détails"), TextField(controller: d, decoration: const InputDecoration(labelText: "Désignation")), DropdownButtonFormField<CompteComptable>(value: s, items: globalPlanComptable.map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(), onChanged: (v) => s = v, decoration: const InputDecoration(labelText: "Compte")), Row(children: [Expanded(child: TextField(controller: pa, decoration: const InputDecoration(labelText: "Prix Achat"), inputFormatters: [ThousandsSeparatorInputFormatter()], keyboardType: TextInputType.number, onTap: () { if(pa.text == "0") pa.clear(); })), const SizedBox(width: 10), Expanded(child: TextField(controller: pv, decoration: const InputDecoration(labelText: "Prix Vente"), inputFormatters: [ThousandsSeparatorInputFormatter()], keyboardType: TextInputType.number, onTap: () { if(pv.text == "0") pv.clear(); }))]), TextField(controller: st, decoration: const InputDecoration(labelText: "Stock"), keyboardType: TextInputType.number, onTap: () { if(st.text == "0") st.clear(); }), const SizedBox(height: 30), _roundedButton("VALIDER", () { if (widget.productToEdit != null) { widget.productToEdit!.designation = d.text; widget.productToEdit!.prixAchat = double.tryParse(pa.text.replaceAll(' ', '')) ?? 0; widget.productToEdit!.prixVente = double.tryParse(pv.text.replaceAll(' ', '')) ?? 0; widget.productToEdit!.stock = double.tryParse(st.text) ?? 0; widget.productToEdit!.compteComptable = s; } else { globalProducts.add(Product(designation: d.text, prixAchat: double.tryParse(pa.text.replaceAll(' ', ''))??0, prixVente: double.tryParse(pv.text.replaceAll(' ', ''))??0, stock: double.tryParse(st.text)??0, compteComptable: s)); } Navigator.pop(context); }, isFullWidth: true)])));
}

class CreateTiersScreen extends StatefulWidget { final bool isClient; final Tiers? tiersToEdit; CreateTiersScreen({required this.isClient, this.tiersToEdit}); @override State<CreateTiersScreen> createState() => _CTSState(); }
class _CTSState extends State<CreateTiersScreen> {
  late TextEditingController n, a, t; CompteComptable? s;
  @override void initState() { super.initState(); n = TextEditingController(text: widget.tiersToEdit?.compteTiers ?? ""); a = TextEditingController(text: widget.tiersToEdit?.adresse ?? ""); t = TextEditingController(text: widget.tiersToEdit?.telephone ?? ""); s = widget.tiersToEdit?.compteCollectif; }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.tiersToEdit == null ? "Nouveau Tiers" : "Modifier Tiers")), body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_sectionHeader(Icons.person, "Identité"), TextField(controller: n, decoration: const InputDecoration(labelText: "Nom / Compte Tiers")), DropdownButtonFormField<CompteComptable>(value: s, items: globalPlanComptable.where((e)=>e.nature=="Tiers").map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(), onChanged: (v) => s = v, decoration: const InputDecoration(labelText: "Compte Collectif")), TextField(controller: a, decoration: const InputDecoration(labelText: "Adresse")), TextField(controller: t, decoration: const InputDecoration(labelText: "Téléphone"), keyboardType: TextInputType.phone), _roundedButton("VALIDER", () { if (widget.tiersToEdit != null) { widget.tiersToEdit!.compteTiers = n.text; widget.tiersToEdit!.adresse = a.text; widget.tiersToEdit!.telephone = t.text; widget.tiersToEdit!.compteCollectif = s; } else { globalTiers.add(Tiers(compteTiers: n.text, intitule: n.text, adresse: a.text, telephone: t.text, isClient: widget.isClient, compteCollectif: s)); } Navigator.pop(context); }, isFullWidth: true)])));
}

Future<void> _printProfessionalInvoice(BuildContext ctx, Invoice inv) async {
  final pdf = pw.Document(); pdf.addPage(pw.Page(build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Text("SANOGO & FRÈRE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
    pw.SizedBox(height: 20), pw.Text("Document N° : ${inv.numero}"), pw.Text("Tiers : ${inv.client.compteTiers}"),
    pw.SizedBox(height: 20), pw.TableHelper.fromTextArray(headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100), headers: ['Désignation', 'Qté', 'PU', 'Montant'], data: inv.lignes.map((l) => [l.product?.designation ?? "", l.quantite, formatPrice(l.prixUnitaire), formatPrice(l.montantHT)]).toList()),
    pw.SizedBox(height: 20), pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("TOTAL : ${formatPrice(inv.netAPayer)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
  ]))); await Printing.layoutPdf(onLayout: (f) async => pdf.save());
}

Widget _sectionHeader(IconData i, String t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Icon(i, color: const Color(0xFF1A237E), size: 20), const SizedBox(width: 8), Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E)))]));
Widget _roundedButton(String label, VoidCallback onTap, {bool isFullWidth = false}) => SizedBox(width: isFullWidth ? double.infinity : null, child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 15)), child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))));

class PlanComptableListScreen extends StatefulWidget { @override State<PlanComptableListScreen> createState() => _PlanState(); }
class _PlanState extends State<PlanComptableListScreen> { @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Plan Comptable")), body: ListView.builder(itemCount: globalPlanComptable.length, itemBuilder: (c, i) => ListTile(title: Text(globalPlanComptable[i].intitule), subtitle: Text(globalPlanComptable[i].numero)))); }
class DepotsListScreen extends StatelessWidget { @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Dépôts")), body: ListView.builder(itemCount: globalDepots.length, itemBuilder: (c, i) => ListTile(title: Text(globalDepots[i])))); }
class CreateDepotScreen extends StatelessWidget { @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Nouveau Dépôt"))); }
class CreateAccountScreen extends StatelessWidget { @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Nouveau Compte"))); }