import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/theme/app_effects.dart';

/// Unified, high-end map card for showing routes in Feed and History.
class PremiumMapCard extends StatefulWidget {
  final List<LatLng> points;
  final double height;
  final String? label;
  final bool enableParallax;

  const PremiumMapCard({
    super.key,
    required this.points,
    this.height = 200,
    this.label,
    this.enableParallax = true,
  });

  @override
  State<PremiumMapCard> createState() => _PremiumMapCardState();
}

class _PremiumMapCardState extends State<PremiumMapCard> {
  final GlobalKey _containerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) return const SizedBox.shrink();

    return Container(
      key: _containerKey,
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppEffects.softShadow(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (widget.enableParallax)
              Flow(
                delegate: _ParallaxFlowDelegate(
                  scrollable: Scrollable.of(context),
                  listItemContext: context,
                  containerKey: _containerKey,
                ),
                children: [
                  _buildMapContent(scale: 1.3), // Scale up for parallax room
                ],
              )
            else
              _buildMapContent(),
            
            // Premium Overlay Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),

            if (widget.label != null)
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: AppEffects.glassDecoration(opacity: 0.6),
                  child: Text(
                    widget.label!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapContent({double scale = 1.0}) {
    return Transform.scale(
      scale: scale,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _getCenterPoint(),
          zoom: 14,
        ),
        polylines: {
          Polyline(
            polylineId: const PolylineId('route'),
            points: widget.points,
            color: const Color(0xFF00E676),
            width: 4,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        },
        myLocationEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        scrollGesturesEnabled: false,
        zoomGesturesEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
      ),
    );
  }

  LatLng _getCenterPoint() {
    if (widget.points.isEmpty) return const LatLng(0, 0);
    double lat = 0, lng = 0;
    for (final p in widget.points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / widget.points.length, lng / widget.points.length);
  }
}

class _ParallaxFlowDelegate extends FlowDelegate {
  final ScrollableState scrollable;
  final BuildContext listItemContext;
  final GlobalKey containerKey;

  _ParallaxFlowDelegate({
    required this.scrollable,
    required this.listItemContext,
    required this.containerKey,
  }) : super(repaint: scrollable.position);

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    return BoxConstraints.tightFor(
      width: constraints.maxWidth,
      height: constraints.maxHeight * 1.5, // Taller child for parallax
    );
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    // Calculate the position of this list item within the viewport.
    final scrollableBox = scrollable.context.findRenderObject() as RenderBox;
    final listItemBox = listItemContext.findRenderObject() as RenderBox;
    final listItemOffset = listItemBox.localToGlobal(
      listItemBox.size.centerLeft(Offset.zero),
      ancestor: scrollableBox,
    );

    // Determine the percent of the way through the viewport that this item is.
    final viewportDimension = scrollable.position.viewportDimension;
    final scrollFraction = (listItemOffset.dy / viewportDimension).clamp(0.0, 1.0);

    // Calculate the vertical alignment of the background based on the scroll percent.
    final verticalAlignment = Alignment(0.0, scrollFraction * 2 - 1);

    // Convert the alignment to a pixel offset for painting.
    final backgroundSize = context.getChildSize(0)!;
    final listItemSize = context.size;
    final childRect = verticalAlignment.inscribe(backgroundSize, Offset.zero & listItemSize);

    // Paint the background.
    context.paintChild(
      0,
      transform: Transform.translate(offset: Offset(0.0, childRect.top)).transform,
    );
  }

  @override
  bool shouldRepaint(_ParallaxFlowDelegate oldDelegate) {
    return scrollable != oldDelegate.scrollable ||
        listItemContext != oldDelegate.listItemContext ||
        containerKey != oldDelegate.containerKey;
  }
}
