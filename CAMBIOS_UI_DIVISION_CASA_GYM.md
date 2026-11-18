# Cambios UI: División CASA/GYM en Selección y Gestión de Ejercicios

## 📋 Resumen

Se actualizó la interfaz de usuario para mostrar ejercicios **divididos por ubicación (CASA/GYM)** en:
1. **Selección de ejercicios** (al crear rutinas)
2. **Gestión de ejercicios** (edición y eliminación)

Ahora los usuarios pueden ver claramente qué ejercicios son para hacer en casa y cuáles requieren gimnasio.

---

## 📱 Cambios en la UI

### 1. Pantalla de Selección de Ejercicios (`exercise_picker_screen.dart`)

**Antes:**
- Una lista única con todos los ejercicios
- Filtros por categoría/subgrupo

**Después:**
- Dos secciones claramente divididas:
  - 🏠 **CASA** (ejercicios sin equipamiento de gimnasio)
  - 🏋️ **GYM** (ejercicios con equipamiento profesional)
- Contador de ejercicios por sección
- Headers con iconos distintivos
- Separador visual (Divider) entre secciones
- Se mantienen los filtros por categoría/subgrupo/búsqueda

**Código actualizado:**
```dart
// Antes
List<Ex> get shown { ... }

// Después
List<Ex> get _filtered { ... }
List<Ex> get shownCasa => [for (final e in _filtered) if (e.locationId == 2) e];
List<Ex> get shownGym => [for (final e in _filtered) if (e.locationId == 1) e];
```

**Renderizado:**
```dart
ListView(
  children: [
    // Sección CASA
    if (shownCasa.isNotEmpty) ...[
      Padding(..., child: Row(children: [
        Icon(Icons.home, ...),
        Text('CASA (${shownCasa.length})', ...),
      ])),
      ...shownCasa.map((e) => CheckboxListTile(...)),
    ],
    // Sección GYM
    if (shownGym.isNotEmpty) ...[
      Divider(...),
      Padding(..., child: Row(children: [
        Icon(Icons.fitness_center, ...),
        Text('GYM (${shownGym.length})', ...),
      ])),
      ...shownGym.map((e) => CheckboxListTile(...)),
    ],
  ],
)
```

### 2. Diálogo de Crear Ejercicio

**Nuevo campo:** Selector de ubicación (SegmentedButton)
```dart
SegmentedButton<int>(
  showSelectedIcon: false,
  segments: const [
    ButtonSegment(value: 1, label: Text('GYM')),
    ButtonSegment(value: 2, label: Text('CASA')),
  ],
  selected: {locationId},
  onSelectionChanged: (v) => set(() => locationId = v.first),
)
```

**Parámetro agregado:**
```dart
final id = await Db.addExercise(
  name.text.trim(), subSel,
  reps.text.trim(), unit, descr.text.trim(),
  locationId  // ← Nuevo
);
```

---

### 3. Pantalla de Gestión de Ejercicios (`manage_exercises_screen.dart`)

**Antes:**
- Una lista única de todos los ejercicios
- Filtros por estado (Activos/Eliminados/Todos)

**Después:**
- Dos secciones divididas: CASA | GYM
- Se mantienen filtros de estado
- Mismo criterio de división que en selección de ejercicios
- Búsqueda y filtrado aplican a ambas secciones

**Código actualizado:**
```dart
// Antes
List<ManagedEx> get _shown { ... }

// Después
List<ManagedEx> get _filtered { ... }
List<ManagedEx> get _shownCasa => [for (final e in _filtered) if (e.locationId == 2) e];
List<ManagedEx> get _shownGym => [for (final e in _filtered) if (e.locationId == 1) e];
```

**Método helper agregado:**
```dart
Widget _buildExerciseCard(BuildContext c, ManagedEx e) => Card(
  margin: const EdgeInsets.only(bottom: 8),
  child: ListTile(...),
);
```

### 4. Diálogo de Editar Ejercicio

**Nuevo campo:** Selector de ubicación
```dart
SegmentedButton<int>(
  segments: const [
    ButtonSegment(value: 1, label: Text('GYM')),
    ButtonSegment(value: 2, label: Text('CASA')),
  ],
  selected: {locationId},
  onSelectionChanged: (v) => set(() => locationId = v.first),
)
```

