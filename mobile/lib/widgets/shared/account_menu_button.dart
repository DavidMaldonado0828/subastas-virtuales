import 'package:flutter/material.dart';

class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({
    required this.alias,
    required this.role,
    required this.onLogout,
    required this.onMyAuctions,
    this.onMyProducts,
    super.key,
  });

  final String alias;
  final String role;
  final VoidCallback onLogout;
  final VoidCallback onMyAuctions;
  final VoidCallback? onMyProducts;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Cuenta',
    onSelected: (value) {
      if (value == 'logout') onLogout();
      if (value == 'my-auctions') onMyAuctions();
      if (value == 'my-products') onMyProducts?.call();
    },
    itemBuilder: (context) => [
      PopupMenuItem<String>(
        value: 'account',
        child: SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alias,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              _RoleLabel(role: role),
            ],
          ),
        ),
      ),
      const PopupMenuDivider(),
      if (role == 'POSTOR')
        const PopupMenuItem<String>(
          value: 'my-auctions',
          child: Row(
            children: [
              Icon(Icons.list_alt_outlined),
              SizedBox(width: 12),
              Text('Mis subastas'),
            ],
          ),
        ),
      if (role == 'VENDEDOR')
        const PopupMenuItem<String>(
          value: 'my-products',
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined),
              SizedBox(width: 12),
              Text('Mis productos'),
            ],
          ),
        ),
      PopupMenuItem<String>(
        value: 'logout',
        child: Row(
          children: [
            const Icon(Icons.logout),
            const SizedBox(width: 12),
            const Text('Cerrar sesión'),
          ],
        ),
      ),
    ],
    child: Padding(
      padding: const EdgeInsets.only(right: 12, left: 4),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFFDBEAFE),
        child: Text(
          alias.trim().isEmpty ? '?' : alias.trim()[0].toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF1A73E8),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _RoleLabel extends StatelessWidget {
  const _RoleLabel({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      'ADMIN' => ('Administrador', const Color(0xFFEDE9FE)),
      'VENDEDOR' => ('Vendedor', const Color(0xFFFFEDD5)),
      _ => ('Participante', const Color(0xFFDBEAFE)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
