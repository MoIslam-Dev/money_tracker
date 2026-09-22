import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../utils/money.dart';

/// Friendly amount text with optional color.
class MoneyText extends StatelessWidget {
  final int amount;
  final bool expenseColor;
  final TextStyle? style;
  final bool showSign;
  const MoneyText(this.amount,
      {super.key, this.expenseColor = false, this.style, this.showSign = false});

  @override
  Widget build(BuildContext context) {
    final effective = style ?? Theme.of(context).textTheme.titleMedium;
    final color = expenseColor
        ? AppColors.expenseOn(context)
        : style?.color ??
            Theme.of(context).colorScheme.onSurface;
    final prefix = showSign ? (amount >= 0 ? '+' : '') : '';
    return Text(
      '$prefix${formatDA(amount)}',
      style: effective?.copyWith(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: t.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(title,
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        ),
        if (actionText != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionText!)),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onPressed;
  const EmptyState({
    super.key,
    this.icon = Icons.savings_outlined,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: t.colorScheme.primaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: t.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            if (buttonLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.add),
                label: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Large numeric amount input used in transaction forms.
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  const AmountField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final parsed = parseAmount(value.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: const [],
              textAlign: TextAlign.center,
              style: t.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: t.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: t.colorScheme.outline.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
              onChanged: (raw) {
                final cleaned = sanitizeAmountText(raw);
                if (cleaned != raw) {
                  controller.value = TextEditingValue(
                    text: cleaned,
                    selection: TextSelection.collapsed(offset: cleaned.length),
                  );
                }
                onChanged?.call(cleaned);
              },
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                parsed == null ? '0 DA' : formatDA(parsed),
                style: t.textTheme.labelLarge?.copyWith(
                    color: parsed == null
                        ? t.colorScheme.outline
                        : t.colorScheme.primary,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}

class MonthSelector extends StatelessWidget {
  final DateTime month;
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const MonthSelector({
    super.key,
    required this.month,
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class LevelBar extends StatelessWidget {
  final double value; // 0..1+
  final Color? color;
  const LevelBar({super.key, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final pct = value.clamp(0.0, 1.0);
    final c = color ??
        (value >= 1
            ? AppColors.expenseOn(context)
            : value >= 0.8
                ? AppColors.amberOn(context)
                : t.colorScheme.primary);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: pct,
        minHeight: 8,
        backgroundColor: t.colorScheme.surfaceContainerHighest,
        color: c,
      ),
    );
  }
}

/// Colored dot used for bullet lists.
class CatDot extends StatelessWidget {
  final Color color;
  const CatDot(this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class DonutChart extends StatelessWidget {
  final List<(String, int, Color)> slices;
  const DonutChart({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (slices.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text('—',
              style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.outline)),
        ),
      );
    }
    final total = slices.fold<int>(0, (a, b) => a + b.$2);
    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          sections: slices.map((s) {
            final fraction = total == 0 ? 0.0 : s.$2 / total;
            return PieChartSectionData(
              value: fraction,
              color: s.$3,
              radius: Math.min(44.0, 50.0),
              title: fraction > 0.03 ? '${(fraction * 100).toStringAsFixed(0)}%' : '',
              titleStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: s.$3.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
              ),
            );
          }).toList(),
          centerSpaceRadius: 52,
          sectionsSpace: 3,
          startDegreeOffset: -90,
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      ),
    );
  }
}

class TrendBars extends StatelessWidget {
  final List<(String, int, int)> series; // dateKey, income, expense
  final Color incomeColor;
  final Color expenseColor;
  const TrendBars({super.key, required this.series, required this.incomeColor, required this.expenseColor});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (series.isEmpty) return const SizedBox.shrink();
    final maxV = series.fold<int>(1, (m, e) => m > (e.$2 > e.$3 ? e.$2 : e.$3) ? m : (e.$2 > e.$3 ? e.$2 : e.$3));
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < series.length; i++) {
      final (_, inc, exp) = series[i];
      groups.add(BarChartGroupData(
        x: i,
        barsSpace: 2,
        barRods: [
          if (exp > 0)
            BarChartRodData(toY: exp.toDouble(),
                color: expenseColor, width: 7, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
          if (inc > 0)
            BarChartRodData(toY: inc.toDouble(),
                color: incomeColor, width: 7, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
        ],
      ));
    }
    final showStep = (series.length / 7).ceil();
    return BarChart(
      BarChartData(
        maxY: maxV.toDouble() * 1.2,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxV / 4).clamp(1, maxV)).toDouble(),
          getDrawingHorizontalLine: (_) => FlLine(
            color: t.colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) => Text(
                formatDAShort(v.toInt()),
                style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.outline),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= series.length || idx % showStep != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _shortLabel(series[idx].$1),
                    style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.outline),
                  ),
                );
              },
              reservedSize: 26,
            ),
          ),
        ),
        barGroups: groups,
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  String _shortLabel(String dateKey) {
    final parts = dateKey.split('-');
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return '$d/${m < 10 ? '0$m' : '$m'}';
  }
}

