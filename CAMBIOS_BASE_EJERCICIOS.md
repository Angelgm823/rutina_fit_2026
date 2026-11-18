# Cambios en la Base de Ejercicios - 2026-11-18

## Resumen Ejecutivo

Se ha expandido significativamente la base de datos de ejercicios de **31 → 119 ejercicios** agregando nuevos movimientos para cada grupo muscular y equipo disponible (mancuernas, ligas de resistencia, barra romana, bicicleta estática, equipamiento de gimnasio).

Se agregó una nueva columna `location` para diferenciar ejercicios de **GYM** vs **CASA**.

---

## Cambios en la Base de Datos

### Versión de BD: 8 → 9

**Archivo**: `lib/database/db.dart`

- Incrementada versión de BD de 8 a 9
- Agregada migración `_migrateTo9()` que crea columna `location TEXT DEFAULT 'GYM'`
- Actualizado `_createLibrary()` para incluir columna `location` en tabla `exercises`
- Actualizado `_exCols` para incluir 'location'
- Actualizado `_manageCols` para incluir 'location'
- Actualizado `updateExercise()` para aceptar parámetro `location`
- Actualizado `addExercise()` para aceptar parámetro `location`
- Actualizado `exportData()` para exportar columna `location`
- Actualizado `importData()` para importar columna `location`

**Archivo**: `lib/models/exercises.dart`

- Agregado campo `location` al modelo `Ex`
- Actualizado constructor de `Ex` con valor por defecto `location = 'GYM'`
- Actualizado `Ex.fromMap()` para mapear 'location' con valor por defecto 'GYM'

**Archivo**: `assets/db/ejercicios.db`

- Agregada columna `location` a tabla `ejercicios`
- Agregados 88 nuevos ejercicios (119 total)
- Asignada ubicación (GYM/CASA) basada en equipo:
  - **CASA (71)**: Peso corporal (29), Mancuernas (22), Ligas (12), Barra romana (5), Banco (2), Cuerda (1)
  - **GYM (48)**: Máquina (10), Barra (9), Polea (6), Barra fija (2), Máquina Smith (3), y otros

---

## Distribución de Ejercicios por Grupo Muscular

| Grupo | Antes | Después | Nuevos |
|-------|-------|---------|--------|
| Pecho | 7 | 15 | +8 |
| Espalda | 3 | 16 | +13 |
| Brazos | 5 | 18 | +13 |
| Hombros | 3 | 15 | +12 |
| Piernas y Glúteos | 6 | 26 | +20 |
| Abdomen | 3 | 15 | +12 |
| Cardio | 3 | 14 | +11 |
| **TOTAL** | **31** | **119** | **+88** |

---

## Nuevos Ejercicios por Equipo

### Mancuernas (22 ejercicios CASA)
- Press declinado con barra recta
- Press con mancuernas
- Aperturas con mancuernas
- Curl con mancuernas
- Press francés con mancuernas
- Y más...

### Ligas de Resistencia (12 ejercicios CASA)
- Curl de bíceps con ligas
- Press francés con ligas
- Encogimientos con ligas
- Elevaciones laterales con ligas
- Y más...

### Peso Corporal (29 ejercicios CASA)
- Lagartijas con palmadas
- Lagartijas en decline
- Flexiones de diamante
- Pull-ups en barra romana
- Dips en banco
- Burpees
- Mountain climbers
- Y más...

### Equipamiento de Gimnasio (48 ejercicios GYM)
- Máquinas específicas (pecho, espalda, brazos)
- Poleas (jalón, remo, tríceps)
- Leg press
- Caminadora / Elíptica / Escaladora
- Y más...

---

## Ubicaciones (Locations)

### GYM (Gimnasio)
Ejercicios que requieren equipamiento específico de gimnasio:
- Máquinas especializadas
- Poleas
- Barras de pesas
- Caminadora, Elíptica, Escaladora
- Leg press
- Máquina Smith

### CASA
Ejercicios que se pueden hacer en casa con equipamiento accesible:
- Peso corporal
- Mancuernas (ajustables o fijas)
- Ligas de resistencia
- Barra romana (pull-up bar)
- Banco (opcional)
- Cuerda para saltar

---

## Cambios de Código

### db.dart
```dart
// Antes: version 8
// Después: version 9

// Migración _migrateTo9
static Future<void> _migrateTo9(Database d) async {
  await _ensureColumn(d, 'exercises', 'location', 'TEXT DEFAULT "GYM"');
}
```

### exercises.dart
```dart
// Agregado a clase Ex
final String location;

// Constructor
const Ex({
  ...
  this.location = 'GYM',
});

// Factory fromMap
factory Ex.fromMap(Map<String, Object?> m) => Ex(
  ...
  location: (m['location'] as String?) ?? 'GYM',
);
```

---

## Testing Recomendado

1. ✅ Compilación sin errores
2. ✅ Apertura de app sin crashes
3. ✅ Lectura de ejercicios de BD con nueva columna
4. ✅ Filtrado por location (GYM/CASA) si se implementa en UI
5. ✅ Creación de nuevos ejercicios con location
6. ✅ Exportación/importación de datos con location
7. ✅ Verificación que ejercicios antiguos sigan funcionando

---

## Notas

- La columna `location` tiene valor por defecto 'GYM' para compatibilidad
- Todos los ejercicios existentes funcionarán sin cambios
- Se recomienda actualizar UI para mostrar filtros GYM/CASA si es necesario
- Los usuarios pueden crear ejercicios con `location = 'CASA'` al agregar personalizados
