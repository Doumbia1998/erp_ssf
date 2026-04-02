import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dashboard_home.dart';

void main() {
  runApp(const SSFApp());
}

// --- FONCTION DE FORMATAGE GLOBALE ---
String formatPrice(double price) {
  return NumberFormat('#,###', 'fr_FR').format(price).replaceAll(',', ' ') + " FCFA";
}

// --- 1. MODÈLES DE DONNÉES ---
class CompteComptable {
  final String numero;
  final String intitule;
  final String nature;
  CompteComptable({required this.numero, required this.intitule, required this.nature});
  @override
  String toString() => '$numero - $intitule';
}

class Product {
  String designation;
  double prixAchat;
  double prixVente;
  double stock;
  CompteComptable? compteComptable;
  Product({required this.designation, this.prixAchat = 0, this.prixVente = 0, this.stock = 0, this.compteComptable});
}

class Tiers {
  String compteTiers;
  String intitule;
  CompteComptable? compteCollectif;
  String adresse;
  String telephone;
  bool isClient;
  Tiers({required this.compteTiers, required this.intitule, this.compteCollectif, this.adresse = "", this.telephone = "", required this.isClient});
}

class InvoiceLine {
  Product? product;
  double quantite;
  double prixUnitaire;
  double remise;
  InvoiceLine({this.product, this.quantite = 0, this.prixUnitaire = 0, this.remise = 0});
  double get montantHT => (quantite * prixUnitaire) - remise;
}

class Invoice {
  String numero;
  DateTime date;
  Tiers client;
  List<InvoiceLine> lignes;
  double acompte;
  String modePaiement;
  String motifPaiement;
  Invoice({required this.numero, required this.date, required this.client, required this.lignes, this.acompte = 0, this.modePaiement = "Espèces", this.motifPaiement = ""});
  double get totalHT => lignes.fold(0.0, (sum, item) => sum + item.montantHT);
  double get netAPayer => totalHT - acompte;
}

class Payment {
  final String clientTiers;
  final double montant;
  final DateTime date;
  final String mode;
  final String motif;
  Payment({required this.clientTiers, required this.montant, required this.date, required this.mode, this.motif = ""});
}

// --- DONNÉES GLOBALES ---
List<CompteComptable> globalPlanComptable = [
  CompteComptable(numero: "70110000", intitule: "Ventes de marchandises", nature: "Produit"),
  CompteComptable(numero: "41100000", intitule: "Collectif Clients", nature: "Tiers"),
  CompteComptable(numero: "40100000", intitule: "Collectif Fournisseurs", nature: "Tiers"),
];
List<Product> globalProducts = [];
List<Tiers> globalTiers = [];
List<Invoice> globalInvoices = [];
List<Payment> globalPayments = [];
List<String> globalDepots = [];

class SSFApp extends StatelessWidget {
  const SSFApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSF - SOCIÉTÉ SANOGO & FRÈRE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  bool isCompanyTransport = false;
  String currentModule = "Dashboard";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SSF", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: isCompanyTransport ? "Logistique" : "Ventes",
              dropdownColor: const Color(0xFF1A237E),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              items: ["Ventes", "Logistique"].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (val) => setState(() => isCompanyTransport = val == "Logistique"),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1A237E)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- AFFICHAGE DU LOGO DANS LE MENU ---
                  Image.asset('assets/logo_ssf.png', height: 60, errorBuilder: (c, e, s) => const Icon(Icons.business, color: Colors.white, size: 50)),
                  const SizedBox(height: 10),
                  const Text("SANOGO & FRÈRE", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            _drawerItem(Icons.dashboard, "Dashboard"),
            _drawerItem(Icons.settings, "Structure (Articles, Tiers...)"),
            _drawerItem(Icons.assignment, "Documents des Ventes"),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _drawerItem(IconData icon, String title) {
    return ListTile(leading: Icon(icon), title: Text(title), selected: currentModule == title, onTap: () { setState(() => currentModule = title); Navigator.pop(context); });
  }

  Widget _buildBody() {
    if (isCompanyTransport) return const Center(child: Text("Module Transport Actif"));
    switch (currentModule) {
      case "Structure (Articles, Tiers...)": return const StructureModule();
      case "Documents des Ventes": return const SalesDocumentsModule();
      default: return const DashboardHome();
    }
  }
}

