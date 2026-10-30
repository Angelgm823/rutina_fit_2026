import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

/// Temporizador de cuenta regresiva reutilizable: el tiempo se escribe en minutos y segundos
/// (nada de opciones fijas) y baja de ahí a 0. El estado vive en el controller de cada
/// pantalla; este widget solo dibuja y reenvía los eventos.
class CountdownTimer extends StatefulWidget {
  final int total; // segundos elegidos
  final int remaining; // segundos que faltan (válido mientras running o pausado)
  final bool running;
  final int maxSeconds; // tope permitido

  /// Null = los campos de minutos/segundos no se muestran (p. ej. mientras corre).
  final ValueChanged<int>? onTotalChanged;

  /// Null = no se muestran los controles de inicio/pausa.
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onReset;

  const CountdownTimer({
    super.key,
    required this.total,
    required this.remaining,
    required this.running,
    this.onTotalChanged,
    this.onStart,
    this.onPause,
    this.onReset,
    this.maxSeconds = 1800,
  });

  static String fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late final _ctl = TextEditingController(text: CountdownTimer.fmt(widget.total));

  @override
  void didUpdateWidget(CountdownTimer old) {
    super.didUpdateWidget(old);
    if (widget.total == old.total || widget.running) return;
    final text = CountdownTimer.fmt(widget.total);
    if (_ctl.text != text) _ctl.text = text;
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  /// Lee "mm:ss" (o solo segundos si no hay ":").
  void _emit(String v) {
    final parts = v.split(':');
    final m = parts.length > 1 ? int.tryParse(parts[0]) ?? 0 : 0;
    final s = int.tryParse(parts.last) ?? 0;
    widget.onTotalChanged?.call((m * 60 + s).clamp(0, widget.maxSeconds));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showInputs = widget.onTotalChanged != null && !widget.running;
    // Ya se usó algo de este tiempo (pausado a medias o llegó a 0 solo), aunque ya no esté corriendo.
    final started = !widget.running && widget.total > 0 && widget.remaining < widget.total;
    final resuming = started && widget.remaining > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          CountdownTimer.fmt(widget.running || started ? widget.remaining : widget.total),
          style: theme.textTheme.displayMedium,
        ),
        if (showInputs) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _ctl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.text,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'))],
              decoration: const InputDecoration(labelText: 'mm:ss', isDense: true, border: OutlineInputBorder()),
              onChanged: _emit,
            ),
          ),
        ],
        if (widget.onStart != null || widget.onPause != null || widget.onReset != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: widget.running ? widget.onPause : (widget.total > 0 ? widget.onStart : null),
                icon: Icon(widget.running ? Icons.pause : Icons.play_arrow),
                label: Text(widget.running ? 'Pausar' : (resuming ? 'Continuar' : 'Iniciar')),
              ),
              if (widget.onReset != null && widget.total > 0) ...[
                const SizedBox(width: 8),
                OutlinedButton(onPressed: widget.onReset, child: const Text('Reiniciar')),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
