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
  String numero, intitule, nature;
  CompteComptable({required this.numero, required this.intitule, required this.nature});
  @override String toString() => '$numero - $intitule';
}

class Product {
  String designation;
  double prixAchat, prixVente;
  CompteComptable? compteComptable;
  Map<String, double> stocksParDepot = {};
  Product({required this.designation, this.prixAchat = 0, this.prixVente = 0, this.compteComptable});
  double get stockTotal => stocksParDepot.values.fold(0.0, (sum, qty) => sum + qty);
  double get stock => stockTotal;
  double getStockIn(String depotName) => stocksParDepot[depotName] ?? 0.0;
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
  double acompte, fraisTransport;
  String? depot;
  Invoice({required this.numero, required this.date, required this.client, required this.lignes, this.acompte = 0, this.fraisTransport = 0, this.modePaiement = "Espèces", this.motifPaiement = "", this.depot});
  double get totalHT => lignes.fold(0.0, (sum, item) => sum + item.montantHT);
  double get netAPayer => totalHT - acompte - fraisTransport;
}

class Payment {
  final String clientTiers, mode, motif;
  final double montant;
  final DateTime date;
  Payment({required this.clientTiers, required this.montant, required this.date, required this.mode, this.motif = ""});
}

// --- 2. DONNÉES GLOBALES ---
List<CompteComptable> globalPlanComptable = [
  CompteComptable(numero: "70110000", intitule: "Ventes de marchandises", nature: "Produit"),
  CompteComptable(numero: "41100000", intitule: "Clients Divers", nature: "Tiers"),
  CompteComptable(numero: "40100000", intitule: "Fournisseurs", nature: "Tiers"),
];
List<Product> globalProducts = [];
List<Tiers> globalTiers = [];
List<Invoice> globalInvoices = [];
List<Invoice> globalPurchases = [];
List<Payment> globalPayments = [];
List<String> globalDepots = ["Dépôt Principal"];

// --- 3. CONFIGURATION APP ---
class SSFApp extends StatelessWidget {
  const SSFApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'SSF GESTION', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)), useMaterial3: true),
    home: const LoginScreen(),
  );
}

// --- 4. DESIGN CONNEXION ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  @override Widget build(BuildContext context) => Scaffold(
    body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1976D2), Color(0xFF1565C0)])),
        child: Center(child: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(height: 50),
            Container(height: 100, width: 100, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Padding(padding: const EdgeInsets.all(15), child: Image.asset('assets/logo_ssf.png', errorBuilder: (c, e, s) => const Icon(Icons.business, size: 50, color: Color(0xFF1565C0))))),
            const SizedBox(height: 20),
            const Text("SSF VENTE", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(25), child: Column(children: [
                TextField(controller: _user, decoration: const InputDecoration(hintText: "Email Utilisateur", prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 15),
                TextField(controller: _pass, obscureText: _hide, decoration: InputDecoration(hintText: "Mot de passe", prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)))),
                const SizedBox(height: 30),
                _roundedButton("SE CONNECTER", () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const MainNavigation())), isFullWidth: true),
              ]))),
            ),
            const SizedBox(height: 40),
            const Text("Développer par @MLD Consulting", style: TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 20),
          ]),
        )))),
  );
}

// --- 5. NAVIGATION ---
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override State<MainNavigation> createState() => _MainNavigationState();
}
class _MainNavigationState extends State<MainNavigation> {
  bool isTransportMode = false;
  String currentModule = "Dashboard";
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(isTransportMode ? "TRANSPORT" : "SSF VENTE", style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white,
      actions: [DropdownButton<String>(value: isTransportMode ? "Transport" : "Ventes", dropdownColor: const Color(0xFF1A237E), underline: const SizedBox(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), items: const [DropdownMenuItem(value: "Ventes", child: Text("SSF VENTE")), DropdownMenuItem(value: "Transport", child: Text("TRANSPORT"))], onChanged: (val) => setState(() => isTransportMode = val == "Transport")), const SizedBox(width: 10)],
    ),
    drawer: Drawer(child: ListView(children: [
      DrawerHeader(decoration: const BoxDecoration(color: Color(0xFF1A237E)), child: Center(child: Text("GESTION SSF", style: const TextStyle(color: Colors.white, fontSize: 20)))),
      _drawerItem(Icons.dashboard, "Dashboard"), _drawerItem(Icons.settings, "Structure"), _drawerItem(Icons.assignment, "Documents des Ventes"), _drawerItem(Icons.shopping_cart, "Documents des Achats"), _drawerItem(Icons.payments, "Règlements Clients"),
      const Divider(), ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Déconnexion"), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen()))),
    ])),
    body: isTransportMode ? const TransportModule() : _buildBody(),
  );
  Widget _drawerItem(IconData i, String t) => ListTile(leading: Icon(i), title: Text(t), selected: currentModule == t, onTap: () { setState(() => currentModule = t); Navigator.pop(context); });
  Widget _buildBody() {
    switch (currentModule) {
      case "Structure": return const StructureModule();
      case "Documents des Ventes": return SalesDocumentsModule();
      case "Documents des Achats": return PurchaseDocumentsModule();
      case "Règlements Clients": return PaymentsReportModule();
      default: return const DashboardHome();
    }
  }
}

