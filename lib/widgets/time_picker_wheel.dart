import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Selector de tiempo con rueda (minutos y segundos) estilo iOS.
class TimePickerWheel extends StatefulWidget {
  final int initialSeconds;
  final int maxSeconds;
  final ValueChanged<int> onTimeChanged;
  final VoidCallback? onConfirm;

  const TimePickerWheel({
    super.key,
    required this.initialSeconds,
    required this.maxSeconds,
    required this.onTimeChanged,
    this.onConfirm,
  });

  @override
  State<TimePickerWheel> createState() => _TimePickerWheelState();
}

class _TimePickerWheelState extends State<TimePickerWheel> {
  late int _selectedMinutes;
  late int _selectedSeconds;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialSeconds ~/ 60;
    _selectedSeconds = widget.initialSeconds % 60;
  }

  int get _totalSeconds => _selectedMinutes * 60 + _selectedSeconds;

  void _updateTime() {
    widget.onTimeChanged(_totalSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final maxMinutes = widget.maxSeconds ~/ 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Título
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Selecciona el tiempo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        // Ruedas
        Container(
          height: 160,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Row(
            children: [
              // Minutos
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: _selectedMinutes,
                  ),
                  itemExtent: 40,
                  onSelectedItemChanged: (index) {
                    _selectedMinutes = index;
                    _updateTime();
                  },
                  children: List<Widget>.generate(
                    maxMinutes + 1,
                    (i) => Center(
                      child: Text('$i', style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              ),
              // Separador
              SizedBox(
                width: 50,
                child: Center(
                  child: Text(':', style: Theme.of(context).textTheme.headlineSmall),
                ),
              ),
              // Segundos
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: _selectedSeconds,
                  ),
                  itemExtent: 40,
                  onSelectedItemChanged: (index) {
                    _selectedSeconds = index;
                    _updateTime();
                  },
                  children: List<Widget>.generate(
                    60,
                    (i) => Center(
                      child: Text(i.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Botón de confirmación
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    widget.onConfirm?.call();
                    Navigator.pop(context);
                  },
                  child: const Text('Listo'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Muestra un diálogo con rueda de selección de tiempo
Future<int?> showTimePickerWheel({
  required BuildContext context,
  required int initialSeconds,
  required int maxSeconds,
}) async {
  int? result;

  await showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 100),
      child: TimePickerWheel(
        initialSeconds: initialSeconds,
        maxSeconds: maxSeconds,
        onTimeChanged: (seconds) => result = seconds,
        onConfirm: () {},
      ),
    ),
  );

  return result;
}
