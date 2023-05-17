import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:web_audio';
import 'package:badges/badges.dart' as badges;
import 'package:consumer_application/accents_dropdown.dart';
import 'package:consumer_application/download_file_widget.dart';
import 'package:consumer_application/wallet_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import 'dart:convert';
import 'package:consumer_application/wallet.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/src/media_type.dart';
import 'package:logger/logger.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:url_launcher/url_launcher.dart';

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
  "American woman 1": 7000,
  "American woman 2": 7391,
  "American woman 3": 6801,
  "American woman 4": 7900,
  "American man 1": 2100,
  "American man 2": 6100,
  "American man 3": 1300,
  "American man 4": 5000,
  "American man 5": 4000
};

class TextInputScreen extends StatefulWidget {
  @override
  TextInputScreenState createState() => TextInputScreenState();
}

class TextInputScreenState extends State<TextInputScreen> {
  String dhaliDebit = "0";
  int selectedAccentInt = 7361;
  XRPLWallet? _wallet;
  bool hideMnemonic = true;
  String _endPoint =
      "https://dhali-prod-run-dauenf0n.uc.gateway.dev/d0bf540f9-00f9-4637-8917-a048758d0d37/run";
  Client client = Client('wss://s.altnet.rippletest.net:51233');
  ValueNotifier<String?> balance = ValueNotifier(null);
  String? mnemonic;

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

  XRPLWallet? getWallet() {
    return _wallet;
  }

  Widget getAnimatedText(String text) {
    return AnimatedTextKit(
      animatedTexts: [
        TypewriterAnimatedText(
          text,
          textStyle: const TextStyle(
            fontSize: 32.0,
            fontWeight: FontWeight.bold,
          ),
          speed: const Duration(milliseconds: 50),
        ),
      ],
      repeatForever: true,
      pause: const Duration(milliseconds: 50),
      displayFullTextOnTap: true,
      stopPauseOnTap: true,
    );
  }