// --- STRUCTURE MODULE ---
class StructureModule extends StatelessWidget {
  const StructureModule({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStructureCard(context, "Plan Comptable", Icons.account_tree, const PlanComptableListScreen()),
        const SizedBox(height: 12),
        _buildStructureCard(context, "Articles", Icons.inventory_2, const ArticlesListScreen()),
        const SizedBox(height: 12),
        _buildStructureCard(context, "Clients", Icons.people, const TiersListScreen(isClient: true)),
        const SizedBox(height: 12),
        _buildStructureCard(context, "Fournisseurs", Icons.business_center, const TiersListScreen(isClient: false)),
        const SizedBox(height: 12),
        _buildStructureCard(context, "Dépôts de stockage", Icons.warehouse, const DepotsListScreen()),
      ],
    );
  }

  Widget _buildStructureCard(BuildContext context, String title, IconData icon, Widget screen) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
      child: ListTile(leading: Icon(icon, color: const Color(0xFF1A237E)), title: Text(title), trailing: const Icon(Icons.chevron_right, color: Color(0xFF1A237E)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => screen)),
      ),
    );
  }
}

// --- ARTICLES LIST ---
class ArticlesListScreen extends StatefulWidget {
  const ArticlesListScreen({super.key});
  @override State<ArticlesListScreen> createState() => _ArticlesListScreenState();
}
class _ArticlesListScreenState extends State<ArticlesListScreen> {
  String query = "";
  @override
  Widget build(BuildContext context) {
    final filtered = globalProducts.where((p) => p.designation.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text("Articles")),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8.0), child: TextField(onChanged: (v) => setState(() => query = v), decoration: InputDecoration(hintText: "Rechercher article...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))))),
        Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (context, i) => ListTile(title: Text(filtered[i].designation), trailing: Text(formatPrice(filtered[i].prixVente)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: filtered[i])))))),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateArticleScreen())).then((_) => setState(() {})), child: const Icon(Icons.add)),
    );
  }
}

// --- TIERS LIST ---
class TiersListScreen extends StatefulWidget {
  final bool isClient;
  const TiersListScreen({super.key, required this.isClient});
  @override State<TiersListScreen> createState() => _TiersListScreenState();
}
class _TiersListScreenState extends State<TiersListScreen> {
  String query = "";
  @override
  Widget build(BuildContext context) {
    final list = globalTiers.where((t) => t.isClient == widget.isClient && t.compteTiers.toLowerCase().contains(query.toLowerCase())).toList();
    double totalAchats = 0; double totalPaye = 0;
    for (var tier in list) {
      final tierInvoices = globalInvoices.where((inv) => inv.client.compteTiers == tier.compteTiers).toList();
      final tierPayments = globalPayments.where((p) => p.clientTiers == tier.compteTiers).toList();
      totalAchats += tierInvoices.fold(0.0, (sum, inv) => sum + inv.totalHT);
      totalPaye += tierInvoices.fold(0.0, (sum, inv) => sum + inv.acompte) + tierPayments.fold(0.0, (sum, p) => sum + p.montant);
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.isClient ? "Clients" : "Fournisseurs")),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8.0), child: TextField(onChanged: (v) => setState(() => query = v), decoration: InputDecoration(hintText: "Rechercher...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))))),
        if (widget.isClient) Container(width: double.infinity, margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL ACHATS", style: TextStyle(color: Colors.white, fontSize: 12)), Text(formatPrice(totalAchats), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
            const Divider(color: Colors.white24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL IMPAYÉS", style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)), Text(formatPrice(totalAchats - totalPaye), style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 15))]),
          ]),
        ),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (context, i) => ListTile(leading: Icon(widget.isClient ? Icons.person : Icons.business, color: Colors.blue), title: Text(list[i].compteTiers), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TiersDetailScreen(tiers: list[i])))))),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CreateTiersScreen(isClient: widget.isClient))).then((_) => setState(() {})), child: const Icon(Icons.add)),
    );
  }
}

