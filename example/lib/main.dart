import 'package:flutter/material.dart';
import 'package:monetization/monetization.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter + Web Monetization',
      home: MyHomePage(title: 'Web Monetization Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Monetization monetization;
  double total;

  @override
  void initState() {
    super.initState();
    setState(() {
      monetization = Monetization('\$pay.tomasarias.me', debug: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Color(0xFF6ADAAB),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image(
                image: AssetImage('assets/wm.png'),
                width: 275,
                height: 275,
              ),
            ),
            StreamBuilder(
                stream: monetization.onProgress,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text(
                      'Monetization not started yet',
                      style: Theme.of(context).textTheme.headline4,
                    );
                  }

                  return Text(
                    '${monetization.getTotal(formatted: true)} ${monetization.assetCode}',
                    style: Theme.of(context).textTheme.headline4,
                  );
                }),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RaisedButton(
                    onPressed: () => monetization.enable(),
                    child: Text(
                      'Start',
                      style: Theme.of(context).textTheme.headline6,
                    ),
                  ),
                  SizedBox(
                    width: 24,
                  ),
                  RaisedButton(
                    onPressed: () => monetization.disable(),
                    child: Text(
                      'Stop',
                      style: Theme.of(context).textTheme.headline6,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Tip: Open the DevTools to see the monetization events.',
              style: Theme.of(context).textTheme.overline,
            ),
          ],
        ),
      ),
    );
  }
}
