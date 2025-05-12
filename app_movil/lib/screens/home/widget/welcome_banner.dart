import 'package:flutter/material.dart';

class WelcomeBanner extends StatelessWidget {
  final dynamic user;
  final dynamic userCenter;

  const WelcomeBanner({
    Key? key,
    required this.user,
    required this.userCenter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentTime = DateTime.now().hour;
    String greeting;

    if (currentTime < 12) {
      greeting = "¡Buenos días";
    } else if (currentTime < 18) {
      greeting = "¡Buenas tardes";
    } else {
      greeting = "¡Buenas noches";
    }

    final Color primaryColor = const Color(0xFF2c6bed);
    final Color secondaryColor = const Color(0xFF60a3f5);

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 25,
                child: Text(
                  user?.name.isNotEmpty == true
                      ? user!.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$greeting, ${user?.name.split(' ')[0] ?? 'Usuario'}!",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (userCenter != null)
                      Text(
                        userCenter.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          if (userCenter != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    userCenter.address,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}