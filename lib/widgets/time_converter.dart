import 'package:flutter/material.dart';

/// Formats a DateTime like: "16 Jan, 25 7:00 PM"
class TimeConverter extends StatelessWidget {
  final DateTime? dateTime;
  final TextStyle? style;
  final TextAlign? textAlign;

  const TimeConverter({
    super.key,
    required this.dateTime,
    this.style,
    this.textAlign,
  });

  static const _months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
  ];

  static String format(DateTime dt) {
    final local = dt.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final mon = _months[(local.month - 1).clamp(0, 11)];
    final yy = (local.year % 100).toString().padLeft(2, '0');

    int hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? "PM" : "AM";

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return "$day $mon, $yy $hour:$minute $ampm";
  }

  @override
  Widget build(BuildContext context) {
    final dt = dateTime;
    final text = dt == null ? "-" : format(dt);

    return Text(
      text,
      textAlign: textAlign ?? TextAlign.end,
      style: style ??
          Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
    );
  }
}
