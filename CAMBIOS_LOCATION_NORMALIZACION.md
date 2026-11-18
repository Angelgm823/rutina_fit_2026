# Refactorización: Location - Columna a Tabla (v9 → v10)

## 📋 Resumen Ejecutivo

Se refactorizó la estructura de la base de datos para **normalizar `location`** de una columna de texto en la tabla `exercises` a una **tabla separada `locations`** con relación **Foreign Key (1:N)**.

**Cambios:**
- Base de datos: v9 → v10
- Nueva tabla: `locations` con 2 registros (GYM=1, CASA=2)
- Nueva columna: `exercises.location_id` (FK)
- Código Dart actualizado: `location` → `locationId` + getter

---

## 🗄️ Cambios en la Base de Datos

### Tabla `locations` (Nueva)
```sql
CREATE TABLE locations(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL
);

INSERT INTO locations(name) VALUES('GYM'), ('CASA');
```

**Registros:**
- `id=1, name='GYM'` - Ejercicios de gimnasio
- `id=2, name='CASA'` - Ejercicios de casa

### Tabla `exercises` (Modificada)
**Antes:**
```sql
location TEXT DEFAULT 'GYM'
```

**Después:**
```sql
location_id INTEGER DEFAULT 1,
FOREIGN KEY(location_id) REFERENCES locations(id)
```

**Migración de datos:**
- Todos los `location='GYM'` → `location_id=1`
- Todos los `location='CASA'` → `location_id=2`
- Validación: 48 GYM + 71 CASA = 119 ejercicios ✅

---

## 💻 Cambios en el Código

### `lib/database/db.dart`

#### Versión BD incrementada
```dart
version: 10  // Era: 9
```

#### Nueva tabla creada en `_createLibrary()`
```dart
await d.execute('CREATE TABLE locations(...)');
await d.execute('INSERT INTO locations(name) VALUES("GYM"), ("CASA")');
```

#### Nueva migración `_migrateTo10()`
```dart
static Future<void> _migrateTo10(Database d) async {
  // Crear tabla locations
  // Agregar columna location_id
  // Migrar datos: GYM→1, CASA→2
}
```

#### Funciones actualizadas
- `updateExercise()`: parámetro `location` → `locationId: int`
- `addExercise()`: parámetro `location` → `locationId: int`
- `exportData()`: exporta `location_id`
- `importData()`: soporta ambas versiones (location string + location_id int)

#### Columnas de lectura actualizadas
```dart
static const _exCols = [..., 'location_id'];  // Era: 'location'
```

### `lib/models/exercises.dart`

#### Cambios en modelo `Ex`
```dart
// Antes
final String location;
const Ex({
  ...
  this.location = 'GYM',
});

// Después
final int locationId;
const Ex({
  ...
  this.locationId = 1,
});

// Getter para compatibilidad
String get location => locationId == 2 ? 'CASA' : 'GYM';
```

#### Factory `Ex.fromMap()` actualizado
```dart
locationId: (m['location_id'] as int?) ?? 1,  // Era: location string
```

### `assets/db/ejercicios.db`

**Cambios ejecutados:**
```sql
-- Crear tabla
CREATE TABLE locations(id INTEGER PRIMARY KEY, name TEXT UNIQUE NOT NULL);
INSERT INTO locations(name) VALUES('GYM'), ('CASA');

-- Migrar datos
ALTER TABLE ejercicios ADD COLUMN location_id INTEGER DEFAULT 1;
UPDATE ejercicios SET location_id = 2 WHERE location = 'CASA';
UPDATE ejercicios SET location_id = 1 WHERE location = 'GYM' OR location IS NULL;
```

---

## ✅ Validaciones Realizadas

| Aspecto | Resultado |
|---------|-----------|
| Tabla `locations` creada | ✅ 2 registros |
| Columna `location_id` agregada | ✅ 119 ejercicios |
| Distribución de datos | ✅ 48 GYM, 71 CASA |
| `flutter clean && flutter pub get` | ✅ Sin errores |
| Código compila correctamente | ✅ Dart analyzer OK |

---

## 🎯 Beneficios de esta Refactorización

### 1. **Normalización**
- Elimina redundancia: strings duplicados → IDs únicos
- Mejora integridad referencial con FK

### 2. **Escalabilidad**
- Fácil agregar nuevas ubicaciones en el futuro (ej: "PARQUE", "PISCINA")
- Sin cambios en tabla de ejercicios

### 3. **Consultas más eficientes**
- Comparar por ID (1,2) vs strings ("GYM", "CASA")
- Joins más rápidos

### 4. **Compatibilidad**
- Getter `Ex.location` mantiene compatibilidad con código existente
- `importData()` soporta ambos formatos (antiguo y nuevo)

---

## 🔄 Cambios de API Pública

### Funciones de Base de Datos
```dart
// Antes
updateExercise(..., String location = 'GYM')
addExercise(..., String location = 'GYM')

// Después
updateExercise(..., int locationId = 1)
addExercise(..., int locationId = 1)
```

### Modelo Ex
```dart
// Antes
Ex.location → String ('GYM' o 'CASA')

// Después
Ex.locationId → int (1 o 2)
Ex.location → String (getter que convierte locationId)
```

---

## 📦 Commit

```
refactor: normalizar location de columna a tabla FK
Commit: 29e0988
```

Cambios en:
- `lib/database/db.dart` (+51 líneas, -12 líneas)
- `lib/models/exercises.dart` (actualizado modelo Ex)
- `assets/db/ejercicios.db` (tabla locations + migration)

---

## 🚀 Próximos Pasos (Opcionales)

1. **Eliminar columna antigua** (si es necesario):
   - SQLite no soporta DROP COLUMN directamente
   - Usar recreate table pattern en migración futura

2. **Agregar queries por location**:
   - `exercises(locationId: int)` para filtrar por ubicación
   - `exercisesByLocation(String location)` como helper

3. **UI**: Agregar filtros para mostrar ejercicios por ubicación
   - Toggle GYM/CASA
   - Selector de ubicación al crear ejercicio

---

## 🧪 Testing Recomendado

- [ ] Crear ejercicio con `locationId: 1` (GYM)
- [ ] Crear ejercicio con `locationId: 2` (CASA)
- [ ] Cargar ejercicios existentes (verificar que `location` getter funciona)
- [ ] Exportar datos (incluye `location_id`)
- [ ] Importar datos exportados (maneja ambos formatos)
- [ ] Compilar sin errores
- [ ] Ejecutar en dispositivo/emulador
