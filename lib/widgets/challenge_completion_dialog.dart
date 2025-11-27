// widgets/challenge_completion_dialog.dart
import 'package:flutter/material.dart';
import 'package:capstone_project/models/challenge.dart';
import 'package:capstone_project/color/colors.dart';
import 'package:capstone_project/utils/responsive_utils.dart';
import 'package:capstone_project/widgets/responsive_widgets.dart';
import 'package:confetti/confetti.dart';


class ChallengeCompletionDialog extends StatefulWidget {
  final Challenge challenge;
  final VoidCallback onCreateNewChallenge;
  final VoidCallback onDismiss;

  const ChallengeCompletionDialog({
    super.key,
    required this.challenge,
    required this.onCreateNewChallenge,
    required this.onDismiss,
  });

  @override
  State<ChallengeCompletionDialog> createState() =>
      _ChallengeCompletionDialogState();
}

class _ChallengeCompletionDialogState extends State<ChallengeCompletionDialog>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    // Start animations
    _animationController.forward();
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: r.size(20),
        vertical: r.size(40),
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Confetti
          Positioned(
            top: 0,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.3,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                AppColors.secondary,
                Colors.orange,
                Colors.pink,
                Colors.purple,
                Colors.amber,
              ],
            ),
          ),

          // Dialog content - Wrapped in SingleChildScrollView
          FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.85, // Max 85% of screen height
                ),
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(r.size(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Gradient Header with Trophy
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: r.size(32),
                            horizontal: r.size(20),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.secondary,
                                AppColors.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(r.size(24)),
                              topRight: Radius.circular(r.size(24)),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Trophy Icon with white background
                              Container(
                                width: r.size(80),
                                height: r.size(80),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.emoji_events,
                                  size: r.size(50),
                                  color: Colors.orange.shade600,
                                ),
                              ),

                              ResponsiveGap.vertical(12),

                              // Title
                              Text(
                                'Challenge Complete!',
                                style: TextStyle(
                                  fontSize: r.font(24, min: 20, max: 28),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              ResponsiveGap.vertical(2),

                            ],
                          ),
                        ),

                        // Content section
                        Padding(
                          padding: EdgeInsets.all(r.size(20)),
                          child: Column(
                            children: [
                              // Challenge Info Card
                              Container(
                                padding: EdgeInsets.all(r.size(16)),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(r.size(16)),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Challenge label
                                    Text(
                                      'Challenge',
                                      style: TextStyle(
                                        fontSize: r.font(11, min: 10, max: 12),
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),

                                    ResponsiveGap.vertical(8),

                                    // Challenge Name
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(r.size(6)),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(r.size(6)),
                                          ),

                                        ),
                                        ResponsiveGap.horizontal(8),
                                        Flexible(
                                          child: Text(
                                            widget.challenge.title,
                                            style: TextStyle(
                                              fontSize: r.font(15, min: 13, max: 17),
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),

                                    ResponsiveGap.vertical(12),

                                    // Divider
                                    Container(
                                      height: 1,
                                      color: Colors.grey.shade200,
                                    ),

                                    ResponsiveGap.vertical(12),

                                    // Duration - Column layout for small screens
                                    Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: r.size(14),
                                              color: Colors.grey.shade600,
                                            ),
                                            ResponsiveGap.horizontal(6),
                                            Text(
                                              '${widget.challenge.durationInDays} days',
                                              style: TextStyle(
                                                fontSize: r.font(13, min: 12, max: 14),
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        ResponsiveGap.vertical(4),
                                        Text(
                                          widget.challenge.dateRangeString,
                                          style: TextStyle(
                                            fontSize: r.font(11, min: 10, max: 12),
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              ResponsiveGap.vertical(16),

                              // Milestone Video Ready - Mint green theme
                              Container(
                                padding: EdgeInsets.all(r.size(14)),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(r.size(14)),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(r.size(10)),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(r.size(10)),
                                      ),
                                      child: Icon(
                                        Icons.video_library,
                                        size: r.size(20),
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    ResponsiveGap.horizontal(12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Your Milestone Video is Ready!',
                                            style: TextStyle(
                                              fontSize: r.font(13, min: 12, max: 14),
                                              fontWeight: FontWeight.w700,
                                              color: Colors.green.shade900,
                                            ),
                                          ),
                                          ResponsiveGap.vertical(2),
                                          Text(
                                            'View your journey on the History tab',
                                            style: TextStyle(
                                              fontSize: r.font(11, min: 10, max: 12),
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              ResponsiveGap.vertical(20),

                              // Buttons
                              Column(
                                children: [
                                  // Create New Challenge Button - Gradient
                                  SizedBox(
                                    width: double.infinity,
                                    height: r.size(50),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        widget.onCreateNewChallenge();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(r.size(14)),
                                        ),
                                      ),
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [

                                              AppColors.secondary,
                                              AppColors.secondary,

                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(r.size(14)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.secondary.withValues(alpha: 0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          alignment: Alignment.center,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add_circle_outline,
                                                size: r.size(20),
                                              ),
                                              ResponsiveGap.horizontal(8),
                                              Text(
                                                'Create New Challenge',
                                                style: TextStyle(
                                                  fontSize: r.font(15, min: 14, max: 16),
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  ResponsiveGap.vertical(10),

                                  // Later Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: r.size(48),
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        widget.onDismiss();
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.grey.shade700,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(r.size(14)),
                                        ),
                                      ),
                                      child: Text(
                                        'Later',
                                        style: TextStyle(
                                          fontSize: r.font(14, min: 13, max: 15),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}