import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../widgets/info_card.dart';

class DisplayPage extends StatelessWidget {
  const DisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ui.FlutterView view =
        View.of(context);

    final display = view.display;

    final logicalSize =
        MediaQuery.sizeOf(context);

    final physicalSize =
        display.size;

    final devicePixelRatio =
        display.devicePixelRatio;

    final refreshRate =
        display.refreshRate;

    final frameDurationMs =
        refreshRate > 0
            ? 1000.0 / refreshRate
            : double.nan;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'CARACTERÍSTICAS DO DISPLAY',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        InfoCard(
          title: 'Resolução física',
          value:
              '${physicalSize.width.toStringAsFixed(0)} × '
              '${physicalSize.height.toStringAsFixed(0)} px',
          description:
              'Dimensão física informada pelo display.',
        ),

        InfoCard(
          title: 'Área lógica do aplicativo',
          value:
              '${logicalSize.width.toStringAsFixed(1)} × '
              '${logicalSize.height.toStringAsFixed(1)}',
          description:
              'Sistema de coordenadas lógico utilizado pelo Flutter.',
        ),

        InfoCard(
          title: 'Device Pixel Ratio',
          value:
              devicePixelRatio.toStringAsFixed(3),
          description:
              'Relação entre pixels físicos e pixels lógicos.',
        ),

        InfoCard(
          title: 'Refresh rate',
          value:
              '${refreshRate.toStringAsFixed(2)} Hz',
          description:
              'Taxa de atualização atualmente informada pelo display.',
        ),

        InfoCard(
          title: 'Frame teórico',
          value:
              '${frameDurationMs.toStringAsFixed(2)} ms',
          description:
              'Tempo teórico de um frame.',
        ),

        const SizedBox(height: 20),

        const Text(
          'Os movimentos nesta tela não são registrados '
          'como eventos experimentais de touchscreen.',
          style: TextStyle(
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}