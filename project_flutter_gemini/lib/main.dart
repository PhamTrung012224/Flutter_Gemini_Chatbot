import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docx_to_text/docx_to_text.dart';

/// The API key to use when accessing the Gemini API.
///
/// To learn how to generate and specify this key,
/// check out the README file of this sample.
const String _apiKey = 'AIzaSyB1ba064lrSShRi-uQbJNnewAPdNKdt3V8';

void main() {
  runApp(const GenerativeAISample());
}

class GenerativeAISample extends StatelessWidget {
  const GenerativeAISample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Gemini',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: const Color(0xFFC5E5FA),
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(title: 'Flutter Gemini'),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.title});

  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36))),
        backgroundColor: const Color(0xFFF1F7FF),
        centerTitle: true,
        titleTextStyle: TextStyle(
            color: const Color(0xFF3B8BEE),
            fontSize: 24,
            fontFamily: GoogleFonts.poppins().fontFamily,
            fontWeight: FontWeight.bold),
        title: Text(widget.title),
      ),
      body: const ChatWidget(apiKey: _apiKey),
    );
  }
}

class ChatWidget extends StatefulWidget {
  const ChatWidget({
    required this.apiKey,
    super.key,
  });

  final String apiKey;

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  List<Image>? imageInput = [];
  List<DataPart>? imageData = [];
  List<TextPart>? textFromFiles = [];
  List<PlatformFile>? files = [];
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();
  final List<
      ({
        List<Image>? image,
        List<String>? textFromFiles,
        List<String>? text,
        List<PlatformFile>? file,
        bool fromUser
      })> _generatedContent = <({
    List<Image>? image,
    List<String>? textFromFiles,
    List<String>? text,
    List<PlatformFile>? file,
    bool fromUser
  })>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      safetySettings: [
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none)
      ],
      model: 'gemini-1.5-flash',
      apiKey: widget.apiKey,
    );
    _chat = _model.startChat(
      generationConfig: GenerationConfig(
        temperature: 1,
        topP: 0.95,
        topK: 64,
        maxOutputTokens: 8192,
        responseMimeType: "text/plain",
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(
          milliseconds: 400,
        ),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textFieldDecoration = InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: 'Enter a prompt...',
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );

    return GestureDetector(
      onTap: _textFieldFocus.unfocus,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _apiKey.isNotEmpty
                  ? ListView.builder(
                      controller: _scrollController,
                      itemBuilder: (context, idx) {
                        final content = _generatedContent[idx];
                        return MessageWidget(
                          text: content.text,
                          image: content.image,
                          file: content.file,
                          textFromFiles: content.textFromFiles,
                          isFromUser: content.fromUser,
                          scrollController: _scrollController,
                        );
                      },
                      itemCount: _generatedContent.length,
                    )
                  : ListView(
                      children: const [
                        Text(
                          'No API key found. Please provide an API Key using '
                          "'--dart-define' to set the 'API_KEY' declaration.",
                        ),
                      ],
                    ),
            ),
            if (imageInput?.isNotEmpty ?? false)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                width: MediaQuery.of(context).size.width,
                height: (imageInput!.length / 3).ceil() *
                    (MediaQuery.of(context).size.width / 3),
                child: GridView.builder(
                  itemCount: imageInput!.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10),
                  itemBuilder: (context, idx) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Image(
                        image: imageInput![idx].image,
                        width: MediaQuery.of(context).size.width / 3,
                        height: MediaQuery.of(context).size.width / 3,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            if (files?.isNotEmpty ?? false)
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.05,
                child: ListView.builder(
                  itemCount: files!.length,
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, idx) {
                    return Container(
                      margin: const EdgeInsets.only(left: 4, right: 4),
                      padding: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFA2E6FF),
                          borderRadius: BorderRadius.circular(5)),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 24,
                              height: 24,
                              child: (files![idx].extension == 'pdf')
                                  ? const Image(
                                      image:
                                          AssetImage('assets/images/pdf.png'))
                                  : const Image(
                                      image:
                                          AssetImage('assets/images/doc.png'))),
                          Text(' ${files![idx].name}'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(
                  left: 2.0, right: 2.0, top: 4.0, bottom: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      focusNode: _textFieldFocus,
                      decoration: textFieldDecoration,
                      controller: _textController,
                      onSubmitted: _sendChatMessage,
                    ),
                  ),
                  const SizedBox.square(dimension: 4),
                  IconButton(
                    onPressed: !_loading
                        ? () async {
                            _getTextFromFiles();
                          }
                        : null,
                    icon: Icon(
                      Icons.file_copy_sharp,
                      color: _loading
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: !_loading
                        ? () async {
                            _getImage();
                          }
                        : null,
                    icon: Icon(
                      Icons.image,
                      color: _loading
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (!_loading)
                    IconButton(
                      onPressed: () async {
                        _sendChatMessage(_textController.text);
                      },
                      icon: Icon(
                        Icons.send,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  else
                    const CircularProgressIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getTextFromFiles() async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowMultiple: true,
          allowedExtensions: ['pdf', 'doc', 'docx']);
      if (result != null) {
        for (var i in result.files) {
          final bytes = await File(i.path!).readAsBytes();
          if (i.extension == 'pdf') {
            files!.add(i);
            final PdfDocument document = PdfDocument(inputBytes: bytes);
            //Extract the text from all the pages.
            String text = PdfTextExtractor(document).extractText();
            textFromFiles!.add(TextPart(text));
            //Dispose the document.
            document.dispose();
          } else if (i.extension == 'docx' || i.extension == 'doc') {
            files!.add(i);
            final text = docxToText(bytes);
            textFromFiles!.add(TextPart(text));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  backgroundColor: Colors.blueGrey,
                  content: Text('Only PDF and Word files are allowed.')),
            );
          }
        }
        setState(() {});
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _getImage() async {
    ImagePicker imagePicker = ImagePicker();
    final img = await imagePicker.pickMultiImage();
    for (var i in img) {
      final byte = File(i.path).readAsBytesSync();
      if (!checkByte(byte)) {
        final img = DataPart(
            lookupMimeType(i.path).toString() != 'null'
                ? lookupMimeType(i.path).toString()
                : 'image/jpg',
            byte);
        imageData!.add(img);
        imageInput!.add(Image(image: FileImage(File(i.path))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: Colors.blueGrey,
              content: Text('Please choose different image')),
        );
      }
    }
    setState(() {});
  }

  bool checkByte(Uint8List bytes) {
    for (var i in imageData!) {
      if (listEquals(i.bytes, bytes)) return true;
    }
    return false;
  }

  Future<void> _sendChatMessage(String message) async {
    if ((message?.isEmpty ?? true) &&
        (imageInput?.isEmpty ?? true) &&
        (textFromFiles?.isEmpty ?? true)) {
      _textFieldFocus.unfocus();
    } else {
      setState(() {
        _loading = true;
        _textFieldFocus.unfocus();
      });

      try {
        setState(() {
          _generatedContent.add((
            image: imageInput,
            textFromFiles: [],
            text: [message],
            file: files,
            fromUser: true
          ));
          _scrollDown();
        });

        final response = _chat.sendMessageStream(Content.multi(
            [TextPart(message), ...imageData!, ...textFromFiles!]));
        //reset data
        imageInput = [];
        imageData = [];
        textFromFiles = [];
        files = [];
        setState(() {});
        //reset data
        List<String> text = [];
        await for (var chunk in response) {
          if (_generatedContent.last.fromUser == true) {
            text.add(chunk.text!);
          }
        }

        setState(() {
          _generatedContent.add((
            image: null,
            file: null,
            textFromFiles: null,
            text: text,
            fromUser: false
          ));
        });
      } catch (e) {
        _showError(e.toString());
        setState(() {
          _loading = false;
        });
      } finally {
        _textController.clear();
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Something went wrong'),
          content: SingleChildScrollView(
            child: SelectableText(message),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            )
          ],
        );
      },
    );
  }
}

class MessageWidget extends StatefulWidget {
  const MessageWidget({
    super.key,
    this.image,
    this.text,
    this.scrollController,
    this.textFromFiles,
    this.file,
    required this.isFromUser,
  });

  final List<Image>? image;
  final List<String>? textFromFiles;
  final List<String>? text;
  final List<PlatformFile>? file;
  final bool isFromUser;
  final ScrollController? scrollController;

  @override
  State<MessageWidget> createState() => _MessageState();
}

class _MessageState extends State<MessageWidget>
    with AutomaticKeepAliveClientMixin {
  bool isAnimated = true;
  List<AnimatedText> animationText = [];
  String message = '';

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.scrollController!.animateTo(
        widget.scrollController!.position.maxScrollExtent,
        duration: const Duration(
          milliseconds: 1500,
        ),
        curve: Curves.easeOut,
      ),
    );
  }

  void getText() {
    for (var i in widget.text!) {
      animationText
          .add(TyperAnimatedText(i, speed: const Duration(milliseconds: 3)));
    }
  }

  @override
  void initState() {
    getText();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Row(
      mainAxisAlignment:
          widget.isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          flex: 1,
          fit: FlexFit.loose,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            decoration: BoxDecoration(
              color: widget.isFromUser
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message != '')
                  MarkdownBody(
                    data: message,
                    selectable: true,
                  ),
                if (widget.text != null && widget.isFromUser == false)
                  isAnimated
                      ? AnimatedTextKit(
                          animatedTexts: animationText,
                          onNextBeforePause: (p0, p1) {
                            setState(() {
                              message += animationText[p0].text;
                            });
                          },
                          onNext: (p0, p1) {
                            _scrollDown();
                          },
                          pause: const Duration(microseconds: 800),
                          onFinished: () {
                            setState(() {
                              isAnimated = false;
                            });
                          },
                          isRepeatingAnimation: false,
                        )
                      : const MarkdownBody(data: ''),
                if ((widget.text!.first != '') && widget.isFromUser == true)
                  SelectableText(widget.text!.first),
                if (widget.image?.isNotEmpty ?? false)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    width: ((widget.image!.length) >= 3
                            ? 3
                            : widget.image!.length) *
                        (MediaQuery.of(context).size.width * 0.8 / 3),
                    height: (widget.image!.length / 3).ceil() *
                        (MediaQuery.of(context).size.width * 0.8 / 3),
                    child: GridView.builder(
                      itemCount: widget.image!.length,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent:
                              MediaQuery.of(context).size.width * 0.8 / 3,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2),
                      itemBuilder: (context, idx) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image(
                            image: widget.image![idx].image,
                            width: MediaQuery.of(context).size.width * 0.8 / 3,
                            height: MediaQuery.of(context).size.width * 0.8 / 3,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                if (widget.file?.isNotEmpty ?? false)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.05,
                    child: ListView.builder(
                      itemCount: widget.file!.length,
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, idx) {
                        return Container(
                          height: MediaQuery.of(context).size.height * 0.05,
                          margin: const EdgeInsets.only(left: 4, right: 4),
                          padding: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                              color: const Color(0xFFA2E6FF),
                              borderRadius: BorderRadius.circular(5)),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: (widget.file![idx].extension == 'pdf')
                                      ? const Image(
                                          image: AssetImage(
                                              'assets/images/pdf.png'))
                                      : const Image(
                                          image: AssetImage(
                                              'assets/images/doc.png'))),
                              Text(' ${widget.file![idx].name}'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
