library painter;

import 'dart:convert';

import 'package:flutter/material.dart' as mat show Image;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Image;
import 'dart:ui';
import 'dart:async';
import 'dart:typed_data';

class Painter extends StatefulWidget {
  final PainterController painterController;

  Painter(PainterController painterController)
      : this.painterController = painterController,
        super(key: ValueKey<PainterController>(painterController));

  @override
  _PainterState createState() => _PainterState();
}

class _PainterState extends State<Painter> {
  final GlobalKey _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.painterController._globalKey = _globalKey;
  }

  @override
  Widget build(BuildContext context) {
    Widget child = CustomPaint(
      willChange: true,
      painter: _PainterPainter(widget.painterController._pathHistory,
          repaint: widget.painterController),
    );
    child = ClipRect(child: child);
    if (widget.painterController.backgroundImage == null) {
      child = RepaintBoundary(
        key: _globalKey,
        child: GestureDetector(
          child: child,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
        ),
      );
    } else {
      child = RepaintBoundary(
        key: _globalKey,
        child: Stack(
          alignment: FractionalOffset.center,
          fit: StackFit.expand,
          children: <Widget>[
            widget.painterController.backgroundImage!,
            GestureDetector(
              child: child,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
            )
          ],
        ),
      );
    }
    return Container(
      child: child,
      width: double.infinity,
      height: double.infinity,
    );
  }

  void _onPanStart(DragStartDetails start) {
    Offset pos = (context.findRenderObject() as RenderBox)
        .globalToLocal(start.globalPosition);
    widget.painterController._pathHistory.add(pos);
    widget.painterController._notifyListeners();
  }

  void _onPanUpdate(DragUpdateDetails update) {
    Offset pos = (context.findRenderObject() as RenderBox)
        .globalToLocal(update.globalPosition);
    widget.painterController._pathHistory.updateCurrent(pos);
    widget.painterController._notifyListeners();
  }

  void _onPanEnd(DragEndDetails end) {
    widget.painterController._pathHistory.endCurrent();
    widget.painterController._notifyListeners();
  }
}

class _PainterPainter extends CustomPainter {
  final _PathHistory _path;

  _PainterPainter(this._path, {required Listenable repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    _path.draw(canvas, size);
  }

  @override
  bool shouldRepaint(_PainterPainter oldDelegate) => true;
}

class _PathHistory {
  late List<MapEntry<Path, Paint>> _paths;
  late List<MapEntry<Path, Paint>> _undone;
  late Paint currentPaint;
  late Paint _backgroundPaint;
  late bool _inDrag;
  late double _width;
  late double _height;
  late double _startX; //start X with a tap
  late double _startY; //start Y with a tap
  bool _startFlag = false;
  bool _erase = false;
  double _eraseArea = 1.0;
  bool _pathFound = false;
  late List<PathPoints> _pathPoints;
  late List<PathPoints> _pathPointsUnDone;
  late MyPaths _myPaths;
  late bool _updated;

  _PathHistory() {
    _paths = [];
    _undone = [];
    _pathPoints = [];
    _pathPointsUnDone = [];
    _myPaths = MyPaths(
        height: 0,
        width: 0,
        backGroundColor: 0,
        pathPoints: []
    );
    _inDrag = false;
    _backgroundPaint = Paint();
    _updated = false;
  }

  bool canUndo() => _paths.length > 0;

  bool get erase => _erase;
  set erase(bool e) {
    _erase = e;
  }

  set eraseArea(double r) {
    _eraseArea = r;
  }

  bool get updated => _updated;
  set updated(bool u) {
    _updated = u;
  }

  void undo() {
    if (!_inDrag && canUndo()) {
      _undone.add(_paths.removeLast());
      _pathPointsUnDone.add(_pathPoints.removeLast());
    }
  }

  bool canRedo() => _undone.length > 0;

  void redo() {
    if (!_inDrag && canRedo()) {
      _paths.add(_undone.removeLast());
      _pathPoints.add(_pathPointsUnDone.removeLast());
    }
  }

  void clear() {
    if (!_inDrag) {
        _paths.clear();
        _undone.clear();
        _pathPoints.clear();
        _updated = false;
    }
  }

  void loadStartXY(PathPoints pathPoints) {
    Path path = Path();
    Paint paint = Paint();

    paint.style = getPaintingStyle(pathPoints.paintingStyle)!;
    paint.strokeWidth = pathPoints.lineThicknes;
    paint.color = Color(pathPoints.lineColor);

    path.moveTo(pathPoints.startX, pathPoints.startY);

    _paths.add(MapEntry<Path, Paint>(path, paint));
  }

  void load(int lineColor, double lineThicknes, double lineToX, double lineToY, bool singlePoint) {

      Path loopPath = _paths.last.key;

      if (!singlePoint) {
          loopPath.lineTo(lineToX, lineToY);
      } else {
        loopPath.addOval(Rect.fromCircle(center: new Offset(lineToX, lineToY), radius: 1.0));
      }
  }