// --- DÉTAILS ---
class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});
  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> history = [];
    for (var inv in globalInvoices) {
      for (var line in inv.lignes) {
        if (line.product?.designation == product.designation) { history.add({'date': inv.date, 'numero': inv.numero, 'client': inv.client.compteTiers, 'qte': line.quantite, 'total': line.montantHT}); }
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(product.designation)),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(20), color: Colors.blue.shade50, width: double.infinity, child: Column(children: [Text("Stock Actuel: ${product.stock.toStringAsFixed(0)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)), Text(product.designation)])),
        const Padding(padding: EdgeInsets.all(8.0), child: Text("Historique des ventes", style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(child: history.isEmpty ? const Center(child: Text("Aucune vente")) : ListView.builder(itemCount: history.length, itemBuilder: (context, i) => ListTile(title: Text("Facture ${history[i]['numero']} - ${history[i]['client']}"), subtitle: Text("${DateFormat('dd/MM/yyyy').format(history[i]['date'] as DateTime)} | Qté: ${history[i]['qte']}"), trailing: Text(formatPrice(history[i]['total'] as double), style: const TextStyle(fontWeight: FontWeight.bold))))),
      ]),
    );
  }
}

class TiersDetailScreen extends StatefulWidget {
  final Tiers tiers;
  const TiersDetailScreen({super.key, required this.tiers});
  @override State<TiersDetailScreen> createState() => _TiersDetailScreenState();
}
class _TiersDetailScreenState extends State<TiersDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final clientInvoices = globalInvoices.where((inv) => inv.client.compteTiers == widget.tiers.compteTiers).toList();
    final clientPayments = globalPayments.where((p) => p.clientTiers == widget.tiers.compteTiers).toList();
    double totalAchats = clientInvoices.fold(0.0, (sum, inv) => sum + inv.totalHT);
    double totalPaye = clientInvoices.fold(0.0, (sum, inv) => sum + inv.acompte) + clientPayments.fold(0.0, (sum, p) => sum + p.montant);
    return Scaffold(
      appBar: AppBar(title: Text("Compte : ${widget.tiers.intitule}")),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(15), color: const Color(0xFF1A237E).withOpacity(0.05), child: Column(children: [_row("Total ACHATS", formatPrice(totalAchats), Colors.black), _row("Total PAYÉ", formatPrice(totalPaye), Colors.green), const Divider(), _row("RESTE À PAYER", formatPrice(totalAchats - totalPaye), totalAchats - totalPaye > 0 ? Colors.red : Colors.green, isBold: true)])),
        Padding(padding: const EdgeInsets.all(10), child: _roundedButton("Effectuer un règlement", () => _showPaymentDialog(context))),
        Expanded(child: ListView(children: [
          ...clientInvoices.map((inv) => ListTile(title: Text("Facture ${inv.numero}"), subtitle: Text(DateFormat('dd/MM/yyyy').format(inv.date)), trailing: Text(formatPrice(inv.totalHT)))),
          ...clientPayments.map((p) => ListTile(title: Text("Règlement (${p.mode})"), subtitle: Text(DateFormat('dd/MM/yyyy').format(p.date)), trailing: Text("- ${formatPrice(p.montant)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))),
        ]))
      ]),
    );
  }
  void _showPaymentDialog(BuildContext context) {
    final controller = TextEditingController(); final mController = TextEditingController(); String sMode = "Espèces";
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(title: const Text("Nouveau Règlement"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: controller, decoration: const InputDecoration(labelText: "Montant"), keyboardType: TextInputType.number), const SizedBox(height: 10), DropdownButtonFormField<String>(value: sMode, items: ["Espèces", "Chèque", "Virement", "Orange Money", "MobiCash"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) => setDialogState(() => sMode = v!), decoration: const InputDecoration(labelText: "Mode")), if (sMode == "Chèque" || sMode == "Virement") Padding(padding: const EdgeInsets.only(top: 10), child: TextField(controller: mController, decoration: const InputDecoration(labelText: "Motif / Banque")))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")), ElevatedButton(onPressed: () { setState(() { globalPayments.add(Payment(clientTiers: widget.tiers.compteTiers, montant: double.parse(controller.text), date: DateTime.now(), mode: sMode, motif: mController.text)); }); Navigator.pop(context); }, child: const Text("Valider"))])));
  }
  Widget _row(String l, String v, Color c, {bool isBold = false}) { return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)), Text(v, style: TextStyle(color: c, fontWeight: FontWeight.bold))])); }
}

