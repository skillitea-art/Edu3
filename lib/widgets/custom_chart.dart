import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class CustomChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final String title;

  const CustomChart({
    super.key,
    required this.values,
    required this.labels,
    this.title = 'Activity Overview',
  });

  @override
  State<CustomChart> createState() => _CustomChartState();
}

class _CustomChartState extends State<CustomChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 160,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(double.infinity, 160),
                    painter: _BarChartPainter(
                      values: widget.values,
                      labels: widget.labels,
                      progress: _animation.value,
                      primaryColor: isDark ? AppTheme.primaryDark : AppTheme.primaryColor,
                      accentColor: AppTheme.secondaryColor,
                      isDark: isDark,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double progress;
  final Color primaryColor;
  final Color accentColor;
  final bool isDark;

  _BarChartPainter({
    required this.values,
    required this.labels,
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Find max value for normalization
    double maxValue = values.reduce((curr, next) => curr > next ? curr : next);
    if (maxValue == 0) maxValue = 1.0;

    final double width = size.width;
    final double height = size.height - 24; // Extra space for labels
    final int itemsCount = values.length;
    final double barSpacing = width / (itemsCount * 1.5 + 0.5);
    final double barWidth = barSpacing * 0.8;

    // Draw background guide lines (e.g. 50%, 100%)
    canvas.drawLine(Offset(0, height * 0.5), Offset(width, height * 0.5), linePaint);
    canvas.drawLine(Offset(0, height), Offset(width, height), linePaint);

    for (int i = 0; i < itemsCount; i++) {
      final double x = barSpacing * 0.5 + i * (barSpacing * 1.5);
      final double normalizedValue = values[i] / maxValue;
      final double barHeight = height * normalizedValue * progress;
      final double y = height - barHeight;

      // Draw bar using gradient
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(6),
      );

      final barGradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          primaryColor.withValues(alpha: 0.6),
          i % 2 == 1 ? accentColor : primaryColor,
        ],
      );

      paint.shader = barGradient.createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);

      // Draw label
      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, height + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.values != values;
  }
}
