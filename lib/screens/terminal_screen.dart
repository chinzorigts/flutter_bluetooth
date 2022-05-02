import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth/core/constants/colors/colors.dart';
import 'package:flutter_bluetooth/core/constants/styles/styles.dart';
import 'package:flutter_bluetooth/data/model/command_model.dart';
import 'package:flutter_bluetooth/screens/widgets/app_alert.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';
import 'package:lottie/lottie.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class TerminalScreen extends StatefulWidget{

  final BluetoothCharacteristic characteristic;
  final Stream<BluetoothDeviceState> deviceState;


  const TerminalScreen({Key? key, required this.characteristic, required this.deviceState,}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _TerminalScreenState();
  }
}

class _TerminalScreenState extends State<TerminalScreen>{

  List<CommandModel> listCommandModel = [];

  var bluePus = FlutterBluePlus.instance;
  StreamSubscription? _streamListCommand;

  final _textEditingControllerCommand = TextEditingController();

  final itemScrollController = ItemScrollController();
  final itemPositionsListener = ItemPositionsListener.create();

  var lastItemIndex = 0;
  var realItemIndex = 0;

  bool disconnected = false;
  bool reserved = false;

  @override
  void initState() {
    super.initState();

    widget.deviceState.asBroadcastStream().listen((event) async {
      debugPrint('DEVICE STATE ==> $event');
      if(event == BluetoothDeviceState.disconnected){
        disconnected = true;
        await AppAlert.showBottomToast(message: 'Device is disconnected');
        setState(() {});
      }
    });

    itemPositionsListener.itemPositions.addListener(() {
      if(itemPositionsListener.itemPositions.value.isNotEmpty){
        lastItemIndex = itemPositionsListener.itemPositions.value.map((e) => e.index).toList().last;
        debugPrint(lastItemIndex.toString());
      }
    });
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    if(_streamListCommand != null){
      await _streamListCommand!.cancel();
    }
    _textEditingControllerCommand.dispose();
  }

  Future<void> scrollToItem() async{
    if(realItemIndex > lastItemIndex){
      await itemScrollController.scrollTo(
        index: realItemIndex,
        duration: const Duration(milliseconds: 500),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Terminal'),
          actions: [
            IconButton(
                onPressed: () => _deleteCommandLine(),
                icon: const Icon(LineIcons.trash,)
            )
          ],
        ),
        body: IndexedStack(
          index: disconnected ? 0 : 1,
          children: [
            Center(
              child: Column(
                children: <Widget>[
                  Lottie.asset('assets/lotties/no_connection.json', animate: true, repeat: true),
                  const SizedBox(height: 16,),
                  Text('Device disconnected...' , style: AppStyle.textBody4,)
                ],
              )
            ),
            Stack(
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.only(bottom: 60.0),
                  child:
                  ScrollablePositionedList.builder(
                    itemCount: listCommandModel.length,
                    itemBuilder: (BuildContext context, int index) {
                      realItemIndex = index;
                      return _buildConsoleListRow(index);
                    },
                    itemScrollController: itemScrollController,
                    itemPositionsListener: itemPositionsListener,
                    scrollDirection: Axis.vertical,
                  ),
                ),
                //BOTTOM WIDGET TEXT FIELD AND SEND BUTTON
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: const EdgeInsets.only(left: 10.0, bottom: 10.0, top: 10.0),
                    height: 60,
                    width: double.infinity,
                    color: Colors.white,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                                hintText: 'Input command text...',
                                hintStyle: TextStyle(color: Colors.black54),
                                border: InputBorder.none
                            ),
                            controller: _textEditingControllerCommand,
                          ),
                        ),
                        const SizedBox(width: 15,),
                        FloatingActionButton(
                          onPressed: () async {
                            await widget.characteristic.setNotifyValue(!widget.characteristic.isNotifying);
                            setState(() {});
                          },
                          child: Icon(widget.characteristic.isNotifying ? LineIcons.stop : LineIcons.play, color: Colors.white, size: 18,),
                          backgroundColor: widget.characteristic.isNotifying ? AppColors.error : AppColors.indiaGreen,
                          elevation: 5,
                          heroTag: null,
                        ),
                        FloatingActionButton(
                          onPressed: () async {
                            await _putCommandData(_textEditingControllerCommand.text);
                            if(_textEditingControllerCommand.text.isNotEmpty) {
                              _textEditingControllerCommand.clear();
                            }
                            if(mounted){
                              setState(() {});
                            }
                          },
                          child: const Icon(LineIcons.paperPlane, color: Colors.white, size: 18,),
                          backgroundColor: Colors.blue,
                          elevation: 5,
                          heroTag: null,
                        ),
                      ],
                    ),
                  ),
                )
              ],
            )
          ],
        )

    );
  }

  _buildConsoleListRow(int index){
   return Container(
     padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 10.0, bottom: 10.0),
     child: Row(
       children: <Widget>[
         Text(listCommandModel[index].dateTimeNow.toString(), style: AppStyle.textBody5),
         const SizedBox(width: 10,),
         Flexible(
           child: Text(listCommandModel[index].command.toString(), style: listCommandModel[index].isCommandText ? AppStyle.textBody7 : AppStyle.textBody6, softWrap: true),
         ),
       ],
     ),
   );
  }

  Future<void> _putCommandData(String command) async {
    CommandModel _commandModel;
    _commandModel = CommandModel(true, DateFormat('HH:mm:ss').format(DateTime.now()), command);
    listCommandModel.add(_commandModel);

    var charac = widget.characteristic;

    if(_streamListCommand != null ){
      debugPrint('CANCELING STREAM LIST COMMAND HERE ...');
      await _streamListCommand!.cancel();
    }

    await charac.write(command.codeUnits, withoutResponse: false);
    await charac.setNotifyValue(true);
    _streamListCommand = charac.value.listen((event) async {
      debugPrint('CHARACTERISTIC VALUE LISTEN HERE ===== > ');
      if(event.isNotEmpty){
        _commandModel = CommandModel(false, DateFormat('HH:mm:ss').format(DateTime.now()), String.fromCharCodes(event));
        listCommandModel.add(_commandModel);
        if(mounted){
          await scrollToItem();
          setState(() {});
        }
      }
    });
  }

  _deleteCommandLine(){
    if(listCommandModel.isNotEmpty)
      {
        listCommandModel.clear();
      }
    setState(() {});
  }
}