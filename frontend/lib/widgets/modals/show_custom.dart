import 'package:flutter/material.dart';
import 'package:frontend/screens/manage_location.dart';
import 'package:frontend/screens/manage_noete.dart';
<<<<<<< HEAD

import 'package:frontend/screens/weather_stogare.dart';
=======
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e

void showCustomModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('Notifications'),
                    trailing: Icon(Icons.notifications_none, size: 20),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
<<<<<<< HEAD
                            builder: (context) => WeatherStorageScreen(),
                          ));
                    },
                  ),
                  Divider(height: 1),
                  ListTile(
                    title: Text('Notifications'),
                    trailing: Icon(Icons.notifications_none, size: 20),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManageNote(),
                          ));
                    },
                  ),
=======
                            builder: (context) => ManageNote(),
                          ));
                    },
                  ),
>>>>>>> 5ac083889d9a16af0cc6cec4a1db08759213a99e
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
