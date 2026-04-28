import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  final Map<String, dynamic>? employeeData;
  HomePage(this.employeeData);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool isRecording = false;
  bool hasRecording = false;
  String? filePath;
  bool isUploading = false;
  String transcription = '';

  @override
  void initState() {
    super.initState();
    initRecorderAndPlayer();
  }

  Future<void> initRecorderAndPlayer() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    await _recorder!.openRecorder();
    await _player!.openPlayer();
  }

  @override
  void dispose() {
    _recorder!.closeRecorder();
    _player!.closePlayer();
    super.dispose();
  }

  Future<bool> requestMicPermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  Future<void> toggleRecording() async {
    bool hasPermission = await requestMicPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')));
      return;
    }

    Directory tempDir = await getTemporaryDirectory();
    String path =
        '${tempDir.path}/record_${DateTime.now().millisecondsSinceEpoch}.aac';

    if (!isRecording) {
      await _recorder!.startRecorder(
        toFile: path,
        codec: Codec.aacMP4, // AAC/MP4 supaya main balik boleh jalan
      );

      setState(() {
        isRecording = true;
        hasRecording = false;
        filePath = path;
        transcription = '';
      });
    } else {
      await _recorder!.stopRecorder();
      setState(() {
        isRecording = false;
        hasRecording = true;
      });

      print('Recording saved at: $filePath');
      await convertWithWhisper();
    }
  }

  Future<void> convertWithWhisper() async {
    if (filePath == null) return;

    File audioFile = File(filePath!);
    final url = Uri.parse("https://api.openai.com/v1/audio/transcriptions");

    var request = http.MultipartRequest("POST", url)
      ..headers["Authorization"] = "Bearer MY_API_KEY"
      ..fields["model"] = "whisper-1"
      ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

    var response = await request.send();
    var body = await http.Response.fromStream(response);

    if (response.statusCode == 200) {
      var data = jsonDecode(body.body);
      setState(() => transcription = data["text"]);
      print("Whisper text: $transcription");
    } else {
      print("Whisper error: ${body.body}");
    }
  }

  Future<void> playLastRecording() async {
    if (filePath == null || !File(filePath!).existsSync()) return;

    if (_player!.isPlaying) {
      await _player!.stopPlayer();
    }

    await _player!.startPlayer(
      fromURI: filePath!,
      codec: Codec.aacMP4,
    );
  }

  Future<void> uploadRecording() async {
    if (filePath == null || !File(filePath!).existsSync()) return;

    setState(() => isUploading = true);

    File file = File(filePath!);
    List<int> audioBytes = await file.readAsBytes();
    String base64Audio = base64Encode(audioBytes);

    await FirebaseFirestore.instance.collection('reports').add({
      'employeeEmail': widget.employeeData?['email'],
      'employeeName': widget.employeeData?['name'],
      'audioBase64': base64Audio,
      'transcription': 'Earlier today, while monitoring the company servers, I noticed unusual activity on the main database around 3:15 PM. There were multiple failed login attempts from an external IP address.It looks like sensitive employee and client information might have been accessed.',
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report sent successfully!')),
    );

    setState(() {
      filePath = null;
      hasRecording = false;
      isUploading = false;
      transcription = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 0, 18, 33)
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(foregroundColor: Colors.white, title: Text('Welcome, ${widget.employeeData?['name']}', style: const TextStyle(fontSize: 15, fontFamily: 'WorkSans',color: Colors.white),), backgroundColor: Colors.transparent,),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 70),
                const Text('Send your report',
                  style: TextStyle(fontSize: 32, fontFamily: 'WorkSans', fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Color.fromARGB(255, 7, 116, 150), offset: Offset(0, 0), blurRadius: 20)])
                ),
                const Text('Report any cybercrime activity to investigation team.', style: TextStyle(fontSize: 11, fontFamily: 'WorkSans', color: Colors.white, shadows: [Shadow(color: Color.fromARGB(255, 7, 116, 150), offset: Offset(0, 0), blurRadius: 20)]),),
                const SizedBox(height: 60),
      
                // BUTTON RECORD
                GestureDetector(
                  onTap: toggleRecording,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      boxShadow: isRecording ? [BoxShadow(color: Colors.redAccent.withOpacity(0.6),spreadRadius: 8, blurRadius: 20,),] : [BoxShadow(color: const Color.fromARGB(255, 82, 246, 255).withOpacity(0.6),spreadRadius: 8, blurRadius: 20,),],
                      gradient: isRecording ? RadialGradient(colors: [Color.fromARGB(255, 191, 118, 118), Color.fromARGB(255, 1, 32, 48),], center: Alignment.center, radius: 0.5): RadialGradient(colors: [Color.fromARGB(255, 118, 178, 191), Color.fromARGB(255, 1, 32, 48),], center: Alignment.center, radius: 0.5),
                      shape: BoxShape.circle,
                      border: isRecording ? Border.all(color: const Color.fromARGB(255, 209, 150, 150), width: 2) :Border.all(color: const Color.fromARGB(255, 255, 255, 255), width: 2)
                    ),
                    child: Icon(
                      isRecording ? Icons.stop : Icons.mic,
                      size: 70,
                      color: isRecording ?  const Color.fromARGB(255, 255, 255, 255) :  const Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                ),
      
                const SizedBox(height: 30),
      
                // RECORDING STATUS
                const SizedBox(height: 10),
                Text(
                  isRecording
                      ? 'Recording...'
                      : hasRecording
                          ? 'Recording ready.\n$transcription'
                          : 'Tap to record',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontFamily: 'SansSerif', color: Colors.white,),
                ),
      
                const SizedBox(height: 20),
      
                // SEND REPORT BUTTON
                SizedBox(
                  width: 160,
                  height: 45,
                  child: ElevatedButton(
                    onPressed:
                        hasRecording && !isUploading ? uploadRecording : null,
                        style: ElevatedButton.styleFrom(
                          side: BorderSide(color: hasRecording && !isUploading ? const Color.fromARGB(255, 255, 255, 255) : Colors.transparent, width: 2),
                          
                          backgroundColor: const Color.fromARGB(255, 7, 52, 72),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                    child: isUploading
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : const Text('Send Report'),
                  ),
                ),
              ],
            ),
          ),
        ),
      
        floatingActionButton: FloatingActionButton(
          onPressed: hasRecording ? playLastRecording : null,
          backgroundColor: hasRecording ? const Color.fromARGB(255, 47, 94, 102) : const Color.fromARGB(255, 137, 137, 137),
          shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2)),
          child: const Icon(Icons.play_arrow, color: Colors.white,),
          tooltip: 'Play last recording',
        ),
      ),
    );
  }
}