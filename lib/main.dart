import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:web_audio';
import 'package:badges/badges.dart' as badges;
import 'package:consumer_application/accents_dropdown.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import 'dart:convert';
import 'package:consumer_application/wallet.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/src/media_type.dart';
import 'package:logger/logger.dart';

import 'package:xrpl/xrpl.dart';

import 'package:flutter/material.dart';

Future<void> main() async {
  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TextInputScreen(),
    ),
  );
}

enum SnackBarTypes { error, success, inProgress }

const Map<String, int> accents = {
  "American woman": 7391,
  "American man": 2100,
  "Scottish man": 100
};

class TextInputScreen extends StatefulWidget {
  @override
  TextInputScreenState createState() => TextInputScreenState();
}

class TextInputScreenState extends State<TextInputScreen> {
  String dhaliDebit = "0";
  int selectedAccentInt = 7361;
  XRPLWallet? _wallet;
  String _endPoint =
      "https://kernml-run-3mmgxhct.uc.gateway.dev/d79da1862-3366-4a06-ba72-47a1f8cdb483/run";
  Client client = Client('wss://s.altnet.rippletest.net:51233');
  ValueNotifier<String?> balance = ValueNotifier(null);
  String? mnemonic;
  final TextEditingController _mnemonicController = TextEditingController();
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
    return _wallet == null ? getWalletScaffold() : getInferenceScaffold();
  }

  Widget getInferenceScaffold() {
    return Scaffold(
        body: Column(children: [
          Spacer(flex: 1),
          Expanded(child: getHeader(), flex: 3),
          Spacer(flex: 5),
          _wallet == null
              ? SelectableText('Please activate your wallet!',
                  style: const TextStyle(fontSize: 25))
              : ValueListenableBuilder<String?>(
                  valueListenable: _wallet!.balance,
                  builder: (BuildContext context, String? balance, Widget? _) {
                    return Row(children: [
                      Spacer(flex: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText('Classic address: ${_wallet!.address}',
                              style: const TextStyle(fontSize: 25)),
                          balance == null
                              ? Row(children: [
                                  Text("Loading balance: ",
                                      style: TextStyle(fontSize: 25)),
                                  CircularProgressIndicator()
                                ])
                              : SelectableText(
                                  'Balance: ${double.parse(balance) - double.parse(dhaliDebit) / 1000000} XRP',
                                  style: const TextStyle(fontSize: 25)),
                        ],
                      ),
                      Spacer(flex: 10),
                      Expanded(
                          flex: 5,
                          child: DropdownAccentButton(
                            setValue: (value) {
                              setState(() {
                                if (accents[value] != null) {
                                  selectedAccentInt = accents[value]!;
                                }
                              });
                            },
                            options: accents,
                          )),
                      Spacer(flex: 5)
                    ]);
                  }),
          Spacer(flex: 1),
          Container(
            padding: EdgeInsets.fromLTRB(220, 0, 220, 0),
            child: TextField(
              maxLines: 10,
              minLines: 10,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Please enter the text to be spoken here',
              ),
              controller: _submissionTextController,
            ),
          ),
          Spacer(flex: 5),
        ]),
        floatingActionButton: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Spacer(flex: 3),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Linkify(
                    onOpen: (link) => html.window.open(link.url, 'new tab'),
                    text:
                        "GitHub repo https://github.com/Dhali-org/xrpl-text-to-speech/tree/develop",
                    style: const TextStyle(fontSize: 25)),
                Text(
                    "Note: costs are calculated based on input size.  This app uses the XRPL testnet.",
                    style: const TextStyle(fontSize: 25))
              ],
            ),
            Spacer(flex: 5),
            getInferenceFloatingActionButton(),
            Spacer(flex: 3)
          ],
        ));
  }

  Widget getInferenceFloatingActionButton() {
    return FloatingActionButton(
      heroTag: "run",
      tooltip: "Run inference",
      onPressed: () async {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        const int wordLimit = 15;
        if (_wallet == null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Invalid wallet'),
              content: const Text('Please activate your wallet!'),
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
        } else if (_submissionTextController.text == "") {
          updateSnackBar(
              message: "You must provide an input",
              snackBarType: SnackBarTypes.error);
          return;
        }

        updateSnackBar(snackBarType: SnackBarTypes.inProgress);
        try {
          List<String> sentences = _submissionTextController.text.split(".");
          List<double> audioSamples = [];
          bool successful = true;
          for (String sentence in sentences) {
            if (sentence == "") {
              continue;
            }
            String dest =
                "rstbSTpPcyxMsiXwkBxS9tFTrg2JsDNxWk"; // Dhali's address
            var openChannels = await _wallet!
                .getOpenPaymentChannels(destination_address: dest);
          String amount;
          String authAmount; // The amount to authorise for the claim
          if (openChannels.isNotEmpty) {
            amount = openChannels.first.amount.toString();
          } else {
            amount = (double.parse(_wallet!.balance.value!) * 1000000 ~/ 2)
                .toString(); // The total amount escrowed in the channel
            openChannels = [await _wallet!.openPaymentChannel(dest, amount)];
          }
          authAmount = amount;
          Map<String, String> paymentClaim = {
            "account": _wallet!.address,
            "destination_account": dest,
            "authorized_to_claim": authAmount,
            "signature":
                _wallet!.sendDrops(authAmount, openChannels[0].channelId),
            "channel_id": openChannels[0].channelId
          };
          Map<String, String> header = {
            "Payment-Claim": const JsonEncoder().convert(paymentClaim)
          };
          String entryPointUrlRoot = _endPoint;

          var request =
              http.MultipartRequest("PUT", Uri.parse(entryPointUrlRoot));
          request.headers.addAll(header);

          var logger = Logger();
          var textBytes = _submissionTextController.text.codeUnits;
            var input = '{"accent": $selectedAccentInt, "text": "$sentence."}';
          request.files.add(http.MultipartFile(
              contentType: MediaType('multipart', 'form-data'),
              "input",
              Stream.value(input.codeUnits),
              textBytes.length,
              filename: "input"));

          var finalResponse = await request.send();

          if (finalResponse.headers
                  .containsKey("dhali-total-requests-charge") &&
              finalResponse.headers["dhali-total-requests-charge"] != null) {
              dhaliDebit =
                  finalResponse.headers["dhali-total-requests-charge"]!;
          }

          logger.d("Status: ${finalResponse.statusCode}");
          var response =
              json.decode(await finalResponse.stream.bytesToString());
          if (finalResponse.statusCode == 200) {
              audioSamples.addAll(response["results"].cast<double>());
            } else {
              updateSnackBar(
                  message: response.toString(),
                  snackBarType: SnackBarTypes.error);
              throw Exception("Your text could not be converted successfully");
            }
          }

            updateSnackBar(snackBarType: SnackBarTypes.success);

            try {
              final audioContext = AudioContext();
              final audioBuffer =
                  audioContext.createBuffer(1, audioSamples.length, 16000);

              // Fill the buffer with the audio samples
              Float32List buffer = Float32List.fromList(audioSamples);
              audioBuffer.copyToChannel(buffer, 0);

              // Create a buffer source and connect it to the destination
              final audioBufferSource = audioContext.createBufferSource();
              audioBufferSource.buffer = audioBuffer;
              audioBufferSource.connectNode(audioContext.destination!);

              audioBufferSource.start(0);
            } catch (e, stacktrace) {
              print('Error playing audio: $e');
              print('Stack: ${stacktrace}');
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
      child: const Icon(
        Icons.play_arrow,
        size: 40,
        fill: 1,
      ),
    );
  }

  Widget getWalletFloatingActionButton(String text) {
    return FloatingActionButton.extended(
      heroTag: "getWallet",
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
                              _wallet = XRPLWallet(mnemonic!, testMode: true);
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
      label: Text(
        text,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget getHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        const Spacer(flex: 1),
        const SizedBox(
          width: 10,
        ),
        const Text(
          'Text to speech converter',
          textAlign: TextAlign.left,
          style: TextStyle(fontSize: 52),
        ),
        const Spacer(flex: 3),
        badges.Badge(
            position: badges.BadgePosition.topEnd(top: -2, end: -30),
            showBadge: true,
            ignorePointer: false,
            onTap: () {},
            badgeContent:
                const Icon(Icons.check, color: Colors.white, size: 10),
            badgeAnimation: const badges.BadgeAnimation.rotation(
              animationDuration: Duration(seconds: 1),
              colorChangeAnimationDuration: Duration(seconds: 1),
              loopAnimation: false,
              curve: Curves.fastOutSlowIn,
              colorChangeAnimationCurve: Curves.easeInCubic,
            ),
            badgeStyle: badges.BadgeStyle(
              shape: badges.BadgeShape.square,
              badgeColor: Colors.green,
              padding: const EdgeInsets.all(5),
              borderRadius: BorderRadius.circular(4),
              elevation: 0,
            ),
            child: RichText(
                text: TextSpan(
              style: const TextStyle(fontSize: 18),
              children: <TextSpan>[
                TextSpan(
                    text: 'Powered by Dhali',
                    style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launcher.launchUrl(Uri.parse(
                            "https://dhali-staging.web.app/#/assets/d79da1862-3366-4a06-ba72-47a1f8cdb483"));
                      }),
              ],
            ))),
        const Spacer(flex: 1),
      ],
    );
  }

  Widget getWalletScaffold() {
    return Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: Column(children: [
          Spacer(flex: 1),
          Expanded(child: getHeader(), flex: 3),
          Spacer(flex: 10),
          Expanded(
              child: SelectableText('Please activate your wallet!',
                  style: const TextStyle(fontSize: 25)),
              flex: 10),
        ]),
        floatingActionButton: getWalletFloatingActionButton("Get wallet"));
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