// --- LISTS & FORMS ---
class PlanComptableListScreen extends StatefulWidget { const PlanComptableListScreen({super.key}); @override State<PlanComptableListScreen> createState() => _PlanComptableListScreenState(); }
class _PlanComptableListScreenState extends State<PlanComptableListScreen> {
  String query = "";
  @override Widget build(BuildContext context) { final list = globalPlanComptable.where((c) => c.intitule.toLowerCase().contains(query.toLowerCase())).toList(); return Scaffold(appBar: AppBar(title: const Text("Plan Comptable")), body: Column(children: [Padding(padding: const EdgeInsets.all(8.0), child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(hintText: "Rechercher...", prefixIcon: Icon(Icons.search)))), Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (context, i) => ListTile(title: Text(list[i].intitule), subtitle: Text(list[i].numero))))],), floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateAccountScreen())).then((_) => setState(() {})), child: const Icon(Icons.add))); }
}
class DepotsListScreen extends StatefulWidget { const DepotsListScreen({super.key}); @override State<DepotsListScreen> createState() => _DepotsListScreenState(); }
class _DepotsListScreenState extends State<DepotsListScreen> {
  String query = "";
  @override Widget build(BuildContext context) { final list = globalDepots.where((d) => d.toLowerCase().contains(query.toLowerCase())).toList(); return Scaffold(appBar: AppBar(title: const Text("Dépôts")), body: Column(children: [Padding(padding: const EdgeInsets.all(8.0), child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(hintText: "Rechercher...", prefixIcon: Icon(Icons.search)))), Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (context, i) => ListTile(title: Text(list[i]))))],), floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateDepotScreen())).then((_) => setState(() {})), child: const Icon(Icons.add))); }
}

