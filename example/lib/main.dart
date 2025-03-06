import 'package:flutter/material.dart';
import 'package:reorderable_plus/flutter_spanablegrid.dart';
import 'package:reorderable_plus/reorderable.dart' as reorder;
import 'package:reorderable_plus/reorderable.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return _ReorderGridView(title: widget.title);
  }
}

class _ReorderGridView extends StatefulWidget {
  const _ReorderGridView({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<_ReorderGridView> createState() => _ReorderGridViewState();
}

class _ReorderGridViewState extends State<_ReorderGridView> {
  final data = List.generate(30, (index) => index);

  List<GridTileOrigin> list = [
    GridTileOrigin(2, 140, const ValueKey(1)),
    GridTileOrigin(2, 64, const ValueKey(2)),
    GridTileOrigin(2, 64, const ValueKey(3)),
    GridTileOrigin(2, 64, const ValueKey(4)),
    GridTileOrigin(2, 64, const ValueKey(5)),
    GridTileOrigin(2, 140, const ValueKey(6)),
    GridTileOrigin(2, 64, const ValueKey(7)),
    GridTileOrigin(2, 64, const ValueKey(8)),
    GridTileOrigin(2, 140, const ValueKey(9)),
    GridTileOrigin(2, 140, const ValueKey(11)),
    GridTileOrigin(2, 64, const ValueKey(12)),
    GridTileOrigin(2, 64, const ValueKey(13)),
    GridTileOrigin(2, 64, const ValueKey(14)),
    GridTileOrigin(2, 64, const ValueKey(15)),
    GridTileOrigin(2, 140, const ValueKey(16)),
    GridTileOrigin(2, 64, const ValueKey(17)),
    GridTileOrigin(2, 64, const ValueKey(18)),
    GridTileOrigin(2, 140, const ValueKey(19)),
  ];

  GlobalKey<SliverReorderableGridState> key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      floatingActionButton: FloatingActionButton(
        child: GestureDetector(
            onTap: () {
              key.currentState?.updateSize(
                const ValueKey(2),
                GridTileOrigin(4, 140, const ValueKey(2)),
              );
            },
            onDoubleTap: () {
              list = [
                ...list,
                GridTileOrigin(2, 64, const ValueKey(5)),
              ];
              key.currentState?.resetItemSize();
              setState(() {});
            },
            child: const Icon(Icons.add)),
        onPressed: () {
          key.currentState?.updateSize(
            const ValueKey(2),
            GridTileOrigin(2, 140, const ValueKey(2)),
          );
        },
      ),
      body: CustomScrollView(
        // reverse: true,
        slivers: [
          reorder.SliverReorderableGrid(
            key: key,
            gridDelegate: HomeGridDelegate([...list]),
            itemBuilder: (context, int index) {
              final item = list[index];
              return reorder.ReorderableDelayedDragStartListener(
                key: item.key,
                index: index,
                // enabled: item % 2 == 0,
                child: Container(
                  alignment: Alignment.center,
                  color: Colors.green.withOpacity(0.6),
                  child: Text('${item.key}'),
                ),
              );
            },
            itemCount: list.length,
            onReorder: (oldIndex, newIndex) {
              debugPrint('onReorder: $oldIndex -> $newIndex');
              final origin = list.removeAt(oldIndex);
              list.insert(newIndex, origin);
              setState(() {});
            },
            onReorderStart: (p0) {
              debugPrint('onReorderStart');
            },
            onReorderEnd: (p0) {
              debugPrint('onReorderEnd');
            },
            proxyDecorator: (child, index, animation) {
              return Container(
                color: Colors.red.withOpacity(0.3),
                height: 160,
                child: child,
              );
            },
            shadowBuilder: (Widget child) {
              return Opacity(
                opacity: 0.2,
                child: child,
              );
            },
          ),
        ],
      ),
    );
  }
}