  Widget getInferenceScaffold() {
    return Scaffold(
      body: ListView(children: [
        SizedBox(
          height: 10,
        ),
        getHeader(),
        Container(
          height: MediaQuery.of(context).size.height / 5,
        ),
        Row(
          children: [
            Spacer(
              flex: 2,
            ),
            Text("Select accent:", style: const TextStyle(fontSize: 15)),
            Spacer(
              flex: 1,
            ),
            Expanded(
                flex: 6,
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
            Spacer(
              flex: 4,
            )
          ],
        ),
        Row(
          children: [
            Spacer(
              flex: 1,
            ),
            Expanded(
              flex: 10,
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
            Spacer(
              flex: 1,
            )
          ],
        ),
        const SizedBox(
          height: 10,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Spacer(flex: 8),
            getInferenceFloatingActionButton(),
            Spacer(flex: 1)
          ],
        ),
        Container(
          height: MediaQuery.of(context).size.height / 20,
        ),
        _wallet == null
            ? getAnimatedText('Please activate your wallet')
            : ValueListenableBuilder<String?>(
                valueListenable: _wallet!.balance,
                builder: (BuildContext context, String? balance, Widget? _) {
                  return Row(children: [
                    Container(
                      width: MediaQuery.of(context).size.width / 20,
                    ),
                    Container(
                        width: 17 * MediaQuery.of(context).size.width / 20,
                        child: FittedBox(
                            fit: BoxFit.fitWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                    'Classic address: ${_wallet!.address}',
                                    style: const TextStyle(fontSize: 15)),
                                Row(
                                  children: [
                                    const SelectableText('Memorable words: ',
                                        style: const TextStyle(fontSize: 15)),
                                    SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          hideMnemonic = !hideMnemonic;
                                        });
                                      },
                                      child: Icon(
                                        hideMnemonic
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Visibility(
                                      visible: !hideMnemonic,
                                      child: SelectableText(
                                        " ${_wallet!.mnemonic!}",
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ),
                                    Visibility(
                                      visible: hideMnemonic,
                                      child: SelectableText(
                                        "  " *
                                            (_wallet!.mnemonic!.length * 0.9)
                                                .toInt(),
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                                balance == null
                                    ? const Row(children: [
                                        Text("Loading balance: ",
                                            style: TextStyle(fontSize: 15)),
                                        CircularProgressIndicator()
                                      ])
                                    : SelectableText(
                                        'Balance: ${double.parse(balance) - double.parse(dhaliDebit) / 1000000} XRP',
                                        style: const TextStyle(fontSize: 15)),
                              ],
                            ))),
                    Container(
                      width: MediaQuery.of(context).size.width / 10,
                    ),
                  ]);
                }),
        SizedBox(height: 100),
        Container(
          width: MediaQuery.of(context).size.width / 6,
        ),
        Row(
          children: [
            Container(
              width: MediaQuery.of(context).size.width / 5,
            ),
            Container(
                width: 3 * MediaQuery.of(context).size.width / 5,
                child: FittedBox(
                    fit: BoxFit.fitWidth,
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'GitHub repo: ',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text:
                                'https://github.com/Dhali-org/xrpl-text-to-speech/tree/develop',
                            style: TextStyle(color: Colors.blue),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                launchUrl(Uri.parse(
                                    'https://github.com/Dhali-org/xrpl-text-to-speech/tree/develop'));
                              },
                          ),
                          TextSpan(
                            text:
                                "\nNote: costs are calculated based on input size.  This app uses the XRPL testnet.",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ))),
            Container(
              width: MediaQuery.of(context).size.width / 5,
            )
          ],
        ),
      ]),
    );
  }

  Widget getInferenceFloatingActionButton() {
    return FloatingActionButton(
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
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

          Float32List buffer = Float32List.fromList(audioSamples);

          final dataUri =
              'data:text/plain;base64,${base64Encode(getWavBytes(buffer, 16000))}';
          html.document.createElement('a') as html.AnchorElement
            ..href = dataUri
            ..download = 'output.wav'
            ..dispatchEvent(html.Event.eventType('MouseEvent', 'click'));

          try {
            final audioContext = AudioContext();
            final audioBuffer =
                audioContext.createBuffer(1, audioSamples.length, 16000);

            // Fill the buffer with the audio samples
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
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      heroTag: "getWallet",
      tooltip: "Activate or top-up my wallet",
      onPressed: () async {
        updateSnackBar(
            message: "This app currently uses the test XRP leger.",
            snackBarType: SnackBarTypes.error);
        if (_wallet == null) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => WalletHomeScreen(
                      title: "wallet",
                      getWallet: () {
                        return _wallet;
                      },
                      setWallet: (XRPLWallet wallet) {
                        setState(() {
                          _wallet = wallet;
                        });
                        Navigator.pop(context);
                      },
                    )),
          );
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
        badges.Badge(
            position: badges.BadgePosition.topEnd(top: -5, end: -45),
            showBadge: true,
            ignorePointer: false,
            onTap: () {},
            badgeContent: const Text(
              'Preview',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 10,
                color: Color.fromARGB(255, 186, 151, 255),
                fontWeight: FontWeight.bold,
              ),
            ),
            badgeStyle: badges.BadgeStyle(
              shape: badges.BadgeShape.square,
              badgeColor: Color.fromARGB(0, 0, 0, 0),
              padding: const EdgeInsets.all(5),
              borderRadius: BorderRadius.circular(4),
              elevation: 0,
            ),
            child: Text(
              'EchoText',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            )),
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
                            "https://dhali-app.web.app/#/assets/d0bf540f9-00f9-4637-8917-a048758d0d37"));
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
              child: getAnimatedText('Please activate your wallet'), flex: 10),
        ]),
        floatingActionButton: getWalletFloatingActionButton("Activate wallet"));
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