// FORMULAIRES
class CreateAccountScreen extends StatefulWidget { const CreateAccountScreen({super.key}); @override State<CreateAccountScreen> createState() => _CreateAccountScreenState(); }
class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _num = TextEditingController(); final _int = TextEditingController(); String _nature = "Produit";
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("SSF - Plan Comptable")), body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [TextField(controller: _num, decoration: const InputDecoration(hintText: "Compte Général")), const SizedBox(height: 10), TextField(controller: _int, decoration: const InputDecoration(hintText: "Intitulé")), const SizedBox(height: 10), Column(children: ["Produit", "Charge", "Tiers"].map((n) => RadioListTile<String>(title: Text(n), value: n, groupValue: _nature, onChanged: (v) => setState(() => _nature = v!))).toList()), const SizedBox(height: 30), _roundedButton("Enregistrer", () { globalPlanComptable.add(CompteComptable(numero: _num.text, intitule: _int.text, nature: _nature)); Navigator.pop(context); }, isFullWidth: true)])));
}
class CreateArticleScreen extends StatefulWidget { const CreateArticleScreen({super.key}); @override State<CreateArticleScreen> createState() => _CreateArticleScreenState(); }
class _CreateArticleScreenState extends State<CreateArticleScreen> {
  final _des = TextEditingController(); final _pa = TextEditingController(); final _pv = TextEditingController(); CompteComptable? _sel;
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("SSF - Nouvel Article")), body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [_sectionHeader(Icons.shopping_cart, "Informations de base"), TextField(controller: _des, decoration: const InputDecoration(labelText: "Désignation")), const SizedBox(height: 16), DropdownButtonFormField<CompteComptable>(decoration: const InputDecoration(labelText: "Compte Comptable"), items: globalPlanComptable.map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(), onChanged: (v) => _sel = v), const SizedBox(height: 24), _sectionHeader(Icons.monetization_on, "Prix"), Row(children: [Expanded(child: TextField(controller: _pa, decoration: const InputDecoration(labelText: "Prix Achat"), keyboardType: TextInputType.number)), const SizedBox(width: 16), Expanded(child: TextField(controller: _pv, decoration: const InputDecoration(labelText: "Prix Vente"), keyboardType: TextInputType.number))]), const SizedBox(height: 40), _roundedButton("CRÉER L'ARTICLE", () { globalProducts.add(Product(designation: _des.text, prixAchat: double.tryParse(_pa.text)??0, prixVente: double.tryParse(_pv.text)??0, compteComptable: _sel)); Navigator.pop(context); }, isFullWidth: true)])));
}
class CreateTiersScreen extends StatefulWidget { final bool isClient; const CreateTiersScreen({super.key, required this.isClient}); @override State<CreateTiersScreen> createState() => _CreateTiersScreenState(); }
class _CreateTiersScreenState extends State<CreateTiersScreen> {
  final _num = TextEditingController(); final _adr = TextEditingController(); final _tel = TextEditingController(); CompteComptable? _sel;
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.isClient ? "SSF - Client" : "SSF - Fournisseur")), body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [_sectionHeader(Icons.person, "Identité"), TextField(controller: _num, decoration: const InputDecoration(labelText: "Compte Tiers")), const SizedBox(height: 16), DropdownButtonFormField<CompteComptable>(decoration: const InputDecoration(labelText: "Compte Collectif"), items: globalPlanComptable.where((e)=>e.nature=="Tiers").map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(), onChanged: (v) => _sel = v), const SizedBox(height: 24), _sectionHeader(Icons.contact_phone, "Coordonnées"), TextField(controller: _adr, decoration: const InputDecoration(labelText: "Adresse")), const SizedBox(height: 16), TextField(controller: _tel, decoration: const InputDecoration(labelText: "Téléphone"), keyboardType: TextInputType.phone), const SizedBox(height: 40), _roundedButton("ENREGISTRER", () { globalTiers.add(Tiers(compteTiers: _num.text, intitule: _num.text, adresse: _adr.text, telephone: _tel.text, isClient: widget.isClient, compteCollectif: _sel)); Navigator.pop(context); }, isFullWidth: true)])));
}
class CreateDepotScreen extends StatefulWidget { const CreateDepotScreen({super.key}); @override State<CreateDepotScreen> createState() => _CreateDepotScreenState(); }
class _CreateDepotScreenState extends State<CreateDepotScreen> {
  final _int = TextEditingController();
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("SSF - Nouveau Dépôt")), body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [TextField(controller: _int, decoration: const InputDecoration(hintText: "Intitulé du Dépôt")), const SizedBox(height: 30), _roundedButton("CRÉER LE DÉPÔT", () { globalDepots.add(_int.text); Navigator.pop(context); }, isFullWidth: true)])),
  );
}

// DESIGN
Widget _sectionHeader(IconData icon, String title) { return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(children: [Icon(icon, color: const Color(0xFF1A237E), size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E)))])); }
Widget _roundedButton(String label, VoidCallback onTap, {bool isFullWidth = false}) { return SizedBox(width: isFullWidth ? double.infinity : null, child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 15), elevation: 0), child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)))); }