// --- 6. PLAN COMPTABLE ---
class PlanComptableListScreen extends StatefulWidget {
  @override State<PlanComptableListScreen> createState() => _PlanState();
}
class _PlanState extends State<PlanComptableListScreen> {
  String q = "";
  @override Widget build(BuildContext context) {
    final list = globalPlanComptable.where((c) => c.intitule.toLowerCase().contains(q.toLowerCase()) || c.numero.contains(q)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text("Plan Comptable"), backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => q = v), decoration: InputDecoration(hintText: "Rechercher un compte...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)), filled: true, fillColor: Colors.grey.shade50))),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(
          leading: CircleAvatar(backgroundColor: list[i].nature == "Produit" ? Colors.green : Colors.blue, child: Text(list[i].numero[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          title: Text(list[i].intitule, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("N° ${list[i].numero} • ${list[i].nature}"),
          trailing: IconButton(icon: const Icon(Icons.edit_note, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => CreateAccountScreen(accountToEdit: list[i]))).then((_) => setState(() {}))),
        ))),
      ]),
      floatingActionButton: FloatingActionButton(backgroundColor: const Color(0xFF1A237E), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CreateAccountScreen())).then((_) => setState(() {})), child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}

class CreateAccountScreen extends StatefulWidget {
  final CompteComptable? accountToEdit;
  const CreateAccountScreen({this.accountToEdit, super.key});
  @override State<CreateAccountScreen> createState() => _CreateAccountState();
}
class _CreateAccountState extends State<CreateAccountScreen> {
  late TextEditingController n, i; String nature = "Tiers";
  @override void initState() { super.initState(); n = TextEditingController(text: widget.accountToEdit?.numero ?? ""); i = TextEditingController(text: widget.accountToEdit?.intitule ?? ""); nature = widget.accountToEdit?.nature ?? "Tiers"; }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.accountToEdit == null ? "Nouveau Compte" : "Modifier Compte"), elevation: 0),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader(Icons.account_balance, "Informations Comptables"),
      const SizedBox(height: 20),
      TextField(controller: n, decoration: const InputDecoration(labelText: "Numéro de compte"), keyboardType: TextInputType.number),
      const SizedBox(height: 20),
      TextField(controller: i, decoration: const InputDecoration(labelText: "Intitule / Libellé")),
      const SizedBox(height: 20),
      DropdownButtonFormField<String>(value: nature, decoration: const InputDecoration(labelText: "Nature du compte"), items: ["Tiers", "Produit", "Charge", "Immo", "Banque"].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => nature = v!)),
      const SizedBox(height: 40),
      _roundedButton("VALIDER L'ENREGISTREMENT", () {
        if (n.text.isNotEmpty && i.text.isNotEmpty) {
          setState(() {
            if (widget.accountToEdit != null) {
              widget.accountToEdit!.numero = n.text; widget.accountToEdit!.intitule = i.text; widget.accountToEdit!.nature = nature;
            } else {
              globalPlanComptable.add(CompteComptable(numero: n.text, intitule: i.text, nature: nature));
            }
          });
          Navigator.pop(context);
        }
      }, isFullWidth: true),
    ])),
  );
}

