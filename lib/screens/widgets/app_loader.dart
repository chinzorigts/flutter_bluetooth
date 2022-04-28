import 'package:flutter/cupertino.dart';
import 'package:flutter_bluetooth/core/constants/styles/styles.dart';
import 'package:lottie/lottie.dart';

class AppLoader extends StatelessWidget{

  final String? message;

  const AppLoader({Key? key, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      right: true,
      left: true,
      child: Center(
        child: Column(
          children: <Widget>[
            Lottie.asset('assets/lotties/circle_loader.json',
                animate: true,
                fit: BoxFit.fill,
                repeat: true,
                height: 100,
                width: 100
            ),
            const SizedBox(height: 10,),
            Text(message != null && message!.isNotEmpty ? message! : '', style: AppStyle.textBody3,)
          ],
        ),
      )
    );
  }

}