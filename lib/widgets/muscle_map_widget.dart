
import 'package:flutter/material.dart';

class MuscleMapWidget extends StatelessWidget {
  final String activeMuscleGroup;

  const MuscleMapWidget({super.key, required this.activeMuscleGroup});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(300, 600), // Larger canvas for detail
      painter: PersonPainter(activeMuscleGroup: activeMuscleGroup),
    );
  }
}

class PersonPainter extends CustomPainter {
  final String activeMuscleGroup;

  PersonPainter({required this.activeMuscleGroup});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    // Centers
    final cx = w / 2;
    
    // Paints
    final Paint bodyOutlinePaint = Paint()
      ..color = const Color(0xFF8D6E63) // Darker brown outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint muscleInactivePaint = Paint()
      ..color = const Color(0xFFD7CCC8) // Light grey/brown
      ..style = PaintingStyle.fill;

    final Paint muscleActivePaint = Paint()
      ..color = const Color(0xFFE91E63) // Vibrant Pink/Red
      ..style = PaintingStyle.fill;
      
    final Paint highlightPaint = Paint()
       ..color = Colors.white.withValues(alpha: 0.2)
       ..style = PaintingStyle.fill;

    Paint getPaint(List<String> groups) {
      bool isActive = groups.contains(activeMuscleGroup) || activeMuscleGroup == 'Full Body';
      if (activeMuscleGroup == 'Cardio' && ['Legs', 'Full Body'].any((g) => groups.contains(g))) {
         isActive = true; // Cardio highlights legs/body
      }
      return isActive ? muscleActivePaint : muscleInactivePaint;
    }

    void drawMuscle(Path path, List<String> groups) {
      canvas.drawPath(path, getPaint(groups));
      canvas.drawPath(path, bodyOutlinePaint);
      
      // Add a subtle highlight for 3D effect
      if (getPaint(groups) == muscleActivePaint) {
         // canvas.drawPath(path, highlightPaint); // Optional shine
      }
    }

    // --- ANATOMY PATHS ---
    // Coordinates are roughly relative to w, h

    // Head
    final headPath = Path();
    headPath.addOval(Rect.fromCenter(center: Offset(cx, h * 0.1), width: w * 0.14, height: h * 0.12));
    drawMuscle(headPath, []); // Head usually not targeted

    // Neck (Traps)
    final trapsPath = Path();
    trapsPath.moveTo(cx - w*0.06, h*0.15);
    trapsPath.lineTo(cx + w*0.06, h*0.15);
    trapsPath.lineTo(cx + w*0.12, h*0.18); // Shoulder connection
    trapsPath.lineTo(cx - w*0.12, h*0.18);
    trapsPath.close();
    drawMuscle(trapsPath, ['Shoulders', 'Back']);

    // Shoulders (Deltoids)
    final leftDelt = Path();
    leftDelt.moveTo(cx - w*0.12, h*0.18);
    leftDelt.quadraticBezierTo(cx - w*0.22, h*0.19, cx - w*0.20, h*0.28); // Outer rounded
    leftDelt.lineTo(cx - w*0.15, h*0.25); // Inner insertion
    leftDelt.close();
    
    final rightDelt = Path();
    rightDelt.moveTo(cx + w*0.12, h*0.18);
    rightDelt.quadraticBezierTo(cx + w*0.22, h*0.19, cx + w*0.20, h*0.28);
    rightDelt.lineTo(cx + w*0.15, h*0.25);
    rightDelt.close();
    
    drawMuscle(leftDelt, ['Shoulders']);
    drawMuscle(rightDelt, ['Shoulders']);

    // Chest (Pecs)
    final leftPec = Path();
    leftPec.moveTo(cx, h*0.18); // Sternum top
    leftPec.lineTo(cx - w*0.12, h*0.19); // Shoulder joint
    leftPec.quadraticBezierTo(cx - w*0.14, h*0.25, cx - w*0.10, h*0.28); // Armpit/Side
    leftPec.quadraticBezierTo(cx - w*0.05, h*0.29, cx, h*0.28); // Bottom curve
    leftPec.close();

    final rightPec = Path();
    rightPec.moveTo(cx, h*0.18);
    rightPec.lineTo(cx + w*0.12, h*0.19);
    rightPec.quadraticBezierTo(cx + w*0.14, h*0.25, cx + w*0.10, h*0.28);
    rightPec.quadraticBezierTo(cx + w*0.05, h*0.29, cx, h*0.28);
    rightPec.close();

    drawMuscle(leftPec, ['Chest']);
    drawMuscle(rightPec, ['Chest']);

    // Abs (Abdominals) - segmented look
    final absPath = Path();
    absPath.moveTo(cx - w*0.04, h*0.28); // Top left (under pecs)
    absPath.lineTo(cx + w*0.04, h*0.28); // Top right
    absPath.lineTo(cx + w*0.03, h*0.42); // Bottom right
    absPath.lineTo(cx - w*0.03, h*0.42); // Bottom left
    absPath.close();
    