// --- 7. ARTICLES & TIERS ---
class ArticlesListScreen extends StatefulWidget {
  @override State<ArticlesListScreen> createState() => _ArticlesListScreenState();
}
class _ArticlesListScreenState extends State<ArticlesListScreen> {
  String q = "";
  @override Widget build(BuildContext context) {
    final list = globalProducts.where((p) => p.designation.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(appBar: AppBar(title: const Text("Articles")), body: Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: "Rechercher...", prefixIcon: Icon(Icons.search)))),
      Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (context, i) => ListTile(title: Text(list[i].designation), subtitle: Text("Stock: ${list[i].stockTotal.toStringAsFixed(0)}"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(formatPrice(list[i].prixVente)), IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateArticleScreen(productToEdit: list[i]))).then((_) => setState(() {})))]), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProductDetailScreen(product: list[i])))))),
    ]), floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CreateArticleScreen())).then((_) => setState(() {})), child: const Icon(Icons.add)));
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
      tA += invs.fold(0.0, (s, i) => s + (i.totalHT - i.fraisTransport));
      tP += invs.fold(0.0, (s, i) => s + i.acompte) + pays.fold(0.0, (s, p) => s + p.montant);
    }
    return Scaffold(appBar: AppBar(title: Text(widget.isClient ? "Clients" : "Fournisseurs")), body: Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: "Rechercher...", prefixIcon: Icon(Icons.search)))),
      if (widget.isClient) Container(width: double.infinity, margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(12)), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL ACHATS (NET)", style: TextStyle(color: Colors.white, fontSize: 12)), Text(formatPrice(tA), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL IMPAYÉS", style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)), Text(formatPrice(tA - tP), style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))]),
      ])),
      Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(leading: Icon(widget.isClient ? Icons.person : Icons.business), title: Text(list[i].compteTiers), trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateTiersScreen(isClient: widget.isClient, tiersToEdit: list[i]))).then((_) => setState(() {}))), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TiersDetailScreen(tiers: list[i])))))),
    ]), floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateTiersScreen(isClient: widget.isClient))).then((_) => setState(() {})), child: const Icon(Icons.add)));
  }
}

// --- 8. STRUCTURE MODULE ---
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

class ProductDetailScreen extends StatelessWidget {
  final Product product; ProductDetailScreen({required this.product});
  @override Widget build(BuildContext context) {
    double tQ = 0, tCA = 0, tC = 0;
    for (var i in globalInvoices) { for (var l in i.lignes) { if (l.product?.designation == product.designation) { tQ += l.quantite; tCA += l.montantHT; tC += (l.quantite * product.prixAchat); } } }
    return Scaffold(appBar: AppBar(title: Text(product.designation)), body: Column(children: [
      Container(width: double.infinity, margin: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFDFF0D8), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        _rowDetail("Quantités Vendues", tQ.toStringAsFixed(0)), _rowDetail("Chiffre d'affaires", formatPrice(tCA)), _rowDetail("Marge", formatPrice(tCA - tC)), _rowDetail("Stock Actuel", product.stockTotal.toStringAsFixed(0)),
      ]))),
      const Padding(padding: EdgeInsets.all(8), child: Text("HISTORIQUE DES VENTES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
      Expanded(child: ListView(children: globalInvoices.where((i) => i.lignes.any((l) => l.product?.designation == product.designation)).map((i) => ListTile(title: Text("${i.client.compteTiers} (${i.depot})"), subtitle: Text(DateFormat('dd/MM/yyyy').format(i.date)), trailing: Text(formatPrice(i.totalHT)))).toList())),
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
    final paysList = globalPayments.where((p) => p.clientTiers == widget.tiers.compteTiers).toList();
    double tA = invoices.fold(0.0, (s, i) => s + (i.totalHT - i.fraisTransport));
    double tP = invoices.fold(0.0, (s, i) => s + i.acompte) + paysList.fold(0.0, (s, p) => s + p.montant);
    return Scaffold(appBar: AppBar(title: Text(widget.tiers.compteTiers)), body: Column(children: [
      Container(padding: const EdgeInsets.all(15), color: const Color(0xFF1A237E).withOpacity(0.05), child: Column(children: [_rSummary("Total dû (Net)", formatPrice(tA)), _rSummary("Payé", formatPrice(tP)), _rSummary("Reste à Payer", formatPrice(tA - tP), red: tA - tP > 0)])),
      Padding(padding: const EdgeInsets.all(10), child: _roundedButton("Effectuer un règlement", () => _showPaymentDialog(context))),
      Expanded(child: ListView(children: [...invoices.map((i) => ListTile(title: Text("Facture ${i.numero}"), subtitle: Text("Dépôt: ${i.depot}"), trailing: Text(formatPrice(i.totalHT - i.fraisTransport)))), ...paysList.map((p) => ListTile(title: Text("Règlement (${p.mode})"), subtitle: Text(p.motif), trailing: Text("- ${formatPrice(p.montant)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))))])),
    ]));
  }
  void _showPaymentDialog(BuildContext context) {
    final ctrl = TextEditingController(text: "0"); final mCtrl = TextEditingController(); String mode = "Espèces";
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(title: const Text("Nouveau Règlement"), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: ctrl, decoration: const InputDecoration(labelText: "Montant"), keyboardType: TextInputType.number, inputFormatters: [ThousandsSeparatorInputFormatter()], onTap: () => {if(ctrl.text=="0") ctrl.clear()}),
      DropdownButtonFormField<String>(value: mode, items: ["Espèces", "Chèque", "Virement"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) => setS(() => mode = v!), decoration: const InputDecoration(labelText: "Mode")),
      if (mode != "Espèces") TextField(controller: mCtrl, decoration: const InputDecoration(labelText: "Motif / Banque"))
    ]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annuler")), ElevatedButton(onPressed: () { if(ctrl.text.isNotEmpty) { setState(() { globalPayments.add(Payment(clientTiers: widget.tiers.compteTiers, montant: double.parse(ctrl.text.replaceAll(' ', '')), date: DateTime.now(), mode: mode, motif: mCtrl.text)); }); Navigator.pop(c); } }, child: const Text("Valider"))])));
  }
  Widget _rSummary(String l, String v, {bool red = false}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l), Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: red ? Colors.red : Colors.black))]);
}

// --- 9. FACTURATION UI ---
class SalesDocumentsModule extends StatefulWidget { @override State<SalesDocumentsModule> createState() => _SDMState(); }
class _SDMState extends State<SalesDocumentsModule> {
  String q = ""; @override Widget build(BuildContext context) {
    final list = globalInvoices.where((i) => i.numero.toLowerCase().contains(q.toLowerCase()) || i.client.compteTiers.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(appBar: AppBar(title: const Text("Ventes"), automaticallyImplyLeading: false), body: Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: "Rechercher...", prefixIcon: Icon(Icons.search)))),
      Container(width: double.infinity, margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL CA VENTES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(formatPrice(list.fold(0.0, (sum, inv) => sum + (inv.totalHT - inv.fraisTransport))), style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))])),
      Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(leading: const Icon(Icons.description, color: Colors.blue), title: Text("Facture ${list[i].numero}"), subtitle: Text("${list[i].client.compteTiers} (${list[i].depot})"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateInvoiceScreen(isAchat: false, invoiceToEdit: list[i]))).then((_) => setState(() {}))), IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red), onPressed: () => _printProfessionalInvoice(context, list[i]))]))))
    ]), floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CreateInvoiceScreen(isAchat: false))).then((_) => setState(() {})), label: const Text("Nouvelle Vente"), icon: const Icon(Icons.add)));
  }
}

