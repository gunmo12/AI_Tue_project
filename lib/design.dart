import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const purple = Color(0xff8550ed),
    ink = Color(0xff201d2c),
    muted = Color(0xff797386),
    bg = Color(0xfff6f3fd),
    track = Color(0xffeae6f3),
    green = Color(0xff16814a),
    red = Color(0xffde3457);
const palette = [
  Color(0xff9865f4),
  Color(0xff58a7f5),
  Color(0xffee79bc),
  Color(0xff35bd96),
  Color(0xffffb368),
  Color(0xffd7d7e3),
];
const tints = [
  Color(0xfff0e9ff),
  Color(0xffe9f8f2),
  Color(0xffffebf5),
  Color(0xffe8f7f1),
  Color(0xfffff2e5),
  Color(0xfff0eff5),
];
Widget txt(
  String text, {
  double size = 12,
  Color color = muted,
  bool bold = false,
}) => Text(
  text,
  style: TextStyle(
    fontSize: size,
    color: color,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    height: 1.5,
  ),
);
Widget panel(
  Widget child, {
  Color color = Colors.white,
  EdgeInsets padding = const EdgeInsets.all(16),
}) => Container(
  width: double.infinity,
  margin: const EdgeInsets.only(bottom: 14),
  padding: padding,
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(17),
    boxShadow: color == Colors.white
        ? [
            const BoxShadow(
              color: Color(0x0f4a3280),
              offset: Offset(0, 4),
              blurRadius: 16,
            ),
          ]
        : null,
  ),
  child: child,
);
Widget section(String title, {Widget? action}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: Row(
    children: [
      Expanded(child: txt(title, size: 16, color: ink, bold: true)),
      ?action,
    ],
  ),
);
Widget smallButton(String title, VoidCallback? action) => TextButton(
  onPressed: action,
  style: TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    minimumSize: const Size(0, 32),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),
  child: txt(title, size: 11, color: purple),
);
Widget progress(double? value, {Color color = purple}) => ClipRRect(
  borderRadius: BorderRadius.circular(6),
  child: LinearProgressIndicator(
    value: ((value ?? 0) / 100).clamp(0, 1),
    minHeight: 9,
    color: color,
    backgroundColor: track,
  ),
);
Widget heading(String title, String subtitle, {String? icon}) => Padding(
  padding: const EdgeInsets.only(bottom: 18),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          if (icon != null) ...[FigIcon(icon), const SizedBox(width: 8)],
          Expanded(child: txt(title, size: 23, color: ink, bold: true)),
        ],
      ),
      const SizedBox(height: 4),
      txt(subtitle),
    ],
  ),
);

class FigIcon extends StatelessWidget {
  final String name;
  final double box;
  const FigIcon(this.name, {super.key, this.box = 22});
  static const dimensions = <String, List<double>>{
    'imgGroup': [21.8167, 21.8167],
    'imgGroup1': [19.9837, 19.9837],
    'imgGroup2': [19.9833, 19.9833],
    'imgGroup3': [18.15, 18.15],
    'imgGroup4': [18.15, 18.15],
    'imgGroup5': [19.9837, 19.9837],
    'imgGroup6': [19.9833, 19.9833],
    'imgGroup7': [18.15, 18.15],
    'imgGroup8': [18.15, 18.15],
    'imgGroup9': [18.15, 19.0667],
    'imgGroup10': [18.15, 18.15],
    'imgGroup11': [18.15, 18.15],
    'imgGroup12': [14.4833, 18.15],
    'imgGroup13': [18.15, 18.15],
    'imgGroup14': [18.15, 19.0667],
    'imgGroup15': [19.9833, 15.4],
    'imgGroup16': [17.2333, 18.15],
    'imgGroup17': [21.9333, 23.1],
    'imgGroup18': [25.4333, 19.6],
    'imgGroup19': [23.1, 23.1],
    'imgGroup20': [29.7667, 31.35],
    'imgGroup21': [15.8, 19.8],
    'imgGroup22': [19.8, 19.8],
    'imgGroup23': [19.8, 20.8],
  };
  @override
  Widget build(BuildContext context) {
    final d = dimensions[name] ?? [22.0, 22.0];
    return ExcludeSemantics(
      child: SizedBox(
        width: box,
        height: box,
        child: Center(
          child: SvgPicture.asset(
            'assets/figma/$name.svg',
            width: d[0],
            height: d[1],
          ),
        ),
      ),
    );
  }
}

Widget categoryIcon(int i, {bool budget = false}) => Container(
  width: budget ? 24 : 40,
  height: budget ? 24 : 40,
  decoration: BoxDecoration(
    color: budget ? Colors.transparent : tints[i],
    borderRadius: BorderRadius.circular(17),
  ),
  alignment: Alignment.center,
  child: FigIcon(
    (budget
        ? [
            'imgGroup21',
            'imgGroup22',
            'imgGroup23',
            'imgGroup15',
            'imgGroup16',
            'imgGroup5',
          ]
        : [
            'imgGroup12',
            'imgGroup13',
            'imgGroup14',
            'imgGroup15',
            'imgGroup16',
            'imgGroup5',
          ])[i],
  ),
);

class DonutPainter extends CustomPainter {
  final List<int> values;
  DonutPainter(this.values);
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0, (n, v) => n + v);
    final stroke = size.width * 24 / 164;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.width - stroke) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    if (total == 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(rect, start, sweep, false, paint..color = palette[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter old) => true;
}

class TrendPainter extends CustomPainter {
  final List<int> values;
  TrendPainter(this.values);
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xfff0ebf8)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = 20 + i * (size.height - 30) / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final max = values.fold(1, math.max);
    final points = List.generate(
      values.length,
      (i) => Offset(
        10 + i * (size.width - 20) / math.max(1, values.length - 1),
        size.height - 15 - values[i] / max * (size.height - 40),
      ),
    );
    if (points.isEmpty) return;
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x339865f4), Color(0x009865f4)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = purple,
    );
    for (final p in points) {
      canvas.drawCircle(p, 3.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        p,
        3.5,
        Paint()
          ..color = purple
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TrendPainter old) => true;
}
