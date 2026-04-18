import 'package:flutter/material.dart';

class OutfitlyAiScreen extends StatelessWidget {
  const OutfitlyAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outfitly AI'),
      ),
      body: const Center(
        child: Text('Your personal AI stylist is booting up...'),
      ),
    );
  }
}
