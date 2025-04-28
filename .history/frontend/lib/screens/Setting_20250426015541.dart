
import 'package:flutter/material.dart';
import '../services/constants.dart';
import '../services/database.dart';
import '../services/widget_service.dart';
import 'HomePage.dart';

class Setting extends StatefulWidget {
  const Setting({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _Setting();

}

class _Setting extends State<Setting> {
  String title = 'Unit';
  String title2 = 'Language';
  String item1 = '\u00B0C';
  String item2 = '\u00B0F';
  String lang1 = 'Tiếng Việt';
  String lang2 = 'English';
  bool isWidgetDisplayed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(

        appBar: AppBar(
          title: Text('Setting'),
        ),
        backgroundColor: Color(0xFFEFEFEF),
        body: Column(
          children: [
            SizedBox(height: 10,),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: ListTile(
                  title: Text(title),
                  trailing: PopupMenuButton(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10))
                    ),
                    color: Colors.white,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                          child: Text(item1),
                          value: 'metric'),
                      PopupMenuItem(
                        child: Text(item2),
                        value: 'standard',)
                    ],
                    onSelected: (String newValue) {
                      setState(() {
                        type = newValue;
                      });
                    },
                  )
              ),
            ),

            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: ListTile(
                  title: Text(title2),
                  trailing: PopupMenuButton(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10))
                    ),
                    color: Colors.white,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                          child: Text(lang2),
                          value: 'en'),
                      PopupMenuItem(
                        child: Text(lang1),
                        value: 'Vietnamese',)
                    ],
                    onSelected: (String newValue) {
                      setState(() {
                        lang = newValue;
                      });
                    },
                  )
              ),
            ),
            // Container(
            //   decoration: BoxDecoration(
            //     borderRadius: BorderRadius.circular(10),
            //     color: Colors.white,
            //   ),
            //   child: ListTile(
            //     leading: Icon(Icons.refresh),
            //     title: Text('Update Widget'),
            //     onTap: () async {
            //       await WidgetService.updateWidgetData();
            //       ScaffoldMessenger.of(context).showSnackBar(
            //         SnackBar(content: Text('Widget updated successfully')),
            //       );
            //     },
            //   ),
            // ),
            SizedBox(height: 10,),
            Divider(),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: ListTile(
                title: Text('Privacy Policy'),

              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: ListTile(
                title: Text('Authority'),
              ),
            ),
            SizedBox(height: 10,),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: ListTile(
                title: Text('About us'),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: ListTile(
                title: Text('About Weather Forecast'),
              ),
            ),
            Divider(),
            _buildDatabaseResetSection()

          ],
        )
    );
  }

  // Đây là một widget có thể thêm vào màn hình Setting
  Widget _buildDatabaseResetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Database Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: Icon(Icons.cleaning_services_outlined),
          title: Text('Clear Weather Data'),
          subtitle: Text('Keep locations but remove all weather data'),
          onTap: () async {
            bool confirm = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Clear Weather Data'),
                content: Text('This will remove all weather data but keep your saved locations. Continue?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('Clear', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ) ?? false;

            if (confirm) {
              await DatabaseHelper().clearAllData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Weather data cleared successfully!')),
              );
            }
          },
        ),
        ListTile(
          leading: Icon(Icons.restore, color: Colors.red),
          title: Text('Reset Database'),
          subtitle: Text('Remove all data including saved locations'),
          onTap: () async {
            bool confirm = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Reset Database'),
                content: Text('This will completely reset the database and remove ALL data including your saved locations. This action cannot be undone. Continue?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('Reset', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ) ?? false;

            if (confirm) {
              await DatabaseHelper().resetDatabase();
              // Reset global variables
              LocationName = '';
              InitialName = '';
              KeyLocation = null;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Database reset successfully!')),
              );
              // Restart app or navigate back to home
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => HomePage()),
              );
            }
          },
        ),
      ],
    );
  }
}