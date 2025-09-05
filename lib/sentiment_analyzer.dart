import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SentimentAnalyzer {
  final String _modelFile = 'assets/model/sentiment_model_quant.tflite';
  final String _tokenizerFile = 'assets/model/tokenizer.json';

  final int _maxLen = 120;
  final String _oovToken = "<OOV>";

  late Interpreter _interpreter;
  late Map<String, int> _wordIndex;
  bool _loaded = false;

  final Map<int, String> _labelMap = {
    0: 'negative',
    1: 'neutral',
    2: 'positive',
  };

  // In your SentimentAnalyzer class

  Future<bool> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelFile);

      print(_interpreter.getInputTensors());
      print(_interpreter.getOutputTensors());


      // --- Final Tokenizer Logic for the Revealed Structure ---
      final tokStr = await rootBundle.loadString(_tokenizerFile);

      // 1. Decode the entire file into a map.
      final tokMap = json.decode(tokStr) as Map<String, dynamic>;

      // 2. Get the 'config' map from inside it.
      final config = tokMap['config'] as Map<String, dynamic>;

      // 3. Get the 'word_index', which the error confirms is a STRING.
      final wordIndexString = config['word_index'] as String;

      // 4. Decode that string to get the final word index map.
      final wordIndexMap = json.decode(wordIndexString) as Map<String, dynamic>;

      // 5. Convert to the correct type.
      _wordIndex = wordIndexMap.map((k, v) => MapEntry(k, (v as num).toInt()));

      _loaded = true;
      print("✅✅✅ Model and Tokenizer loaded successfully! ✅✅✅");
      return true;

    } catch (e, stackTrace) {
      print("🚨🚨🚨 FAILED to load model: $e 🚨🚨🚨");
      print("🚨 Stack Trace: $stackTrace");
      return false;
    }
  }

  Map<String, dynamic> predict(String text) {
    if (!_loaded) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    final seq = _textToSequence(text);
    final input = [seq.map((e) => e.toDouble()).toList()];  // [1,120] float32
    final output = List.generate(1, (_) => List.filled(_labelMap.length, 0.0));

    _interpreter.run(input, output);

    final probs = output[0].cast<double>();
    final idx = _argMax(probs);
    return {
      'label_id': idx,
      'label': _labelMap[idx] ?? 'Unknown',
      'probs': probs,
    };
  }


  List<int> _textToSequence(String text) {
    final lower = text.toLowerCase();
    final filtered = lower.replaceAll(
        RegExp(r'[!"#$%&()*+,\-./:;<=>?@\[\]^_`{|}~\t\n]'), ' ');
    final tokens = filtered
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((w) => _wordIndex[w] ?? _wordIndex[_oovToken] ?? 1)
        .toList();

    if (tokens.length > _maxLen) {
      return tokens.sublist(0, _maxLen);
    }
    if (tokens.length < _maxLen) {
      tokens.addAll(List.filled(_maxLen - tokens.length, 0));
    }
    return tokens;
  }

  int _argMax(List<double> probs) {
    if (probs.isEmpty) return 0;
    var bestI = 0;
    var bestV = probs[0];
    for (var i = 1; i < probs.length; i++) {
      final v = probs[i];
      if (v > bestV) {
        bestV = v;
        bestI = i;
      }
    }
    return bestI;
  }

  void close() {
    if (_loaded) _interpreter.close();
    _loaded = false;
  }
}