/// Straight line chart for income vs expenses over months.
class TrendLine extends StatelessWidget {
  final List<(String, int)> income;
  final List<(String, int)> expense;
  const TrendLine({super.key, required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final all = [...income, ...expense];
    if (all.isEmpty) return const SizedBox.shrink();
    final maxV = all.fold<int>(1, (m, e) => e.$2 > m ? e.$2 : m);

    List<FlSpot> spots(List<(String, int)> list) =>
        [for (var i = 0; i < list.length; i++) FlSpot(i.toDouble(), list[i].$2.toDouble())];

    return LineChart(
      LineChartData(
        maxY: maxV * 1.2,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: t.colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) => Text(
                formatDAShort(v.toInt()),
                style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.outline),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= income.length) return const SizedBox.shrink();
                final parts = income[idx].$1.split('-');
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    monthShort(int.parse(parts[1]), 'en'),
                    style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.outline),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots(income),
            isCurved: true,
            color: AppColors.incomeOn(context),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: spots(expense),
            isCurved: true,
            color: AppColors.expenseOn(context),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }
}

/// Single-series cumulative line with a soft area fill (e.g. net cash-flow).
class BalanceTrend extends StatelessWidget {
  final List<(String, int)> series;
  final String lang;
  const BalanceTrend({super.key, required this.series, this.lang = 'en'});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (series.isEmpty) return const SizedBox.shrink();
    final lo = series.fold<int>(0, (m, e) => e.$2 < m ? e.$2 : m);
    final hi = series.fold<int>(0, (m, e) => e.$2 > m ? e.$2 : m);
    var pad = ((hi - lo) * 0.18).round();
    if (pad < 1) pad = 1;

    return LineChart(
      LineChartData(
        minY: (lo - pad).toDouble(),
        maxY: (hi + pad).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: t.colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) => Text(
                formatDAShort(v.toInt()),
                style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.outline),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= series.length) return const SizedBox.shrink();
                final parts = series[idx].$1.split('-');
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    monthShort(int.parse(parts[1]), lang),
                    style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.outline),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < series.length; i++)
                FlSpot(i.toDouble(), series[i].$2.toDouble())
            ],
            isCurved: true,
            curveSmoothness: 0.35,
            color: t.colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  t.colorScheme.primary.withValues(alpha: 0.35),
                  t.colorScheme.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }
}

/// Primary action button with full width.
class BigButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  const BigButton({super.key, required this.label, this.onPressed, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.primary;
    final fg = color == null
        ? scheme.onPrimary
        : (bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(double.infinity, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      onPressed: onPressed,
      child: icon == null ? Text(label) : Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon), const SizedBox(width: 8), Text(label)]),
    );
  }
}

/// Static helper alias so Math.min works without importing dart:math inline.
// ignore: public_member_api_docs
class Math {
  static double min(double a, double b) => a < b ? a : b;
}