class PurchaseDocumentsModule extends StatefulWidget { @override State<PurchaseDocumentsModule> createState() => _PDMState(); }
class _PDMState extends State<PurchaseDocumentsModule> {
  String q = ""; @override Widget build(BuildContext context) {
    final list = globalPurchases.where((i) => i.numero.toLowerCase().contains(q.toLowerCase()) || i.client.compteTiers.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(appBar: AppBar(title: const Text("Achats"), automaticallyImplyLeading: false), body: Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: "Rechercher...", prefixIcon: Icon(Icons.search)))),
      Container(width: double.infinity, margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL ACHATS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(formatPrice(list.fold(0.0, (sum, inv) => sum + inv.totalHT)), style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold))])),
      Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(leading: const Icon(Icons.shopping_basket, color: Colors.teal), title: Text("Achat ${list[i].numero}"), subtitle: Text("${list[i].client.compteTiers} (${list[i].depot})"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CreateInvoiceScreen(isAchat: true, invoiceToEdit: list[i]))).then((_) => setState(() {}))), IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red), onPressed: () => _printProfessionalInvoice(context, list[i]))]))))
    ]), floatingActionButton: FloatingActionButton.extended(backgroundColor: Colors.teal, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CreateInvoiceScreen(isAchat: true))).then((_) => setState(() {})), label: const Text("Nouvel Achat"), icon: const Icon(Icons.add, color: Colors.white)));
  }
}

