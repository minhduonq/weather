
import 'package:flutter/material.dart';
import '../services/constants.dart';
import '../services/widget_service.dart';

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



            Spacer(),
            Divider(color: Colors.lightBlueAccent,),

          ],
        )
    );
  }
}