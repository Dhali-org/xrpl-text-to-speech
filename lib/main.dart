import 'dart:async';
import 'dart:html' as html;

import 'dart:convert';
import 'dart:io';
import 'dart:js_util';
import 'package:consumer_application/wallet.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/src/media_type.dart';
import 'package:logger/logger.dart';
import 'package:assets_audio_player/assets_audio_player.dart';

import 'package:xrpl/xrpl.dart';

import 'package:flutter/material.dart';

Future<void> main() async {
  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TextInputScreen(),
      //home: TakePictureScreen(
      //  // Pass the appropriate camera to the TakePictureScreen widget.
      //  camera: firstCamera,
      //),
    ),
  );
}

enum SnackBarTypes { error, success, inProgress }

class TextInputScreen extends StatefulWidget {
  @override
  TextInputScreenState createState() => TextInputScreenState();
}

class TextInputScreenState extends State<TextInputScreen> {
  XRPLWallet? _wallet;
  String _endPoint =
      "https://kernml-run-3mmgxhct.uc.gateway.dev/dhali-text-2-speech/run";
  Client client = Client('wss://s.altnet.rippletest.net:51233');
  ValueNotifier<String?> balance = ValueNotifier(null);
  String? mnemonic;
  final TextEditingController _mnemonicController = TextEditingController();
  final TextEditingController _authAmountController = TextEditingController();
  final TextEditingController _submissionTextController =
      TextEditingController();
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Input text to be spoken')),
        body: Column(children: [
          // If the Future is complete, display the preview.
          TextField(
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Lorem ipsum dolor sit amet',
            ),
            controller: _submissionTextController,
          ),
          _wallet == null
              ? SelectableText(
                  'Please activate your wallet and enter an authorised amount',
                  style: const TextStyle(fontSize: 25))
              : ValueListenableBuilder<String?>(
                  valueListenable: _wallet!.balance,
                  builder: (BuildContext context, String? balance, Widget? _) {
                    if (balance == null) {
                      return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Loading wallet: ",
                                style: TextStyle(fontSize: 25)),
                            CircularProgressIndicator()
                          ]);
                    }
                    return Column(
                      children: [
                        SelectableText('Classic address: ${_wallet!.address}',
                            style: const TextStyle(fontSize: 25)),
                        SelectableText('Balance: $balance XRP',
                            style: const TextStyle(fontSize: 25)),
                        TextField(
                          controller: _authAmountController,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              helperText:
                                  "This is the maximum number of drops Dhali can charge your wallet",
                              labelText: "Enter number of drops to authorize"),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly
                          ],
                        )
                      ],
                    );
                  })
        ]),
        floatingActionButton: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
                left: 30,
                bottom: 20,
                child: FloatingActionButton(
                  heroTag: "run",
                  tooltip: "Run inference",
                  onPressed: () async {
                    if (_wallet == null || _authAmountController.text == "") {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Invalid wallet'),
                          content: const Text(
                              'Please activate your wallet and set an authorised amount'),
                          actions: [
                            ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text('OK'))
                          ],
                        ),
                      );
                      return;
                    }

                    updateSnackBar(snackBarType: SnackBarTypes.inProgress);

                    // Take the Picture in a try / catch block. If anything goes wrong,
                    // catch the error.
                    try {
                      if (!mounted) return;
                      String dest =
                          "rstbSTpPcyxMsiXwkBxS9tFTrg2JsDNxWk"; // Dhali's address
                      String amount =
                          "10000000"; // The total amount escrowed in the channel
                      String authAmount = _authAmountController
                          .text; // The amount to authorise for the claim
                      var openChannels = await _wallet!
                          .getOpenPaymentChannels(destination_address: dest);
                      if (openChannels.isEmpty) {
                        openChannels = [
                          await _wallet!.openPaymentChannel(dest, amount)
                        ];
                      }
                      Map<String, String> paymentClaim = {
                        "account": _wallet!.address,
                        "destination_account": dest,
                        "authorized_to_claim": authAmount,
                        "signature": _wallet!
                            .sendDrops(authAmount, openChannels[0].channelId),
                        "channel_id": openChannels[0].channelId
                      };
                      Map<String, String> header = {
                        "Payment-Claim":
                            const JsonEncoder().convert(paymentClaim)
                      };
                      String entryPointUrlRoot = _endPoint;

                      var request = http.MultipartRequest(
                          "PUT", Uri.parse(entryPointUrlRoot));
                      request.headers.addAll(header);

                      var logger = Logger();
                      logger.d("Preparing file in body");
                      var textBytes = _submissionTextController.text.codeUnits;
                      request.files.add(http.MultipartFile(
                          contentType: MediaType('multipart', 'form-data'),
                          "input",
                          Stream.value(textBytes),
                          textBytes.length,
                          filename: "input"));

                      var finalResponse = await request.send();
                      logger.d("Status: ${finalResponse.statusCode}");
                      var response = json
                          .decode(await finalResponse.stream.bytesToString());
                      if (finalResponse.statusCode == 200) {
                        updateSnackBar(snackBarType: SnackBarTypes.success);
                        var blob = html.Blob(
                            response["results"], 'audio/mp3', 'native');
                        var url = html.Url.createObjectUrlFromBlob(blob);
                        final assetsAudioPlayer = AssetsAudioPlayer();
                        await assetsAudioPlayer.open(Audio.network(url));
                      } else {
                        updateSnackBar(
                            message: response.toString(),
                            snackBarType: SnackBarTypes.error);
                      }
                    } catch (e) {
                      updateSnackBar(snackBarType: SnackBarTypes.error);
                    } finally {
                      Future.delayed(const Duration(milliseconds: 1000), () {
                        setState(() {
                          updateSnackBar();
                        });
                      });
                    }
                  },
                  child: const Icon(Icons.speaker_notes),
                )),
            Positioned(
              bottom: 20,
              right: 30,
              child: FloatingActionButton(
                heroTag: "topup",
                tooltip: "Activate or top-up my wallet",
                onPressed: () async {
                  if (_wallet == null) {
                    showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            actions: [
                              ElevatedButton(
                                  onPressed: () {
                                    mnemonic = _mnemonicController.text;
                                    if (mnemonic != null) {
                                      setState(() {
                                        _wallet = XRPLWallet(mnemonic!,
                                            testMode: true);
                                      });
                                    }
                                    Navigator.pop(context);
                                  },
                                  child: const Text('OK'))
                            ],
                            title: const Text(
                                'Generate wallet using BIP-39 compatible words'),
                            content: TextField(
                              onChanged: (value) {},
                              controller: _mnemonicController,
                            ),
                          );
                        });
                  }
                  if (mnemonic != null) {
                    setState(() {
                      _wallet = XRPLWallet(mnemonic!, testMode: true);
                    });
                  }
                },
                child: const Icon(
                  Icons.wallet_sharp,
                  size: 40,
                ),
              ),
            ),
// Add more floating buttons if you want
          ],
        ));
  }

  void updateSnackBar({String? message, SnackBarTypes? snackBarType}) {
    SnackBar snackbar;
    if (snackBarType == SnackBarTypes.error) {
      snackbar = SnackBar(
        backgroundColor: Colors.red,
        content: Text(message == null
            ? 'An unknown error occured. Please wait 30 seconds and try again.'
            : message),
        duration: const Duration(seconds: 10),
      );
    } else if (snackBarType == SnackBarTypes.inProgress) {
      snackbar = const SnackBar(
        backgroundColor: Colors.blue,
        content: Text('Inference in progress. Please wait...'),
        duration: Duration(days: 365),
      );
    } else if (snackBarType == SnackBarTypes.success) {
      snackbar = const SnackBar(
        backgroundColor: Colors.green,
        content: Text('Success'),
        duration: Duration(seconds: 3),
      );
    } else {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(snackbar);
  }
}