class CreateInvoiceScreen extends StatefulWidget { final bool isAchat; final Invoice? invoiceToEdit; const CreateInvoiceScreen({required this.isAchat, this.invoiceToEdit, super.key}); @override State<CreateInvoiceScreen> createState() => _CISState(); }
class _CISState extends State<CreateInvoiceScreen> {
  late String s; Tiers? selC; String? selDepot; List<InvoiceLine> l = []; late TextEditingController ac, ft; String m = "Espèces";
  @override void initState() { super.initState(); s = widget.invoiceToEdit?.numero ?? "FA${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}"; selC = widget.invoiceToEdit?.client; selDepot = widget.invoiceToEdit?.depot; ac = TextEditingController(text: widget.invoiceToEdit?.acompte.toString().replaceAll('.0', '') ?? "0"); ft = TextEditingController(text: widget.invoiceToEdit?.fraisTransport.toString().replaceAll('.0', '') ?? "0"); m = widget.invoiceToEdit?.modePaiement ?? "Espèces"; l = widget.invoiceToEdit != null ? List.from(widget.invoiceToEdit!.lignes) : [InvoiceLine()]; }
  double get totalHT => l.fold(0.0, (sum, item) => sum + item.montantHT);
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.isAchat ? "Achat $s" : "Vente $s"), backgroundColor: widget.isAchat ? Colors.teal : const Color(0xFF1A237E)), body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    DropdownButtonFormField<Tiers>(value: selC, decoration: const InputDecoration(labelText: "Tiers"), items: globalTiers.where((t) => t.isClient == !widget.isAchat).map((t) => DropdownMenuItem(value: t, child: Text(t.compteTiers))).toList(), onChanged: (v) => setState(() => selC = v)),
    const SizedBox(height: 15), DropdownButtonFormField<String>(value: selDepot, decoration: const InputDecoration(labelText: "Sélectionner le Dépôt", prefixIcon: Icon(Icons.warehouse)), items: globalDepots.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(), onChanged: (v) => setState(() => selDepot = v)),
    const SizedBox(height: 20), const Text("Articles / Produits", style: TextStyle(fontWeight: FontWeight.bold)),
    ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: l.length, itemBuilder: (ctx, i) => InvoiceLineRow(line: l[i], isAchat: widget.isAchat, onUpdate: () => setState(() {}), currentDepot: selDepot)),
    TextButton.icon(onPressed: () => setState(() => l.add(InvoiceLine())), icon: const Icon(Icons.add), label: const Text("Ajouter ligne")),
    const Divider(), DropdownButtonFormField<String>(value: m, items: ["Espèces", "Chèque", "Virement", "MobiCash", "Orange Money"].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => m = v!), decoration: const InputDecoration(labelText: "Mode")),
    TextField(controller: ac, decoration: const InputDecoration(labelText: "Acompte Client"), inputFormatters: [ThousandsSeparatorInputFormatter()], keyboardType: TextInputType.number, onTap: () => {if(ac.text=="0") ac.clear()}, onChanged: (v) => setState(() {})),
    if(!widget.isAchat) TextField(controller: ft, decoration: const InputDecoration(labelText: "Frais Transport (Moins)", prefixIcon: Icon(Icons.local_shipping)), inputFormatters: [ThousandsSeparatorInputFormatter()], keyboardType: TextInputType.number, onTap: () => {if(ft.text=="0") ft.clear()}, onChanged: (v) => setState(() {})),
    const SizedBox(height: 20), Align(alignment: Alignment.centerRight, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("Total HT Articles : ${formatPrice(totalHT)}"), Text("NET À PAYER : ${formatPrice(totalHT - (double.tryParse(ac.text.replaceAll(' ', '')) ?? 0) - (double.tryParse(ft.text.replaceAll(' ', '')) ?? 0))}", style: const TextStyle(fontSize: 18, color: Colors.lightBlue, fontWeight: FontWeight.bold))])),
    const SizedBox(height: 30), _roundedButton("VALIDER", () { if (selC != null && selDepot != null) { if (!widget.isAchat) { for (var line in l) { if (line.product != null) { double stockDispo = line.product!.getStockIn(selDepot!); if (widget.invoiceToEdit != null && widget.invoiceToEdit!.depot == selDepot) { var al = widget.invoiceToEdit!.lignes.firstWhere((al) => al.product == line.product, orElse: () => InvoiceLine()); stockDispo += al.quantite; } if (line.quantite > stockDispo) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text("Stock insuffisant dans $selDepot pour ${line.product!.designation}. Dispo: ${stockDispo.toStringAsFixed(0)}"))); return; } } } } setState(() { if (widget.invoiceToEdit != null) { for (var line in widget.invoiceToEdit!.lignes) { if (line.product != null) { String d = widget.invoiceToEdit!.depot!; if (widget.isAchat) line.product!.stocksParDepot[d] = (line.product!.stocksParDepot[d] ?? 0) - line.quantite; else line.product!.stocksParDepot[d] = (line.product!.stocksParDepot[d] ?? 0) + line.quantite; } } } for (var line in l) { if (line.product != null) { if (widget.isAchat) line.product!.stocksParDepot[selDepot!] = (line.product!.stocksParDepot[selDepot!] ?? 0) + line.quantite; else line.product!.stocksParDepot[selDepot!] = (line.product!.stocksParDepot[selDepot!] ?? 0) - line.quantite; } } final newInv = Invoice(numero: s, date: DateTime.now(), client: selC!, lignes: List.from(l), acompte: double.tryParse(ac.text.replaceAll(' ', '')) ?? 0, fraisTransport: double.tryParse(ft.text.replaceAll(' ', '')) ?? 0, modePaiement: m, depot: selDepot); if (widget.invoiceToEdit != null) { globalPurchases.contains(widget.invoiceToEdit) ? globalPurchases[globalPurchases.indexOf(widget.invoiceToEdit!)] = newInv : globalInvoices[globalInvoices.indexOf(widget.invoiceToEdit!)] = newInv; } else { if (widget.isAchat) globalPurchases.add(newInv); else globalInvoices.add(newInv); } }); Navigator.pop(context); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sélectionnez Tiers ET Dépôt"))); } }, isFullWidth: true),
  ])));
}