// MODULE VENTES
class SalesDocumentsModule extends StatefulWidget { const SalesDocumentsModule({super.key}); @override State<SalesDocumentsModule> createState() => _SalesDocumentsModuleState(); }
class _SalesDocumentsModuleState extends State<SalesDocumentsModule> {
  String _searchQuery = "";
  @override Widget build(BuildContext context) {
    final filtered = globalInvoices.where((inv) { final s = _searchQuery.toLowerCase(); return inv.numero.toLowerCase().contains(s) || inv.client.compteTiers.toLowerCase().contains(s); }).toList();
    double totalCA = filtered.fold(0.0, (sum, inv) => sum + inv.totalHT);
    return Scaffold(appBar: AppBar(title: const Text("Historique Factures"), automaticallyImplyLeading: false), body: Column(children: [Padding(padding: const EdgeInsets.all(8.0), child: TextField(onChanged: (v) => setState(() => _searchQuery = v), decoration: InputDecoration(hintText: "Rechercher...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))))), Container(width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TOTAL CA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text(formatPrice(totalCA), style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16))])), Expanded(child: filtered.isEmpty ? const Center(child: Text("Aucune facture")) : ListView.builder(itemCount: filtered.length, itemBuilder: (context, index) { final inv = filtered[index]; return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: ListTile(leading: const Icon(Icons.description, color: Colors.blue), title: Text("Facture ${inv.numero}"), subtitle: Text("${inv.client.compteTiers} - ${formatPrice(inv.totalHT)}"), trailing: const Icon(Icons.picture_as_pdf, color: Colors.red), onTap: () => _printProfessionalInvoice(context, inv))); }))],), floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateInvoiceScreen())).then((_) => setState(() {})), label: const Text("Nouvelle Facture"), icon: const Icon(Icons.add)));
  }
  Future<void> _printProfessionalInvoice(BuildContext context, Invoice invoice) async {
    final pdf = pw.Document();
    // Charge l'image du logo pour le PDF (optionnel mais recommandé)
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (pw.Context context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text("SSF", style: pw.TextStyle(fontSize: 45, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.Container(width: 320, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))), child: pw.Column(children: [
          pw.Text("SOCIETE SANOGO & FRERE", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.Text("Commerçant Import - Export - Transport", style: pw.TextStyle(fontSize: 10)),
          pw.Text("Tel : 67 63 64 47 / 70 12 68 14", style: pw.TextStyle(fontSize: 10)),
          pw.Text("BAMAKO - SOUGOUNI KOURA FACE STADE MODIBO KEITA", style: pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)
        ]))]),
      pw.SizedBox(height: 30), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Container(width: 180, child: pw.Table(border: pw.TableBorder.all(), children: [pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("N° Facture", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(invoice.numero))]), pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Date", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(DateFormat('dd/MM/yyyy').format(invoice.date)))])])), pw.Container(width: 250, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all()), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text("Client : ${invoice.client.compteTiers}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("Tel : ${invoice.client.telephone}"), pw.Text("Adresse : ${invoice.client.adresse}"), pw.Text("Locateur : FALADJE")]))]),
      pw.SizedBox(height: 30), pw.Text("FACTURE", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)), pw.SizedBox(height: 15),
      pw.TableHelper.fromTextArray(headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100), headers: ['Désignation', 'Qté', 'Px unitaire', 'Remise', 'Montant HT'], data: invoice.lignes.map((l) => [l.product?.designation ?? "", l.quantite.toStringAsFixed(0), formatPrice(l.prixUnitaire).replaceAll(" FCFA", ""), formatPrice(l.remise).replaceAll(" FCFA", ""), formatPrice(l.montantHT).replaceAll(" FCFA", "")]).toList()),
      pw.SizedBox(height: 20), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [pw.Container(width: 220, child: pw.Table(border: pw.TableBorder.all(), children: [pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Total")), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("${formatPrice(invoice.totalHT)}", textAlign: pw.TextAlign.right))]), pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Acompte")), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("${formatPrice(invoice.acompte)}", textAlign: pw.TextAlign.right))]), pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("Net à payer", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text("${formatPrice(invoice.netAPayer)}", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))])]))]),
      pw.SizedBox(height: 10), pw.Text("Règlement par : ${invoice.modePaiement} ${invoice.motifPaiement.isNotEmpty ? '(${invoice.motifPaiement})' : ''}", style: pw.TextStyle(fontSize: 10)), pw.Spacer(),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Pour acquit", style: pw.TextStyle(decoration: pw.TextDecoration.underline)), pw.Text("Le Fournisseur", style: pw.TextStyle(decoration: pw.TextDecoration.underline))]),
    ])));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}

