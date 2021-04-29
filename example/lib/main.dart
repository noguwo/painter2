import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:painter2/painter2.dart';
import 'dart:typed_data';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Painter2 Example',
      home: ExamplePage(),
    );
  }
}

class ExamplePage extends StatefulWidget {
  @override
  _ExamplePageState createState() => new _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  late bool _finished;
  late PainterController _controller;
  late List<PathPoints> _pathPonts;
  late MyPaths _myNote;

  @override
  void initState() {
    super.initState();
    _finished = false;
    _controller = newController();
  }

  PainterController newController() {
    PainterController controller = PainterController();
    controller.thickness = 5.0;
    controller.backgroundColor = Colors.white;
    //controller.backgroundImage = Image.network('https://cdn-images-1.medium.com/max/1200/1*5-aoK8IBmXve5whBQM90GA.png');
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actions;
    if (_finished) {
      actions = <Widget>[
        IconButton(
          icon: Icon(Icons.content_copy),
          tooltip: 'New Painting',
          onPressed: () => setState(() {
                _finished = false;
                _controller = newController();
              }),
        ),
      ];
    } else {
      actions = <Widget>[
        IconButton(
          icon: Icon(Icons.undo),
          tooltip: 'Undo',
          onPressed: () {
            if (_controller.canUndo) _controller.undo();
          },
        ),
        IconButton(
          icon: Icon(Icons.redo),
          tooltip: 'Redo',
          onPressed: () {
            if (_controller.canRedo) _controller.redo();
          },
        ),
        IconButton(
          icon: Icon(Icons.delete),
          tooltip: 'Clear',
          onPressed: () => _controller.clear(),
        ),
        IconButton(
            icon: Icon(Icons.check),
            onPressed: () async {
              setState(() {
                _finished = true;
              });
              _pathPonts = [];
              _pathPonts = _controller.getPathPoints();

              _myNote = new MyPaths(
                  width: 0,
                  height: 0,
                  backGroundColor: 0,
                  pathPoints: []
              );
              _myNote = _controller.getMyPaths();
              var n = jsonEncode(_myNote);
              print(n);

              var q = jsonEncode(_pathPonts);
              print(q);

              Uint8List bytes = await _controller.exportAsPNGBytes();
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (BuildContext context) {
                return Scaffold(
                  appBar: AppBar(
                    title: Text('View your image'),
                  ),
                  body: Container(
                    child: Image.memory(bytes),
                  ),
                );
              }));
            }),
        IconButton(
          icon: Icon(Icons.restore),
          onPressed: () {
            //_controller.setPathPoints(_pathPonts);
            _controller.loadPaths(_myNote);
            setState(() {
              _finished = false;
            });
          },
        )
      ];
    }
    return Scaffold(
      appBar: AppBar(
          title: Text('Painter2 Example'),
          actions: actions,
          bottom: PreferredSize(
            child: DrawBar(_controller),
            preferredSize: Size(MediaQuery.of(context).size.width, 34.0),
          )),
      body: Center(
          child: Painter(_controller)),
    );
  }
}

class DrawBar extends StatelessWidget {
  final PainterController _controller;

  DrawBar(this._controller);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Flexible(child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return Container(
              child: Slider(
            value: _controller.thickness,
            onChanged: (value) => setState(() {
                  _controller.thickness = value;
                }),
            min: 1.0,
            max: 20.0,
            activeColor: Colors.white,
          ));
        })),
        ColorPickerButton(_controller, false),
        ColorPickerButton(_controller, true),
      ],
    );
  }
}

class ColorPickerButton extends StatefulWidget {
  final PainterController _controller;
  final bool _background;

  ColorPickerButton(this._controller, this._background);

  @override
  _ColorPickerButtonState createState() => new _ColorPickerButtonState();
}

class _ColorPickerButtonState extends State<ColorPickerButton> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_iconData, color: _color),
      tooltip:
          widget._background ? 'Change background color' : 'Change draw color',
      onPressed: () => _pickColor(),
    );
  }

  void _pickColor() {
    Color pickerColor = _color;
    Navigator.of(context)
        .push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (BuildContext context) {
              return Scaffold(
                  appBar: AppBar(
                    title: Text('Pick color'),
                  ),
                  body: Container(
                      alignment: Alignment.center,
                      child: ColorPicker(
                        pickerColor: pickerColor,
                        onColorChanged: (Color c) => pickerColor = c,
                      )));
            }))
        .then((_) {
      setState(() {
        _color = pickerColor;
      });
    });
  }

  Color get _color => widget._background
      ? widget._controller.backgroundColor
      : widget._controller.drawColor;

  IconData get _iconData =>
      widget._background ? Icons.format_color_fill : Icons.brush;

  set _color(Color color) {
    if (widget._background) {
      widget._controller.backgroundColor = color;
    } else {
      widget._controller.drawColor = color;
    }
  }
}
