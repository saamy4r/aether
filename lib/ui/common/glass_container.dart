import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blurSigma = AetherGlass.windowBlur,
    this.borderRadius = AetherGlass.windowRadius,
    this.color = AetherColors.glassBase,
    this.borderColor = AetherColors.glassBorder,
    this.padding,
  });

  final Widget child;
  final double blurSigma;
  final double borderRadius;
  final Color color;
  final Color borderColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    // .grouped shares one blur pass between all GlassContainers under the
    // nearest BackdropGroup (e.g. the lobby card list). With no ancestor
    // group it behaves exactly like a regular BackdropFilter. Overlapping
    // surfaces (floating windows) must NOT share a group, so the desktop
    // window layer deliberately has no BackdropGroup.
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor,
              width: AetherGlass.borderWidth,
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
