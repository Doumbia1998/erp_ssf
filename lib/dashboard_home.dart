import 'package:flutter/material.dart';
import 'main.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  @override
  Widget build(BuildContext context) {
    // --- LOGIQUE DE CALCUL DES STATISTIQUES RÉELLES ---

    // 1. Chiffre d'affaire total
    double totalCA = globalInvoices.fold(0.0, (sum, inv) => sum + inv.totalHT);

    // 2. Total Paye (Acomptes sur factures + règlements libres)
    double totalAcomptes = globalInvoices.fold(0.0, (sum, inv) => sum + inv.acompte);
    double totalReglements = globalPayments.fold(0.0, (sum, p) => sum + p.montant);
    double totalPaye = totalAcomptes + totalReglements;

    // 3. Total Impayés
    double totalImpayes = totalCA - totalPaye;

    // 4. Stock Faible
    int stockFaible = globalProducts.where((p) => p.stock <= 5).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SOCIÉTÉ SANOGO & FRÈRE", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
          const Text("Tableau de bord Global", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
          const SizedBox(height: 25),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.1,
            children: [
              _buildStatCard("Chiffre d'Affaire", formatPrice(totalCA), Icons.trending_up, Colors.blue,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesDocumentsModule())).then((_) => setState(() {}))),
              _buildStatCard("Total Encaissé", formatPrice(totalPaye), Icons.check_circle_outline, Colors.green,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TiersListScreen(isClient: true))).then((_) => setState(() {}))),
              _buildStatCard("Total Impayés", formatPrice(totalImpayes), Icons.warning_amber_rounded, Colors.red,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TiersListScreen(isClient: true))).then((_) => setState(() {}))),
              _buildStatCard("Stock Faible", "$stockFaible articles", Icons.inventory_2_outlined, Colors.orange,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ArticlesListScreen())).then((_) => setState(() {}))),
            ],
          ),

          const SizedBox(height: 30),
          const Text("Dernières Factures", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
          const SizedBox(height: 15),

          globalInvoices.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Aucune donnée disponible", style: TextStyle(color: Colors.grey))))
              : Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: globalInvoices.length > 5 ? 5 : globalInvoices.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final inv = globalInvoices.reversed.toList()[index];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(Icons.description, color: Color(0xFF1A237E), size: 20)),
                  title: Text(inv.numero, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(inv.client.compteTiers),
                  trailing: Text(formatPrice(inv.netAPayer), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 28),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ]),
          ],
        ),
      ),
    );
  }
}