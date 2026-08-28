const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Compact relative timestamp for the conversation list: 'now', '2m',
/// '3h', 'yesterday', 'Aug 12', '12 Aug 2024'.
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 2) return 'yesterday';
  if (time.year == ref.year) return '${_months[time.month - 1]} ${time.day}';
  return '${time.day} ${_months[time.month - 1]} ${time.year}';
}