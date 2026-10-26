import 'package:flutter/material.dart';

import '../domain/bot_profile.dart';

class BotAvatar extends StatelessWidget {
  const BotAvatar({super.key, required this.bot, this.radius = 20});

  final BotProfile bot;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(bot.colorValue),
      child: Text(
        bot.name.characters.first,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }
}