class InvoiceLineRow extends StatefulWidget {
  final InvoiceLine line; final bool isAchat; final VoidCallback onUpdate; final String? currentDepot;
  InvoiceLineRow({required this.line, required this.isAchat, required this.onUpdate, this.currentDepot, super.key});
  @override State<InvoiceLineRow> createState() => _ILRState();
}
class _ILRState extends State<InvoiceLineRow> {
  late TextEditingController q, p, r;
  @override void initState() { super.initState(); q = TextEditingController(text: widget.line.quantite.toString().replaceAll('.0', '')); p = TextEditingController(text: widget.line.prixUnitaire.toString().replaceAll('.0', '')); r = TextEditingController(text: widget.line.remise.toString().replaceAll('.0', '')); }
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Column(children: [
    DropdownButtonFormField<Product>(value: widget.line.product, decoration: const InputDecoration(labelText: "Article", border: InputBorder.none), items: globalProducts.map((p) => DropdownMenuItem(value: p, child: Text("${p.designation} (Stock ${widget.currentDepot ?? 'Total'}: ${widget.currentDepot != null ? p.getStockIn(widget.currentDepot!).toStringAsFixed(0) : p.stockTotal.toStringAsFixed(0)})"))).toList(), onChanged: (v) => setState(() { widget.line.product = v; widget.line.prixUnitaire = widget.isAchat ? (v?.prixAchat ?? 0) : (v?.prixVente ?? 0); p.text = widget.line.prixUnitaire.toString().replaceAll('.0', ''); widget.onUpdate(); })),
    Row(children: [Expanded(child: TextField(controller: q, decoration: const InputDecoration(labelText: "Qté"), keyboardType: TextInputType.number, onTap: () => {if(q.text=="0") q.clear()}, onChanged: (v) { widget.line.quantite = double.tryParse(v) ?? 0; widget.onUpdate(); })), const SizedBox(width: 8), Expanded(child: TextField(controller: p, decoration: const InputDecoration(labelText: "PU"), keyboardType: TextInputType.number, inputFormatters: [ThousandsSeparatorInputFormatter()], onTap: () => {if(p.text=="0") p.clear()}, onChanged: (v) { widget.line.prixUnitaire = double.tryParse(v.replaceAll(' ', '')) ?? 0; widget.onUpdate(); })), if (!widget.isAchat) const SizedBox(width: 8), if (!widget.isAchat) Expanded(child: TextField(controller: r, decoration: const InputDecoration(labelText: "Remise"), inputFormatters: [ThousandsSeparatorInputFormatter()], keyboardType: TextInputType.number, onTap: () => {if(r.text=="0") r.clear()}, onChanged: (v) { widget.line.remise = double.tryParse(v.replaceAll(' ', '')) ?? 0; widget.onUpdate(); })),])
  ]));
}