  PaintingStyle? getPaintingStyle(String paintingStyleAsString) {
    for (PaintingStyle element in PaintingStyle.values) {
      if (element.toString() == paintingStyleAsString) {
        return element;
      }
    }
    return null;
  }

  Color get backgroundColor => _backgroundPaint.color;
  set backgroundColor(color) => _backgroundPaint.color = color;

  void add(Offset startPoint) {
    if (!_inDrag) {
      _inDrag = true;
      _startFlag = true;
      _startX = startPoint.dx;
      _startY = startPoint.dy;

      if(!_erase) {
        PathPoints pathPoints = PathPoints(
            startX: startPoint.dx,
            startY: startPoint.dy,
            lineToX: [],
            lineToY: [],
            lineThicknes: currentPaint.strokeWidth,
            lineColor: currentPaint.color.value,
            paintingStyle: currentPaint.style.toString(),
            singlePoint: true
        );
        _pathPoints.add(pathPoints);

        Path path = Path();
        path.moveTo(startPoint.dx, startPoint.dy);

        _paths.add(MapEntry<Path, Paint>(path, currentPaint));
      }
    }
  }

  void updateCurrent(Offset nextPoint) {
    if (_inDrag) {
      _pathFound = false;
      if (!_erase) {
        Path path = _paths.last.key;
        path.lineTo(nextPoint.dx, nextPoint.dy);

        print("dx :"+nextPoint.dx.toString());
        print("dy :"+nextPoint.dy.toString());

        PathPoints pathPoints = _pathPoints.last;
        pathPoints.lineToX.add(nextPoint.dx);
        pathPoints.lineToY.add(nextPoint.dy);
        pathPoints.singlePoint = false;

        _startFlag = false;
        _updated = true;
      } else {
        erasePath(nextPoint.dx, nextPoint.dy);
        _startFlag = false;
      }
    }
  }

  void erasePath(double dx, double dy) {
    for (int i=0; i<_paths.length; i++) {
      _pathFound = false;
      for (double x = dx - _eraseArea; x <= dx + _eraseArea; x++) {
        for (double y = dy - _eraseArea; y <= dy + _eraseArea; y++) {
          if (_paths[i].key.contains(new Offset(x, y)))
          {
            _pathPointsUnDone.add(_pathPoints.removeAt(i));
            _undone.add(_paths.removeAt(i));
            i--;
            _pathFound = true;
            _updated = true;
            break;
          }
        }
        if (_pathFound) {
          break;
        }
      }
    }
  }

  void endCurrent() {
    _inDrag = false;
    Path path = _paths.last.key;
    if ((_startFlag) && (!_erase)) { //if it was just a tap, draw a point and reset a flag
      print("StartX: $_startX");
      print("StartY: $_startY");
      path.addOval(Rect.fromCircle(center: new Offset(_startX, _startY), radius: 1.0));
      _updated = true;
      _startFlag = false;
    }
    if ((_startFlag) && (_erase)) {
      erasePath(_startX, _startY);
      _startFlag = false;
    }
  }

  void draw(Canvas canvas, Size size) {
    _width = size.width;
    _height = size.height;
    canvas.drawRect(
        Rect.fromLTWH(0.0, 0.0, size.width, size.height), _backgroundPaint);
    for (MapEntry<Path, Paint> path in _paths) {
      canvas.drawPath(path.key, path.value);
    }
  }
}

class PainterController extends ChangeNotifier {
  Color _drawColor = Color.fromARGB(255, 0, 0, 0);
  Color _backgroundColor = Color.fromARGB(255, 255, 255, 255);
  mat.Image? _bgimage;

  double _thickness = 1.0;
  double _erasethickness = 1.0;
  late _PathHistory _pathHistory;
  late GlobalKey _globalKey;

  PainterController() {
    _pathHistory = _PathHistory();
  }

  Color get drawColor => _drawColor;
  set drawColor(Color color) {
    _drawColor = color;
    _updatePaint();
  }

  Color get backgroundColor => _backgroundColor;
  set backgroundColor(Color color) {
    _backgroundColor = color;
    _updatePaint();
  }

  mat.Image? get backgroundImage => _bgimage;
  set backgroundImage(mat.Image? image) {
    _bgimage = image;
    _updatePaint();
  }

  double get thickness => _thickness;
  set thickness(double t) {
    _thickness = t;
    _updatePaint();
  }

  double get erasethickness => _erasethickness;
  set erasethickness(double t) {
    _erasethickness = t;
    _pathHistory._eraseArea = t;
    _updatePaint();
  }

  bool get eraser => _pathHistory.erase; //setter / getter for eraser
  set eraser(bool e) {
    _pathHistory.erase = e;
    _pathHistory._eraseArea =  _erasethickness;
    _updatePaint();
  }

  bool get updated => _pathHistory.updated;
  set updated(bool u) {
    _pathHistory.updated = u;
  }

  List<PathPoints> getPathPoints() {
    return _pathHistory._pathPoints;
  }

