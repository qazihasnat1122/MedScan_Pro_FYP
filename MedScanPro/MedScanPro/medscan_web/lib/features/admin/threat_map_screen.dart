import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ThreatMapScreen extends StatefulWidget {
  const ThreatMapScreen({super.key});

  @override
  State<ThreatMapScreen> createState() => _ThreatMapScreenState();
}

class _ThreatMapScreenState extends State<ThreatMapScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _lineDashController;
  String _selectedThreat = 'AUG-8821';

  final List<Map<String, dynamic>> _threats = [
    {
      'id': 'AUG-8821',
      'medicine': 'Augmentin 625mg',
      'manufacturer': 'GlaxoSmithKline Pakistan Ltd.',
      'level': 'CRITICAL',
      'scans': 8,
      'cities': 3,
      'velocity': '850 miles in 14 mins (Impossible Physical Travel)',
      'summary': 'Exact same serialized batch code scanned simultaneously in Karachi, Lahore, and Peshawar. Indicates mass cloned packaging plates.',
      'points': [
        {'city': 'Karachi', 'location': 'Saddar Pharmacy Market', 'scans': 3, 'time': '14 mins ago', 'offset': const Offset(0.3, 0.8)},
        {'city': 'Lahore', 'location': 'Anarkali Wholesale Drug Market', 'scans': 4, 'time': '18 mins ago', 'offset': const Offset(0.7, 0.4)},
        {'city': 'Peshawar', 'location': 'Khyber Medical Bazaar', 'scans': 1, 'time': '26 mins ago', 'offset': const Offset(0.6, 0.2)},
      ],
    },
    {
      'id': 'RSK-99014',
      'medicine': 'Risek 20mg',
      'manufacturer': 'Getz Pharma',
      'level': 'HIGH',
      'scans': 5,
      'cities': 2,
      'velocity': '200 miles in 35 mins',
      'summary': 'Identical batch scanned across multiple provincial boundaries in an impossibly short time window.',
      'points': [
        {'city': 'Islamabad', 'location': 'Blue Area Pharmacies', 'scans': 3, 'time': '5 mins ago', 'offset': const Offset(0.65, 0.25)},
        {'city': 'Faisalabad', 'location': 'Clock Tower Market', 'scans': 2, 'time': '40 mins ago', 'offset': const Offset(0.65, 0.45)},
      ],
    },
    {
      'id': 'BRF-40192',
      'medicine': 'Brufen 400mg',
      'manufacturer': 'Abbott Laboratories',
      'level': 'MODERATE',
      'scans': 3,
      'cities': 2,
      'velocity': '150 miles in 1 hour',
      'summary': 'Concurrent scans detected in twin cities and neighboring districts.',
      'points': [
        {'city': 'Rawalpindi', 'location': 'Commercial Market', 'scans': 2, 'time': '1 hour ago', 'offset': const Offset(0.63, 0.26)},
        {'city': 'Gujranwala', 'location': 'Satellite Town', 'scans': 1, 'time': '1.5 hours ago', 'offset': const Offset(0.68, 0.35)},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _lineDashController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _lineDashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threat = _threats.firstWhere((t) => t['id'] == _selectedThreat);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    final radarCol = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1D21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF19383F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.radar_rounded, color: Color(0xFF16B8A6)),
                const SizedBox(width: 12),
                const Text(
                  'TACTICAL RADAR VISUALIZATION',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.circle, size: 8, color: Color(0xFFEF4444)),
                      SizedBox(width: 6),
                      Text('LIVE FEED', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF19383F)),
          Expanded(
            child: Stack(
              children: [
                // Radar Rings & Map Background
                CustomPaint(
                  painter: _RadarMapPainter(
                    pulseAnimation: _pulseController,
                    dashAnimation: _lineDashController,
                    points: threat['points'],
                  ),
                  size: Size.infinite,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF19383F)),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF19383F),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.speed_rounded, color: Color(0xFFF87171), size: 18),
                const SizedBox(width: 8),
                Text(
                  'VELOCITY ALERT: ${threat['velocity']}',
                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFF87171), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final investigatorPanel = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1D21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF19383F)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('THREAT INVESTIGATOR', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  threat['medicine'],
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: threat['level'] == 'CRITICAL' ? const Color(0xFFEF4444) : (threat['level'] == 'HIGH' ? const Color(0xFFF97316) : const Color(0xFFF59E0B)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  threat['level'],
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('FLAGGED BATCH: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text(threat['id'], style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(threat['manufacturer'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          
          const SizedBox(height: 24),
          const Text('CLINICAL INCIDENT SUMMARY', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(
            threat['summary'],
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.5),
          ),

          const SizedBox(height: 24),
          const Text('CONCURRENT GEO-SCAN POINTS', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Column(
            children: (threat['points'] as List).map((p) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F262C),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF143239)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p['city']} • ${p['location']}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('${p['scans']} scans • ${p['time']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),
          const Text('ACTION HUB', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.security, size: 18),
            label: const Text('Dispatch Field Inspectors'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16B8A6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {},
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.warning_amber_rounded, size: 18),
            label: const Text('Issue Instant Batch Recall'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {},
          ),
        ],
      ),
    );

    final cloneSelector = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1D21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF19383F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('ACTIVE CLONE INCIDENTS', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
          const Divider(height: 1, color: Color(0xFF19383F)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _threats.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFF19383F)),
            itemBuilder: (context, index) {
              final t = _threats[index];
              final isSelected = t['id'] == _selectedThreat;
              return InkWell(
                onTap: () => setState(() => _selectedThreat = t['id']),
                child: Container(
                  color: isSelected ? const Color(0xFF143239) : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF16B8A6) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(t['id'], style: const TextStyle(fontFamily: 'monospace', color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: t['level'] == 'CRITICAL' ? const Color(0xFFEF4444).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1),
                                    border: Border.all(color: t['level'] == 'CRITICAL' ? const Color(0xFFEF4444).withOpacity(0.3) : const Color(0xFFF59E0B).withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(t['level'], style: TextStyle(color: t['level'] == 'CRITICAL' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${t['medicine']} • ${t['scans']} Scans • ${t['cities']} Cities', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.map_outlined, color: Color(0xFF16B8A6), size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('National Threat Map', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 2),
                  Text('Cloned Batch Velocity Surveillance & Geospatial Counterfeit Detection', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      SizedBox(height: 500, child: radarCol),
                      const SizedBox(height: 20),
                      cloneSelector,
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: SizedBox(height: 700, child: investigatorPanel),
                ),
              ],
            )
          else
            Column(
              children: [
                cloneSelector,
                const SizedBox(height: 20),
                SizedBox(height: 400, child: radarCol),
                const SizedBox(height: 20),
                SizedBox(height: 600, child: investigatorPanel),
              ],
            ),
        ],
      ),
    );
  }
}

