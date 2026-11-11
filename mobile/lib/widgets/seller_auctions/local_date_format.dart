String formatSellerDateTime(DateTime value) {
  final local = value.toLocal();
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour < 12 ? 'a. m.' : 'p. m.';
  return '${local.day} ${months[local.month - 1]} ${local.year}, $hour:$minute $suffix';
}

String formatSellerDate(DateTime value) {
  final local = value.toLocal();
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