// --- 10. CRÉATIONS ---
class CreateArticleScreen extends StatefulWidget { final Product? productToEdit; const CreateArticleScreen({this.productToEdit, super.key}); @override State<CreateArticleScreen> createState() => _CASState(); }
class _CASState extends State<CreateArticleScreen> {
  late TextEditingController d, pa, pv; CompteComptable? s;
  @override void initState() { super.initState(); d = TextEditingController(text: widget.productToEdit?.designation ?? ""); pa = TextEditingController(text: widget.productToEdit?.prixAchat.toString().replaceAll('.0', '') ?? "0"); pv = TextEditingController(text: widget.productToEdit?.prixVente.toString().replaceAll('.0', '') ?? "0"); s = widget.productToEdit?.compteComptable; }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.productToEdit == null ? "Nouvel Article" : "Modifier Article")), body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_sectionHeader(Icons.shopping_cart, "Détails"), TextField(controller: d, decoration: const InputDecoration(labelText: "Désignation")), DropdownButtonFormField<CompteComptable>(value: s, items: globalPlanComptable.map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(), onChanged: (v) => s = v, decoration: const InputDecoration(labelText: "Compte")), Row(children: [Expanded(child: TextField(controller: pa, decoration: const InputDecoration(labelText: "Prix Achat"), inputFormatters: [ThousandsSeparatorInputFormatter()], keyboardType: TextInputType.number, onTap: () { if(pa.text == "0") pa.clear(); })), const SizedBox(width: 10), Expanded(child: TextField(controller: pv, decoration: const InputDecoration(labelText: "Prix Vente"), inputFormatters: [ThousandsSeparatorInputFormatter()], keyboardType: TextInputType.number, onTap: () { if(pv.text == "0") pv.clear(); }))]), const SizedBox(height: 30), _roundedButton("VALIDER", () { if (widget.productToEdit != null) { widget.productToEdit!.designation = d.text; widget.productToEdit!.prixAchat = double.tryParse(pa.text.replaceAll(' ', '')) ?? 0; widget.productToEdit!.prixVente = double.tryParse(pv.text.replaceAll(' ', '')) ?? 0; widget.productToEdit!.compteComptable = s; } else { globalProducts.add(Product(designation: d.text, prixAchat: double.tryParse(pa.text.replaceAll(' ', ''))??0, prixVente: double.tryParse(pv.text.replaceAll(' ', ''))??0, compteComptable: s)); } Navigator.pop(context); }, isFullWidth: true)])));
}

class CreateTiersScreen extends StatefulWidget { final bool isClient; final Tiers? tiersToEdit; const CreateTiersScreen({required this.isClient, this.tiersToEdit, super.key}); @override State<CreateTiersScreen> createState() => _CTSState(); }
class _CTSState extends State<CreateTiersScreen> {
  late TextEditingController n, a, t; CompteComptable? s;
  @override void initState() { super.initState(); n = TextEditingController(text: widget.tiersToEdit?.compteTiers ?? ""); a = TextEditingController(text: widget.tiersToEdit?.adresse ?? ""); t = TextEditingController(text: widget.tiersToEdit?.telephone ?? ""); s = widget.tiersToEdit?.compteCollectif; }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.tiersToEdit == null ? "Nouveau Tiers" : "Modifier Tiers")), body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_sectionHeader(Icons.person, "Identité"), TextField(controller: n, decoration: const InputDecoration(labelText: "Nom / Compte Tiers")), DropdownButtonFormField<CompteComptable>(value: s, items: globalPlanComptable.where((e)=>e.nature=="Tiers").map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(), onChanged: (v) => s = v, decoration: const InputDecoration(labelText: "Compte Collectif")), TextField(controller: a, decoration: const InputDecoration(labelText: "Adresse")), TextField(controller: t, decoration: const InputDecoration(labelText: "Téléphone"), keyboardType: TextInputType.phone), _roundedButton("VALIDER", () { if (widget.tiersToEdit != null) { widget.tiersToEdit!.compteTiers = n.text; widget.tiersToEdit!.intitule = n.text; widget.tiersToEdit!.adresse = a.text; widget.tiersToEdit!.telephone = t.text; widget.tiersToEdit!.compteCollectif = s; } else { globalTiers.add(Tiers(compteTiers: n.text, intitule: n.text, adresse: a.text, telephone: t.text, isClient: widget.isClient, compteCollectif: s)); } Navigator.pop(context); }, isFullWidth: true)])));
}

// --- 11. PDF & IMPRESSION ---
Future<void> _printProfessionalInvoice(BuildContext ctx, Invoice inv) async {
  final pdf = pw.Document();
  double totalRemise = inv.lignes.fold(0.0, (sum, l) => sum + l.remise);

  pdf.addPage(pw.Page(build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Text("SANOGO & FRÈRE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
    pw.SizedBox(height: 20), pw.Text("Document N° : ${inv.numero}"), pw.Text("Tiers : ${inv.client.compteTiers}"),
    pw.Text("Dépôt : ${inv.depot ?? 'Non spécifié'}"),
    pw.SizedBox(height: 20),
    pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      headers: ['Désignation', 'Qté', 'PU', 'Remise', 'Montant'],
      data: inv.lignes.map((l) => [
        l.product?.designation ?? "",
        l.quantite.toStringAsFixed(0),
        formatPrice(l.prixUnitaire),
        formatPrice(l.remise),
        formatPrice(l.montantHT)
      ]).toList()
    ),
    pw.SizedBox(height: 10),
    if(totalRemise > 0) pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Total Remise : - ${formatPrice(totalRemise)}", style: pw.TextStyle(color: PdfColors.green))),
    if(inv.fraisTransport > 0) pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Frais Transport : - ${formatPrice(inv.fraisTransport)}", style: pw.TextStyle(color: PdfColors.red))),
    if(inv.acompte > 0) pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Acompte payé : ${formatPrice(inv.acompte)}")),
    pw.SizedBox(height: 10),
    pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("NET À PAYER : ${formatPrice(inv.netAPayer)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))),
  ]))); await Printing.layoutPdf(onLayout: (f) async => pdf.save());
}

