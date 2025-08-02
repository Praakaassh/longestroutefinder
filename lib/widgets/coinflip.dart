import 'package:flutter/material.dart';
import 'dart:math' as math;

class CoinFlipWidget extends StatefulWidget {
  final String frontImagePath;
  final String backImagePath;
  final VoidCallback onFlipComplete;
  final Duration animationDuration;

  const CoinFlipWidget({
    Key? key,
    required this.frontImagePath,
    required this.backImagePath,
    required this.onFlipComplete,
    this.animationDuration = const Duration(milliseconds: 2000),
  }) : super(key: key);

  @override
  State<CoinFlipWidget> createState() => _CoinFlipWidgetState();
}

class _CoinFlipWidgetState extends State<CoinFlipWidget>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _bounceController;
  late Animation<double> _flipAnimation;
  late Animation<double> _bounceAnimation;

  bool _isFlipping = false;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();

    // Flip animation controller
    _flipController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Bounce animation controller
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Flip animation with multiple rotations
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: math.pi * 6, // 3 full rotations
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));

    // Bounce animation for landing effect
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));

    _flipController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _bounceController.forward().then((_) {
          _bounceController.reverse().then((_) {
            widget.onFlipComplete();
          });
        });
      }
    });

    _flipController.addListener(() {
      // Determine which side to show based on rotation
      double rotation = _flipAnimation.value % (math.pi * 2);
      setState(() {
        _showBack = rotation > math.pi / 2 && rotation < 3 * math.pi / 2;
      });
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void flipCoin() {
    if (_isFlipping) return;

    setState(() {
      _isFlipping = true;
    });

    _flipController.reset();
    _flipController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: flipCoin,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flipAnimation, _bounceAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _bounceAnimation.value,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(_flipAnimation.value),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _showBack
                      ? Image.asset(
                    widget.backImagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.orange,
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 30,
                        ),
                      );
                    },
                  )
                      : Image.asset(
                    widget.frontImagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.amber,
                        child: const Icon(
                          Icons.monetization_on,
                          color: Colors.white,
                          size: 30,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