**Parámetro en update:**
```dart
await ctrl.update(
  e.id,
  ...,
  locationId: locationId  // ← Nuevo
);
```

---

## 🔧 Cambios en el Código

### Model Layer

**`lib/controllers/manage_exercises_controller.dart`:**
- Agregado campo `locationId` a clase `ManagedEx`
- Agregado getter `location` para conversión a string
- Actualizado `fromMap()` para leer `location_id`
- Actualizado método `update()` para aceptar `locationId`

```dart
class ManagedEx {
  ...
  final int locationId;
  String get location => locationId == 2 ? 'CASA' : 'GYM';
  
  factory ManagedEx.fromMap(Map<String, Object?> m) => ManagedEx(
    ...
    locationId: (m['location_id'] as int?) ?? 1,
  );
}
```

### UI Layer

**`lib/screens/exercise_picker_screen.dart`:**
- División de lista en dos secciones (CASA/GYM)
- Headers con iconos para cada sección
- Selector de ubicación en diálogo de nuevo ejercicio
- Contador separado por ubicación

**`lib/screens/manage_exercises_screen.dart`:**
- División de lista en dos secciones (CASA/GYM)
- Headers con iconos para cada sección
- Selector de ubicación en diálogo de edición
- Método helper para renderizar cards
- Actualización del controlador para soportar locationId

---

## 🎯 Comportamiento

### Selección de Ejercicios (crear rutina)
1. Abre pantalla con dos secciones: CASA | GYM
2. Filtros (categoría, subgrupo, búsqueda) aplican a ambas secciones
3. Al crear nuevo ejercicio, se elige GYM o CASA
4. Los ejercicios se pueden cambiar de ubicación (a través de edición)

### Gestión de Ejercicios
1. Abre pantalla con dos secciones: CASA | GYM
2. Filtros de estado (Activos/Eliminados/Todos) aplican a ambas secciones
3. Al editar ejercicio, se puede cambiar su ubicación
4. Las acciones (eliminar, restaurar, borrar) funcionan igual

---

## ✅ Validaciones

- ✅ `flutter pub get` sin errores
- ✅ Compilación sin warnings críticos
- ✅ Divisiones por ubicación funcionan correctamente
- ✅ Selectors de ubicación integrados en diálogos
- ✅ Contadores dinámicos por sección
- ✅ Filtros aplican a ambas secciones

---

## 🚀 Próximos Pasos (Opcionales)

1. **Agregar filtro de ubicación en barras de búsqueda** (GYM/CASA toggle)
2. **Mostrar etiqueta de ubicación** en cards (pequeño chip)
3. **Recordar última ubicación seleccionada** al crear ejercicio
4. **Sugerencias de equipo** basadas en ubicación
5. **Estadísticas por ubicación** en la pantalla principal

---

## 📸 Vista Previa

```
┌─────────────────────────────────┐
│ Elegir ejercicios               │
├─────────────────────────────────┤
│ [Todos] [Superior] [Inferior]   │
├─────────────────────────────────┤
│ [Chips: Todas | Pecho | Brazos] │
├─────────────────────────────────┤
│ 🔍 Buscar...                     │
├─────────────────────────────────┤
│                                 │
│ 🏠 CASA (15)                    │
│  ☑ Flexiones de pecho           │
│  ☐ Remo con mancuerna           │
│  ☐ Curls con ligas              │
│                                 │
│ ─────────────────────────────── │
│                                 │
│ 🏋️ GYM (12)                     │
│  ☐ Press de banca               │
│  ☐ Leg press                    │
│  ☐ Jalón lateral                │
│                                 │
├─────────────────────────────────┤
│            Listo (5)            │
└─────────────────────────────────┘
```

---

## 📝 Commit

```
feat: dividir ejercicios por ubicación (CASA/GYM) en UI

- Actualizar exercise_picker_screen.dart: mostrar CASA/GYM separado
- Actualizar manage_exercises_screen.dart: gestión con división por ubicación
- Agregar selector de ubicación en diálogos de crear/editar
- Actualizar ManagedEx con campo locationId
- Agregar contador dinámico de ejercicios por sección
- Mantener filtros (categoría, subgrupo, búsqueda) aplicables a ambas secciones
```