    // Obliques (Sides)
    final leftOblique = Path();
    leftOblique.moveTo(cx - w*0.10, h*0.28);
    leftOblique.lineTo(cx - w*0.04, h*0.28);
    leftOblique.lineTo(cx - w*0.03, h*0.42);
    leftOblique.lineTo(cx - w*0.09, h*0.40); // Hip flare
    leftOblique.close();

    final rightOblique = Path();
    rightOblique.moveTo(cx + w*0.10, h*0.28);
    rightOblique.lineTo(cx + w*0.04, h*0.28);
    rightOblique.lineTo(cx + w*0.03, h*0.42);
    rightOblique.lineTo(cx + w*0.09, h*0.40);
    rightOblique.close();

    drawMuscle(absPath, ['Abs']);
    drawMuscle(leftOblique, ['Abs']);
    drawMuscle(rightOblique, ['Abs']);

    // Arms - Biceps
    final leftBicep = Path();
    leftBicep.moveTo(cx - w*0.20, h*0.28); // From Delt
    leftBicep.quadraticBezierTo(cx - w*0.23, h*0.32, cx - w*0.19, h*0.36); // Elbow
    leftBicep.lineTo(cx - w*0.15, h*0.34); // Inner arm
    leftBicep.lineTo(cx - w*0.15, h*0.25); // Pit
    leftBicep.close();

    final rightBicep = Path();
    rightBicep.moveTo(cx + w*0.20, h*0.28);
    rightBicep.quadraticBezierTo(cx + w*0.23, h*0.32, cx + w*0.19, h*0.36);
    rightBicep.lineTo(cx + w*0.15, h*0.34);
    rightBicep.lineTo(cx + w*0.15, h*0.25);
    rightBicep.close();

    drawMuscle(leftBicep, ['Arms']);
    drawMuscle(rightBicep, ['Arms']);

    // Arms - Forearms
    final leftForearm = Path();
    leftForearm.moveTo(cx - w*0.19, h*0.36); // Elbow
    leftForearm.quadraticBezierTo(cx - w*0.22, h*0.40, cx - w*0.20, h*0.48); // Wrist outer
    leftForearm.lineTo(cx - w*0.16, h*0.48); // Wrist inner
    leftForearm.lineTo(cx - w*0.15, h*0.36); // Elbow inner
    leftForearm.close();

    final rightForearm = Path();
    rightForearm.moveTo(cx + w*0.19, h*0.36); 
    rightForearm.quadraticBezierTo(cx + w*0.22, h*0.40, cx + w*0.20, h*0.48);
    rightForearm.lineTo(cx + w*0.16, h*0.48);
    rightForearm.lineTo(cx + w*0.15, h*0.36);
    rightForearm.close();

    drawMuscle(leftForearm, ['Arms']);
    drawMuscle(rightForearm, ['Arms']);

    // Legs - Quads (Thighs)
    final leftQuad = Path();
    leftQuad.moveTo(cx - w*0.03, h*0.42); // Crotch
    leftQuad.lineTo(cx - w*0.09, h*0.40); // Hip
    leftQuad.quadraticBezierTo(cx - w*0.13, h*0.55, cx - w*0.10, h*0.65); // Outer knee
    leftQuad.lineTo(cx - w*0.05, h*0.65); // Inner knee
    leftQuad.close();

    final rightQuad = Path();
    rightQuad.moveTo(cx + w*0.03, h*0.42);
    rightQuad.lineTo(cx + w*0.09, h*0.40);
    rightQuad.quadraticBezierTo(cx + w*0.13, h*0.55, cx + w*0.10, h*0.65);
    rightQuad.lineTo(cx + w*0.05, h*0.65);
    rightQuad.close();

    drawMuscle(leftQuad, ['Legs']);
    drawMuscle(rightQuad, ['Legs']);

    // Legs - Calves
    final leftCalf = Path();
    leftCalf.moveTo(cx - w*0.10, h*0.65); // Outer knee
    leftCalf.quadraticBezierTo(cx - w*0.12, h*0.75, cx - w*0.09, h*0.88); // Ankle outer
    leftCalf.lineTo(cx - w*0.06, h*0.88); // Ankle inner
    leftCalf.quadraticBezierTo(cx - w*0.04, h*0.75, cx - w*0.05, h*0.65); // Inner knee
    leftCalf.close();

    final rightCalf = Path();
    rightCalf.moveTo(cx + w*0.10, h*0.65);
    rightCalf.quadraticBezierTo(cx + w*0.12, h*0.75, cx + w*0.09, h*0.88);
    rightCalf.lineTo(cx + w*0.06, h*0.88);
    rightCalf.quadraticBezierTo(cx + w*0.04, h*0.75, cx + w*0.05, h*0.65);
    rightCalf.close();

    drawMuscle(leftCalf, ['Legs']);
    drawMuscle(rightCalf, ['Legs']);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
