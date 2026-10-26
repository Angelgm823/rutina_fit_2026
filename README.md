# Rutina Fit

Aplicación Flutter para planear rutinas de ejercicio, registrar entrenamientos y llevar el progreso a lo largo del tiempo — todo de forma local, sin cuentas ni conexión a internet.

## Características

- **Rutinas personalizadas**: crea y edita rutinas eligiendo ejercicios de una base de datos local con más de 300 ejercicios.
- **Registro de entrenamientos**: lleva el control de series, repeticiones y peso durante la sesión, con temporizador de descanso.
- **Modo cardio / bicicleta**: registro de sesiones de bicicleta estática con temporizador dedicado.
- **Progreso**: gráficas de fuerza y cardio filtrables por año y trimestre (usa `syncfusion_flutter_charts`).
- **Historial**: consulta de sesiones pasadas.
- **Notificaciones**: avisos de temporizador que siguen funcionando aunque la app esté en segundo plano o la pantalla apagada.
- **Exportar / importar**: respaldo de los datos y exportación de rutinas/progreso a PDF.
- **Temas**: selector de tema claro/oscuro.
- **Multiplataforma**: Android, iOS, web, Windows, macOS y Linux a partir de un único código base.

## Tecnologías

- [Flutter](https://flutter.dev) / Dart
- `sqflite` — base de datos local (SQLite)
- `syncfusion_flutter_charts` — gráficas de progreso
- `flutter_local_notifications` + `timezone` — notificaciones programadas
- `pdf` — generación de reportes en PDF
- `file_picker` — respaldo e importación de datos

## Estructura del proyecto

```
lib/
├── controllers/   # Lógica de estado de cada pantalla (ChangeNotifier)
├── database/      # Acceso a la base de datos SQLite
├── models/        # Modelos de datos (ejercicios, etc.)
├── screens/        # Pantallas de la app
├── services/      # Notificaciones y otros servicios
├── theme/         # Temas claro/oscuro
├── utils/         # Utilidades (formato, etc.)
└── widgets/       # Componentes reutilizables
assets/
├── db/            # Base de datos local de ejercicios
├── fonts/         # Tipografías usadas en los PDF
└── icon/          # Ícono de la app
```

## Primeros pasos

### Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart ^3.13.4)
- Un emulador/dispositivo, o navegador para la versión web

### Instalación

```bash
git clone https://github.com/<tu-usuario>/rutina_fit_2026.git
cd rutina_fit_2026
flutter pub get
```

### Ejecutar

```bash
flutter run
```

### Pruebas

```bash
flutter test
```

## Licencia

Este proyecto no tiene licencia definida todavía. Si planeas hacer el repositorio público, considera agregar una (por ejemplo, MIT) para aclarar cómo otros pueden usar el código.
