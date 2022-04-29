import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth/core/constants/colors/colors.dart';
import 'package:flutter_bluetooth/core/constants/styles/styles.dart';
import 'package:flutter_bluetooth/data/model/command_model.dart';
import 'package:intl/intl.dart';
import 'package:line_icons/line_icons.dart';

class TerminalScreen extends StatefulWidget{

  final BluetoothCharacteristic characteristic;

  const TerminalScreen({Key? key, required this.characteristic}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _TerminalScreenState();
  }
}

class _TerminalScreenState extends State<TerminalScreen>{

  List<CommandModel> listCommandModel = [];

  final _textEditingControllerCommand = TextEditingController();

  @override
  void initState() {
    super.initState();
  }


  @override
  void dispose() {
    super.dispose();
    _textEditingControllerCommand.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var _size = MediaQuery.of(context).size;

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
        body: Stack(
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: 60.0),
              child: ListView.builder(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                  itemCount: listCommandModel.length,
                  itemBuilder: (context, index){
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
                      onPressed: () async => await widget.characteristic.setNotifyValue(!widget.characteristic.isNotifying),
                      child: const Icon(LineIcons.stop, color: Colors.white, size: 18,),
                      backgroundColor: AppColors.error,
                      elevation: 5,
                    ),
                    FloatingActionButton(
                      onPressed: () {
                        _putCommandData(_textEditingControllerCommand.text);
                        if(_textEditingControllerCommand.text.isNotEmpty) {
                          _textEditingControllerCommand.clear();
                        }
                        setState(() {});
                      },
                      child: const Icon(LineIcons.paperPlane, color: Colors.white, size: 18,),
                      backgroundColor: Colors.blue,
                      elevation: 5,
                    ),
                  ],
                ),
              ),
            )
          ],
        )
    );
  }

  _putCommandData(String command) async {
    CommandModel _commandModel;
    StreamSubscription? _streamListCommand;

    _commandModel = CommandModel(true, DateFormat('HH:mm:ss').format(DateTime.now()), command);
    listCommandModel.add(_commandModel);

    var charac = widget.characteristic;

    if(charac.isNotifying && _streamListCommand != null ){
      await _streamListCommand.cancel();
    }

    await charac.write(command.codeUnits, withoutResponse: false);
    await charac.setNotifyValue(true);
    _streamListCommand = charac.value.listen((event) {
      debugPrint('CHARACTERISTIC VALUE LISTEN HERE ===== > ');
      if(event.isNotEmpty){
        _commandModel = CommandModel(false, DateFormat('HH:mm:ss').format(DateTime.now()), String.fromCharCodes(event));
        listCommandModel.add(_commandModel);
        setState(() {});
      }
    });
    setState(() {});
  }

  _deleteCommandLine(){
    if(listCommandModel.isNotEmpty)
      {
        listCommandModel.clear();
      }
  }
}