// CRÉATION FACTURE
class CreateInvoiceScreen extends StatefulWidget { const CreateInvoiceScreen({super.key}); @override State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState(); }
class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final String _factureNo = "FA10000${globalInvoices.length + 22}"; Tiers? selectedClient; List<InvoiceLine> lines = [InvoiceLine()]; final acompteController = TextEditingController(text: "0"); String selectedMode = "Espèces"; final motifController = TextEditingController();
  double get calculateTotalHT => lines.fold(0.0, (sum, item) => sum + item.montantHT);
  double get netAPayer => calculateTotalHT - (double.tryParse(acompteController.text) ?? 0);
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFFFBFBFF), appBar: AppBar(title: Text("Saisie Facture $_factureNo"), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))), body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DropdownButtonFormField<Tiers>(decoration: const InputDecoration(labelText: "Sélectionner Client", filled: true, fillColor: Colors.white), items: globalTiers.where((t) => t.isClient).map((t) => DropdownMenuItem(value: t, child: Text(t.compteTiers))).toList(), onChanged: (v) => setState(() => selectedClient = v)),
      const SizedBox(height: 25), const Text("Articles / Produits", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 10),
      ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: lines.length, itemBuilder: (context, index) {
        return Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Column(children: [
          DropdownButtonFormField<Product>(decoration: const InputDecoration(labelText: "Choisir Article", border: InputBorder.none), items: globalProducts.map((p) => DropdownMenuItem(value: p, child: Text(p.designation))).toList(), onChanged: (p) { setState(() { lines[index].product = p; lines[index].prixUnitaire = p?.prixVente ?? 0; }); }),
          const Divider(), Row(children: [Expanded(child: TextField(decoration: const InputDecoration(labelText: "Qté"), keyboardType: TextInputType.number, onChanged: (v) => setState(() => lines[index].quantite = double.tryParse(v) ?? 0))), const SizedBox(width: 8), Expanded(child: TextField(decoration: const InputDecoration(labelText: "PU"), controller: TextEditingController(text: lines[index].prixUnitaire.toString()), keyboardType: TextInputType.number, onChanged: (v) => setState(() => lines[index].prixUnitaire = double.tryParse(v) ?? 0))), const SizedBox(width: 8), Expanded(child: TextField(decoration: const InputDecoration(labelText: "Remise"), keyboardType: TextInputType.number, onChanged: (v) => setState(() => lines[index].remise = double.tryParse(v) ?? 0)))])
        ]));
      }),
      TextButton.icon(onPressed: () => setState(() => lines.add(InvoiceLine())), icon: const Icon(Icons.add, size: 18), label: const Text("Ajouter une ligne", style: TextStyle(color: Color(0xFF1A237E)))),
      const Divider(height: 20), const Text("Mode de Règlement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      DropdownButtonFormField<String>(value: selectedMode, items: ["Espèces", "Chèque", "Virement", "Orange Money", "MobiCash"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) => setState(() => selectedMode = v!)),
      if (selectedMode == "Chèque" || selectedMode == "Virement") Padding(padding: const EdgeInsets.only(top: 10), child: TextField(controller: motifController, decoration: const InputDecoration(labelText: "Motif / Nom de la Banque"))),
      const Divider(height: 40), Align(alignment: Alignment.centerRight, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("Total HT : ${formatPrice(calculateTotalHT)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 10), SizedBox(width: 150, child: TextField(controller: acompteController, decoration: const InputDecoration(labelText: "Acompte"), keyboardType: TextInputType.number, onChanged: (v) => setState(() {}))), const SizedBox(height: 15), Text("NET À PAYER : ${formatPrice(netAPayer)}", style: const TextStyle(fontSize: 18, color: Colors.lightBlue, fontWeight: FontWeight.bold))])),
      const SizedBox(height: 40), _roundedButton("VALIDER ET ENREGISTRER", () { if (selectedClient != null) { globalInvoices.add(Invoice(numero: _factureNo, date: DateTime.now(), client: selectedClient!, lignes: List.from(lines), acompte: double.tryParse(acompteController.text) ?? 0, modePaiement: selectedMode, motifPaiement: motifController.text)); Navigator.pop(context); } }, isFullWidth: true),
    ])),
    );
  }
}