  MyPaths getMyPaths() {
    _pathHistory._myPaths.pathPoints = getPathPoints();
    _pathHistory._myPaths.width = _pathHistory._width;
    _pathHistory._myPaths.height = _pathHistory._height;
    _pathHistory._myPaths.backGroundColor = _pathHistory.backgroundColor.value;
    return _pathHistory._myPaths;
  }


  void setPathPoints(List<PathPoints> setPoints) {
    _pathHistory.clear();
    notifyListeners();

    for (PathPoints item in setPoints) {
      _pathHistory.loadStartXY(item);
      notifyListeners();

      if (!item.singlePoint) {
          for (int i = 0; i<item.lineToX.length; i++) {
            _pathHistory.load(item.lineColor, item.lineThicknes, item.lineToX[i], item.lineToY[i], item.singlePoint);
          }
       } else {
           _pathHistory.load(item.lineColor, item.lineThicknes, item.startX, item.startY, item.singlePoint);
       }
      notifyListeners();
    }
    _pathHistory._pathPoints = setPoints;
  }

  void loadPaths(MyPaths myPaths) {
    //_backgroundColor = Color(myPaths.backGroundColor);
    backgroundColor = Color(myPaths.backGroundColor);
    _updatePaint();
    setPathPoints(myPaths.pathPoints);
    notifyListeners();
  }

  void _updatePaint() {
    Paint paint = Paint();
    paint.color = drawColor;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = thickness;
    _pathHistory.currentPaint = paint;
    if (_bgimage != null) {
      _pathHistory.backgroundColor = Color(0x00000000);
    } else {
      _pathHistory.backgroundColor = _backgroundColor;
    }
    notifyListeners();
  }

  void undo() {
    _pathHistory.undo();
    notifyListeners();
  }

  void redo() {
    _pathHistory.redo();
    notifyListeners();
  }

  bool get canUndo => _pathHistory.canUndo();
  bool get canRedo => _pathHistory.canRedo();

  void _notifyListeners() {
    notifyListeners();
  }

  void clear() {
    _pathHistory.clear();
    notifyListeners();
  }

  Future<Uint8List> exportAsPNGBytes() async {
    final pixelRatio = MediaQuery.of(_globalKey.currentContext!).devicePixelRatio;
    //TODO: check boundary on null!
    RenderRepaintBoundary? boundary =
        _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    Image image = await boundary.toImage(pixelRatio: pixelRatio);
    ByteData byteData = (await image.toByteData(format: ImageByteFormat.png))!;
    return byteData.buffer.asUint8List();
  }
}

class PathPoints {
  double startX;
  double startY;
  List<double> lineToX = [];
  List<double> lineToY = [];
  String paintingStyle;
  double lineThicknes;
  int lineColor;
  bool singlePoint = true;

  PathPoints({
    required this.startX,
    required this.startY,
    required this.lineToX,
    required this.lineToY,
    required this.paintingStyle,
    required this.lineThicknes,
    required this.lineColor,
    required this.singlePoint
  });

  Map<String, dynamic> toJson() =>
      {
        'startX' : startX,
        'startY' : startY,
        'lineToX' : lineToX,
        'lineToY' : lineToY,
        'paintingStyle' : paintingStyle,
        'lineThicknes' : lineThicknes,
        'lineColor' : lineColor,
        'singlePoint' : singlePoint,
      };

  factory PathPoints.fromJson(Map<String, dynamic> parsedJson) {
    var x = jsonDecode(parsedJson['lineToX'].toString());
    if (x==null) {x = [];}

    var y = jsonDecode(parsedJson['lineToY'].toString());
    if (y==null) {y = [];}

    return PathPoints(
        startX: parsedJson["startX"],
        startY: parsedJson["startY"],
        lineToX : x.cast<double>(),
        lineToY : y.cast<double>(),
        paintingStyle : parsedJson["paintingStyle"],
        lineThicknes : parsedJson["lineThicknes"],
        lineColor : parsedJson["lineColor"],
        singlePoint : parsedJson["singlePoint"],
    );
  }
}

class MyPaths {
  double width; //canvas' width
  double height; //canvas' height
  int backGroundColor;
  List<PathPoints> pathPoints;

  MyPaths({
    required this.width,
    required this.height,
    required this.backGroundColor,
    required this.pathPoints
  });

  Map<String, dynamic> toJson() =>
      {
        'width' : width,
        'height' : height,
        'backGroundColor' : backGroundColor,
        'pathPoints' : pathPoints,
      };

  factory MyPaths.fromJson(Map<String, dynamic> parsedJson)
  {
    List<PathPoints> pathPoints;
    if (parsedJson['pathPoints'].toString()!=null) {
      var list = parsedJson['pathPoints'] as List;
      pathPoints = list.map((i) => PathPoints.fromJson(i)).toList();
    } else {
      pathPoints = [];
    }

    return MyPaths(
      width: parsedJson["width"],
      height: parsedJson["height"],
      backGroundColor: parsedJson["backGroundColor"],
      pathPoints: pathPoints,
    );
  }
}