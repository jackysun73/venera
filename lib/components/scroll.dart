part of 'components.dart';

class SmoothCustomScrollView extends StatelessWidget {
  const SmoothCustomScrollView(
      {super.key, required this.slivers, this.controller});

  final ScrollController? controller;

  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return SmoothScrollProvider(
      controller: controller,
      builder: (context, controller, physics) {
        return CustomScrollView(
          controller: controller,
          physics: physics,
          slivers: [
            ...slivers,
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: context.padding.bottom,
              ),
            ),
          ],
        );
      },
    );
  }
}

class SmoothScrollProvider extends StatefulWidget {
  const SmoothScrollProvider(
      {super.key, this.controller, required this.builder});

  final ScrollController? controller;

  final Widget Function(BuildContext, ScrollController, ScrollPhysics) builder;

  static bool get isMouseScroll => _SmoothScrollProviderState._isMouseScroll;

  @override
  State<SmoothScrollProvider> createState() => _SmoothScrollProviderState();
}

class _SmoothScrollProviderState extends State<SmoothScrollProvider> {
  late final ScrollController _controller;

  double? _futurePosition;

  static bool _isMouseScroll = App.isDesktop;

  @override
  void initState() {
    _controller = widget.controller ?? ScrollController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (App.isMacOS) {
      return widget.builder(
        context,
        _controller,
        const BouncingScrollPhysics(),
      );
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _futurePosition = null;
        if (_isMouseScroll) {
          setState(() {
            _isMouseScroll = false;
          });
        }
      },
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            return;
          }
          if (pointerSignal.kind == PointerDeviceKind.mouse &&
              !_isMouseScroll) {
            setState(() {
              _isMouseScroll = true;
            });
          }
          if (!_isMouseScroll) return;
          var currentLocation = _controller.position.pixels;
          var old = _futurePosition;
          _futurePosition ??= currentLocation;
          double k = (_futurePosition! - currentLocation).abs() / 1600 + 1;
          _futurePosition = _futurePosition! + pointerSignal.scrollDelta.dy * k;
          _futurePosition = _futurePosition!.clamp(
            _controller.position.minScrollExtent,
            _controller.position.maxScrollExtent,
          );
          if (_futurePosition == old) return;
          var target = _futurePosition!;
          _controller
              .animateTo(
            _futurePosition!,
            duration: _fastAnimationDuration,
            curve: Curves.linear,
          )
              .then((_) {
            var current = _controller.position.pixels;
            if (current == target && current == _futurePosition) {
              _futurePosition = null;
            }
          });
        }
      },
      child: ScrollControllerProvider._(
        controller: _controller,
        child: widget.builder(
          context,
          _controller,
          _isMouseScroll
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
        ),
      ),
    );
  }
}

class ScrollControllerProvider extends InheritedWidget {
  const ScrollControllerProvider._({
    required this.controller,
    required super.child,
  });

  final ScrollController controller;

  static ScrollController of(BuildContext context) {
    final ScrollControllerProvider? provider =
        context.dependOnInheritedWidgetOfExactType<ScrollControllerProvider>();
    return provider!.controller;
  }

  @override
  bool updateShouldNotify(ScrollControllerProvider oldWidget) {
    return oldWidget.controller != controller;
  }
}

class AppScrollBar extends StatefulWidget {
  const AppScrollBar({
    super.key,
    required this.controller,
    required this.child,
    this.topPadding = 0,
  });

  final ScrollController controller;

  final Widget child;

  final double topPadding;

  @override
  State<AppScrollBar> createState() => _AppScrollBarState();
}

class _AppScrollBarState extends State<AppScrollBar> {
  late final ScrollController _scrollController;

  double minExtent = 0;
  double maxExtent = 0;
  double position = 0;

  double viewHeight = 0;

  final _scrollIndicatorSize = App.isDesktop ? 42.0 : 48.0;

  late final VerticalDragGestureRecognizer _dragGestureRecognizer;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller;
    _scrollController.addListener(onChanged);
    Future.microtask(onChanged);
    _dragGestureRecognizer = VerticalDragGestureRecognizer()
      ..onUpdate = onUpdate;
  }

  void onUpdate(DragUpdateDetails details) {
    if (maxExtent - minExtent <= 0 ||
        viewHeight == 0 ||
        details.primaryDelta == null) {
      return;
    }
    var offset = details.primaryDelta!;
    var positionOffset =
        offset / (viewHeight - _scrollIndicatorSize) * (maxExtent - minExtent);
    _scrollController.jumpTo((position + positionOffset).clamp(
      minExtent,
      maxExtent,
    ));
  }

  void onChanged() {
    if (_scrollController.positions.isEmpty) return;
    var position = _scrollController.position;
    if (position.minScrollExtent != minExtent ||
        position.maxScrollExtent != maxExtent ||
        position.pixels != this.position) {
      setState(() {
        minExtent = position.minScrollExtent;
        maxExtent = position.maxScrollExtent;
        this.position = position.pixels;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constrains) {
        var scrollHeight = (maxExtent - minExtent);
        var height = constrains.maxHeight - widget.topPadding;
        viewHeight = height;
        var top = scrollHeight == 0
            ? 0.0
            : (position - minExtent) /
                scrollHeight *
                (height - _scrollIndicatorSize);
        return Stack(
          children: [
            Positioned.fill(
              child: widget.child,
            ),
            Positioned(
              top: top + widget.topPadding,
              right: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    _dragGestureRecognizer.addPointer(event);
                  },
                  child: SizedBox(
                    width: _scrollIndicatorSize/2,
                    height: _scrollIndicatorSize,
                    child: CustomPaint(
                      painter: _ScrollIndicatorPainter(
                        backgroundColor: context.colorScheme.surface,
                        shadowColor: context.colorScheme.shadow,
                      ),
                      child: Column(
                        children: [
                          const Spacer(),
                          Icon(Icons.arrow_drop_up, size: 18),
                          Icon(Icons.arrow_drop_down, size: 18),
                          const Spacer(),
                        ],
                      ).paddingLeft(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScrollIndicatorPainter extends CustomPainter {
  final Color backgroundColor;

  final Color shadowColor;

  const _ScrollIndicatorPainter({
    required this.backgroundColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..arcToPoint(
        Offset(size.width, 0),
        radius: Radius.circular(size.width),
      );
    canvas.drawShadow(path, shadowColor, 4, true);
    var backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..arcToPoint(
        Offset(size.width, 0),
        radius: Radius.circular(size.width),
      );
    canvas.drawPath(path, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _ScrollIndicatorPainter ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}