class _RadarMapPainter extends CustomPainter {
  final Animation<double> pulseAnimation;
  final Animation<double> dashAnimation;
  final List<dynamic> points;

  _RadarMapPainter({
    required this.pulseAnimation,
    required this.dashAnimation,
    required this.points,
  }) : super(repaint: Listenable.merge([pulseAnimation, dashAnimation]));

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 * 0.9;

    // Draw Radar Rings
    final ringPaint = Paint()
      ..color = const Color(0xFF19383F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * (i / 4), ringPaint);
    }

    // Draw Crosshairs
    final crosshairPaint = Paint()
      ..color = const Color(0xFF19383F).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), crosshairPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), crosshairPaint);

    // Map Coordinates to Pixels
    List<Offset> pixelPoints = [];
    for (var p in points) {
      final offset = p['offset'] as Offset;
      // offset is normalized 0..1
      pixelPoints.add(Offset(size.width * offset.dx, size.height * offset.dy));
    }

    // Draw Connection Arcs
    if (pixelPoints.length > 1) {
      final arcPaint = Paint()
        ..color = const Color(0xFFEF4444).withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      for (int i = 0; i < pixelPoints.length; i++) {
        for (int j = i + 1; j < pixelPoints.length; j++) {
          _drawDashedLine(canvas, pixelPoints[i], pixelPoints[j], arcPaint, dashAnimation.value);
        }
      }
    }

    // Draw Pulsing Beacons
    for (int i = 0; i < pixelPoints.length; i++) {
      final p = points[i];
      final pt = pixelPoints[i];

      // Pulse
      final pulseRadius = 30 * pulseAnimation.value;
      final pulseOpacity = 1.0 - pulseAnimation.value;
      
      final pulsePaint = Paint()
        ..color = const Color(0xFFEF4444).withOpacity(pulseOpacity * 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, pulseRadius, pulsePaint);

      // Core
      final corePaint = Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(pt, 5, corePaint);

      final innerCorePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 2.5, innerCorePaint);

      // Draw Labels
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${p['city']}\n',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          children: [
            TextSpan(
              text: '(${p['scans']}x)',
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 10),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pt.dx - textPainter.width / 2, pt.dy + 10));
    }

    // Draw scanning sweeper
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          const Color(0xFF16B8A6).withOpacity(0.0),
          const Color(0xFF16B8A6).withOpacity(0.2),
        ],
        stops: const [0.7, 1.0],
        transform: GradientRotation(pulseAnimation.value * 2 * pi),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius),
      pulseAnimation.value * 2 * pi,
      pi / 2,
      true,
      sweepPaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, double dashOffset) {
    const dashWidth = 5.0;
    const dashSpace = 5.0;

    final distance = (p2 - p1).distance;
    final normalized = (p2 - p1) / distance;

    double currentDistance = dashOffset * (dashWidth + dashSpace);

    while (currentDistance < distance) {
      double endDistance = currentDistance + dashWidth;
      if (endDistance > distance) endDistance = distance;

      canvas.drawLine(
        p1 + normalized * currentDistance,
        p1 + normalized * endDistance,
        paint,
      );

      currentDistance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _RadarMapPainter oldDelegate) => true;
}