Widget _sectionHeader(IconData i, String t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Icon(i, color: const Color(0xFF1A237E), size: 20), const SizedBox(width: 8), Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E)))]));
Widget _roundedButton(String label, VoidCallback onTap, {bool isFullWidth = false, Color color = const Color(0xFF1A237E)}) => SizedBox(width: isFullWidth ? double.infinity : null, child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 15)), child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))));

class DepotsListScreen extends StatelessWidget { @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Dépôts")), body: ListView.builder(itemCount: globalDepots.length, itemBuilder: (c, i) => ListTile(title: Text(globalDepots[i]))), floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CreateDepotScreen())), child: const Icon(Icons.add))); }
class CreateDepotScreen extends StatefulWidget { const CreateDepotScreen({super.key}); @override State<CreateDepotScreen> createState() => _CDSState(); }
class _CDSState extends State<CreateDepotScreen> { final i = TextEditingController(); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Nouveau Dépôt")), body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [TextField(controller: i, decoration: const InputDecoration(labelText: "Nom du Dépôt")), const SizedBox(height: 20), _roundedButton("CRÉER LE DÉPÔT", () { globalDepots.add(i.text); Navigator.pop(context); }, isFullWidth: true)]))); }

class PaymentsReportModule extends StatefulWidget {
  const PaymentsReportModule({super.key});
  @override State<PaymentsReportModule> createState() => _PaymentsReportModuleState();
}
class _PaymentsReportModuleState extends State<PaymentsReportModule> {
  DateTimeRange? selectedRange;
  @override Widget build(BuildContext context) {
    List<Payment> filtered = globalPayments;
    if (selectedRange != null) {
      filtered = globalPayments.where((p) => p.date.isAfter(selectedRange!.start.subtract(const Duration(days: 1))) && p.date.isBefore(selectedRange!.end.add(const Duration(days: 1)))).toList();
    }
    double total = filtered.fold(0.0, (sum, p) => sum + p.montant);
    return Scaffold(
      appBar: AppBar(title: const Text("Règlements Clients"), automaticallyImplyLeading: false, actions: [
        IconButton(icon: const Icon(Icons.calendar_month), onPressed: () async {
          final range = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDateRange: selectedRange);
          if (range != null) setState(() => selectedRange = range);
        }),
        IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () => _printPaymentsReport(context, filtered)),
      ]),
      body: Column(children: [
        Container(width: double.infinity, margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(12)), child: Column(children: [
          Text(selectedRange == null ? "TOTAL ENCAISSÉ (HISTORIQUE)" : "ENCAISSÉ SUR LA PÉRIODE", style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(formatPrice(total), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ])),
        Expanded(child: filtered.isEmpty ? const Center(child: Text("Aucun règlement")) : ListView.builder(itemCount: filtered.length, itemBuilder: (c, i) => ListTile(leading: const Icon(Icons.payment, color: Colors.green), title: Text(filtered[i].clientTiers), subtitle: Text("${DateFormat('dd/MM/yyyy').format(filtered[i].date)} - ${filtered[i].mode}"), trailing: Text(formatPrice(filtered[i].montant), style: const TextStyle(fontWeight: FontWeight.bold))))),
      ]),
    );
  }
  Future<void> _printPaymentsReport(BuildContext context, List<Payment> payments) async {
    final pdf = pw.Document(); final dateFormat = DateFormat('dd/MM/yyyy');
    pdf.addPage(pw.MultiPage(build: (pw.Context context) => [
      pw.Header(level: 0, child: pw.Text("RAPPORT DES ENCAISSEMENTS - SSF VENTE")),
      pw.TableHelper.fromTextArray(headers: ['Date', 'Client', 'Mode', 'Montant'], data: payments.map((p) => [dateFormat.format(p.date), p.clientTiers, p.mode, formatPrice(p.montant)]).toList()),
      pw.SizedBox(height: 20),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("TOTAL : ${formatPrice(payments.fold(0.0, (s, p) => s + p.montant))}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
