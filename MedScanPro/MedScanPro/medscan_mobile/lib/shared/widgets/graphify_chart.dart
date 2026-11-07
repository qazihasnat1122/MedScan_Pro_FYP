import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Data point model for the Graphify chart
class GraphifyDataPoint {
  final String dayLabel; // e.g. 'Mon'
  final double adherenceRate; // 0.0 to 1.0 (e.g. 0.95 = 95%)
  final int dosesTaken;
  final int dosesScheduled;
  final String statusDetail; // e.g. '2/2 Taken on schedule'

  const GraphifyDataPoint({
    required this.dayLabel,
    required this.adherenceRate,
    required this.dosesTaken,
    required this.dosesScheduled,
    required this.statusDetail,
  });
}

/// A premium, interactive medicine adherence and health data visualization
/// widget built with smooth bezier curves, gradient fills, and touch inspection.
class GraphifyAdherenceChart extends StatefulWidget {
  final List<GraphifyDataPoint>? dataPoints;
  final String title;
  final String subtitle;
  final VoidCallback? onDetailsTap;

  const GraphifyAdherenceChart({
    super.key,
    this.dataPoints,
    this.title = 'Medicine Adherence',
    this.subtitle = 'Weekly compliance & dose intake',
    this.onDetailsTap,
  });

  @override
  State<GraphifyAdherenceChart> createState() => _GraphifyAdherenceChartState();
}

class _GraphifyAdherenceChartState extends State<GraphifyAdherenceChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _curveAnimation;
  int _selectedIndex = 4; // Default to Friday or current day

  late final List<GraphifyDataPoint> _points;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _curveAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();

    // Populate points only if real data points are provided
    _points = widget.dataPoints != null
        ? List.from(widget.dataPoints!)
        : const [];
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  double get _averageAdherence {
    if (_points.isEmpty) return 0.0;
    final sum = _points.fold(0.0, (acc, p) => acc + p.adherenceRate);
    return sum / _points.length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    if (_points.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppColors.subtleShadow,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.show_chart_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Icon(
              Icons.event_note_outlined,
              size: 40,
              color: textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No Dose History Yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add medicines and record daily doses to monitor adherence and compliance trends.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: textMuted, height: 1.4),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    final selectedPoint = _points[_selectedIndex.clamp(0, _points.length - 1)];
    final percentStr = '${(_averageAdherence * 100).toInt()}%';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : AppColors.subtleShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row: Title & Adherence Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.show_chart_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
              // Compliance KPI Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.emerald.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.emerald,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$percentStr Rate',
                      style: const TextStyle(
                        color: AppColors.emerald,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Interactive Graphify Bezier Canvas
          SizedBox(
            height: 120,
            child: AnimatedBuilder(
              animation: _curveAnimation,
              builder: (context, child) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTapDown: (details) {
                        final widthPerPoint =
                            constraints.maxWidth / (_points.length - 1);
                        final index = (details.localPosition.dx / widthPerPoint)
                            .round();
                        setState(() {
                          _selectedIndex = index.clamp(0, _points.length - 1);
                        });
                      },
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, 120),
                        painter: _GraphifyCanvasPainter(
                          points: _points,
                          selectedIndex: _selectedIndex,
                          progress: _curveAnimation.value,
                          isDark: isDark,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Day Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_points.length, (i) {
              final isSel = i == _selectedIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _points[i].dayLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                      color: isSel ? AppColors.primary : textMuted,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Inspector Detail Callout for the Selected Day
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162032) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  selectedPoint.adherenceRate >= 0.8
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  color: selectedPoint.adherenceRate >= 0.8
                      ? AppColors.emerald
                      : AppColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${selectedPoint.dayLabel}: ${(selectedPoint.adherenceRate * 100).toInt()}% Adherence',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        selectedPoint.statusDetail,
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${selectedPoint.dosesTaken}/${selectedPoint.dosesScheduled} Doses',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that draws the Graphify bezier curve, glowing data points,
/// and vertical guideline for the selected day.
class _GraphifyCanvasPainter extends CustomPainter {
  final List<GraphifyDataPoint> points;
  final int selectedIndex;
  final double progress;
  final bool isDark;

  _GraphifyCanvasPainter({
    required this.points,
    required this.selectedIndex,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double stepX = size.width / (points.length - 1);
    const double topPadding = 16.0;
    const double bottomPadding = 16.0;
    final double graphHeight = size.height - topPadding - bottomPadding;

    final List<Offset> coordinates = [];
    for (int i = 0; i < points.length; i++) {
      final double x = i * stepX;
      // Invert Y: 1.0 (100%) at top, 0.0 at bottom
      final double normY = 1.0 - (points[i].adherenceRate * progress);
      final double y = topPadding + (normY * graphHeight);
      coordinates.add(Offset(x, y));
    }

    // 1. Draw horizontal subtle grid guidelines
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, topPadding),
      Offset(size.width, topPadding),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, topPadding + graphHeight * 0.5),
      Offset(size.width, topPadding + graphHeight * 0.5),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, topPadding + graphHeight),
      Offset(size.width, topPadding + graphHeight),
      gridPaint,
    );

    // 2. Build smooth cubic bezier path
    final path = Path();
    path.moveTo(coordinates[0].dx, coordinates[0].dy);

    for (int i = 0; i < coordinates.length - 1; i++) {
      final p0 = coordinates[i];
      final p1 = coordinates[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    // 3. Draw gradient fill under the bezier curve
    final fillPath = Path.from(path)
      ..lineTo(coordinates.last.dx, size.height)
      ..lineTo(coordinates.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.28),
          AppColors.primary.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // 4. Draw the smooth curve stroke
    final strokePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // 5. Draw vertical selection guideline
    final selOffset =
        coordinates[selectedIndex.clamp(0, coordinates.length - 1)];
    final guidePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(selOffset.dx, 0),
      Offset(selOffset.dx, size.height),
      guidePaint,
    );

    // 6. Draw dots on all data points
    final dotPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : Colors.white
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < coordinates.length; i++) {
      final pt = coordinates[i];
      final isSel = i == selectedIndex;
      final radius = isSel ? 6.5 : 4.0;

      if (isSel) {
        // Outer halo glow for the selected node
        final glowPaint = Paint()
          ..color = AppColors.primary.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, 11.0, glowPaint);
      }

      canvas.drawCircle(pt, radius, dotPaint);
      canvas.drawCircle(pt, radius, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphifyCanvasPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isDark != isDark;
  }
}

/// Compact mini adherence tracker widget for medicine list items or card headers.
class GraphifyAdherenceMiniChart extends StatelessWidget {
  final double weeklyRate; // e.g. 0.94
  final int streakDays;

  const GraphifyAdherenceMiniChart({
    super.key,
    this.weeklyRate = 0.94,
    this.streakDays = 7,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          // Circular radial percentage
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  value: weeklyRate,
                  strokeWidth: 4.5,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
              Text(
                '${(weeklyRate * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Medication Adherence',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.orange,
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$streakDays-Day Perfect Streak',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Weekly mini bars
          Row(
            children: List.generate(7, (i) {
              final active = i < 6; // 6 out of 7 completed
              return Container(
                margin: const EdgeInsets.only(left: 3),
                width: 4,
                height: active ? 18 : 8,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
