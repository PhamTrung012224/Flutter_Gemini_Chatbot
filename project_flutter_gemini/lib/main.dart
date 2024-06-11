import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

/// The API key to use when accessing the Gemini API.
///
/// To learn how to generate and specify this key,
/// check out the README file of this sample.
const String _apiKey = String.fromEnvironment('API_KEY');

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
        backgroundColor: const Color(0xFFC5E5FA),
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
  List<DataPart>? data = [];
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();
  final List<({List<Image>? image, String? text, bool fromUser})>
      _generatedContent =
      <({List<Image>? image, String? text, bool fromUser})>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
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

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(
          milliseconds: 300,
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
                            _sendImagePrompt(_textController.text);
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

  Future<void> _sendImagePrompt(String message) async {
    ImagePicker imagePicker = ImagePicker();
    final img = await imagePicker.pickMultiImage();
    for (var i in img) {
      final img = DataPart('image/jpeg', File(i.path).readAsBytesSync());
      data!.add(img);
      imageInput!.add(Image(image: FileImage(File(i.path))));
    }
    setState(() {});
  }

  Future<void> _sendChatMessage(String message) async {
    setState(() {
      _loading = true;
      _textFieldFocus.unfocus();
    });

    try {
      if (imageInput?.isEmpty ?? true) {
        _generatedContent.add((image: null, text: message, fromUser: true));
        final response = await _chat.sendMessage(
          Content.text(message),
        );
        var text = response.text;
        setState(() {
          _generatedContent.add((image: null, text: text, fromUser: false));
        });
      } else {
        _generatedContent
            .add((image: imageInput, text: message, fromUser: true));
        final response = await _chat
            .sendMessage(Content.multi([TextPart(message), ...data!]));
        var text = response.text;
        //reset image data
        imageInput = [];
        data = [];
        //reset image data
        setState(() {
          _generatedContent.add((image: null, text: text, fromUser: false));
        });
      }

      setState(() {
        _loading = false;
        _scrollDown();
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
    required this.isFromUser,
  });

  final List<Image>? image;
  final String? text;
  final ScrollController? scrollController;
  final bool isFromUser;

  @override
  State<MessageWidget> createState() => _MessageState();
}

class _MessageState extends State<MessageWidget> with AutomaticKeepAliveClientMixin {
  bool showAnimation=true;

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.scrollController!.animateTo(
        widget.scrollController!.position.maxScrollExtent,
        duration: const Duration(
          milliseconds: 500,
        ),
        curve: Curves.easeOut,
      ),
    );
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
            padding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 10,
            ),
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.text != null && widget.isFromUser == false)
                  showAnimation
                      ? AnimatedTextKit(
                          animatedTexts: [
                            TyperAnimatedText(widget.text!,
                                speed: const Duration(milliseconds: 8))
                          ],
                          isRepeatingAnimation: false,
                          onFinished: () {
                            setState(() {
                              print('build');
                              showAnimation = false;
                              _scrollDown();
                            });
                          },
                          pause: const Duration(milliseconds: 1),
                        )
                      : MarkdownBody(data: widget.text!),
                if (widget.text != null && widget.isFromUser == true)
                  Text('${widget.text}'),
                if (widget.image != null)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    height: (widget.image!.length / 3).ceil() *
                        (MediaQuery.of(context).size.width * 0.8 / 3),
                    child: GridView.builder(
                      itemCount: widget.image!.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                            image: widget.image![idx].image,
                            width: MediaQuery.of(context).size.width * 0.8 / 3,
                            height: MediaQuery.of(context).size.width * 0.8 / 3,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  )
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
