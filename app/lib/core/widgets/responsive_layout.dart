import 'package:flutter/material.dart';

const double mobileBreakpoint = 600;
const double tabletBreakpoint = 1024;
const double desktopBreakpoint = 1100;

bool isDesktopWidth(double width) => width >= desktopBreakpoint;
bool isTabletWidth(double width) =>
    width > mobileBreakpoint && width < desktopBreakpoint;

class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 1100});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(height: constraints.maxHeight, child: child),
          ),
        );
      },
    );
  }
}
