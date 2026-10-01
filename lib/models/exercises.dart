class Ex {
  final int id;
  final String name, category, sub, reps, tip, unit;
  final bool custom;
  const Ex({
    required this.id,
    required this.name,
    required this.category,
    required this.sub,
    required this.reps,
    required this.tip,
    required this.unit,
    required this.custom,
  });

  factory Ex.fromMap(Map<String, Object?> m) => Ex(
        id: m['id'] as int,
        name: m['name'] as String,
        category: m['category'] as String,
        sub: m['sub'] as String,
        reps: m['reps'] as String,
        tip: (m['tip'] as String?) ?? '',
        unit: (m['unit'] as String?) ?? 'reps',
        custom: m['custom'] == 1,
      );
}

const baseSets = 2;

/// Subcategoría -> categoría
const subcategories = <String, String>{
  'Pecho': 'Superior',
  'Espalda': 'Superior',
  'Brazo': 'Superior',
  'Hombro': 'Superior',
  'Abdominales': 'Superior',
  'Pierna': 'Inferior',
  'Glúteo': 'Inferior',
  'Gemelos': 'Inferior',
};

const categories = ['Superior', 'Inferior'];

/// Catálogo inicial: (nombre, subcategoría, repeticiones sugeridas, consejo).
/// Si las repeticiones terminan en " s" el ejercicio se mide en segundos.
const catalog = <(String, String, String, String)>[
  ('Press de pecho con mancuernas', 'Pecho', '8–12', 'Puede ser en el suelo'),
  ('Press de pecho', 'Pecho', '8–12', 'Mancuernas o barra, con seguridad'),
  ('Press inclinado con mancuernas', 'Pecho', '8–12', 'Banco inclinado o apoyo firme'),
  ('Aperturas con mancuernas', 'Pecho', '10–15', 'Codos ligeramente flexionados'),
  ('Flexiones', 'Pecho', '8–15', 'Cuerpo en línea; apoya rodillas si hace falta'),
  ('Press de pecho con liga', 'Pecho', '12–15', 'Ancla la liga a tu espalda'),
  ('Remo con barra', 'Espalda', '8–12', 'Barra hacia el abdomen'),
  ('Remo con mancuerna (por lado)', 'Espalda', '10–12', 'Controla el descenso'),
  ('Remo con liga', 'Espalda', '12–15', 'Junta los omóplatos'),
  ('Jalón con liga', 'Espalda', '12–15', 'Liga anclada arriba'),
  ('Pullover con mancuerna', 'Espalda', '10–12', 'Brazos casi estirados'),
  ('Superman', 'Espalda', '10–15', 'Sin forzar el cuello'),
  ('Curl de bíceps', 'Brazo', '10–15', 'Movimiento controlado'),
  ('Curl con barra romana', 'Brazo', '8–12', 'Codos pegados al cuerpo'),
  ('Curl martillo', 'Brazo', '10–15', 'Muñecas neutras'),
  ('Curl concentrado', 'Brazo', '10–12', 'Codo apoyado en el muslo'),
  ('Extensión de tríceps con liga', 'Brazo', '10–15', 'Sin balancear el cuerpo'),
  ('Extensión de tríceps con mancuerna', 'Brazo', '10–12', 'Mancuerna detrás de la cabeza'),
  ('Press francés con barra romana', 'Brazo', '8–12', 'Codos hacia el techo'),
  ('Fondos en silla', 'Brazo', '8–12', 'Espalda cerca de la silla'),
  ('Press de hombros', 'Hombro', '8–12', 'De pie o sentado'),
  ('Press militar con barra', 'Hombro', '8–10', 'Abdomen firme'),
  ('Elevaciones laterales', 'Hombro', '12–15', 'Poco peso, sin balanceo'),
  ('Elevaciones frontales', 'Hombro', '10–12', 'Sube hasta la altura de los hombros'),
  ('Pájaros con mancuernas', 'Hombro', '12–15', 'Torso inclinado'),
  ('Face pull con liga', 'Hombro', '12–15', 'Espalda alta y hombros'),
  ('Encogimientos de hombros', 'Hombro', '12–15', 'Sube y baja sin rotar'),
  ('Plancha', 'Abdominales', '15–30 s', 'Abdomen y glúteos activos'),
  ('Plancha lateral (por lado)', 'Abdominales', '15–30 s', 'Cuerpo en línea'),
  ('Dead bug (por lado)', 'Abdominales', '8–10', 'Lento y controlado'),
  ('Crunch', 'Abdominales', '12–20', 'Sin jalar el cuello'),
  ('Elevación de piernas', 'Abdominales', '10–15', 'Espalda baja pegada al suelo'),
  ('Bicicleta abdominal', 'Abdominales', '12–20', 'Codo hacia la rodilla contraria'),
  ('Russian twist', 'Abdominales', '12–20', 'Gira desde el torso'),
  ('Sentadilla con barra', 'Pierna', '8–12', 'Muy ligero, prioriza técnica'),
  ('Sentadilla goblet', 'Pierna', '10–15', 'Mancuerna frente al pecho'),
  ('Zancadas con mancuernas', 'Pierna', '10–12', 'Paso amplio y controlado'),
  ('Sentadilla búlgara', 'Pierna', '8–12', 'Pie trasero elevado'),
  ('Sentadilla sumo con mancuerna', 'Pierna', '10–15', 'Pies abiertos, puntas afuera'),
  ('Subidas al banco (step-up)', 'Pierna', '10–12', 'Empuja con el talón'),
  ('Peso muerto rumano', 'Glúteo', '8–12', 'Espalda estable'),
  ('Peso muerto con barra', 'Glúteo', '8–10', 'Peso que controles bien'),
  ('Puente de glúteo', 'Glúteo', '12–15', 'Aprieta arriba 1 segundo'),
  ('Hip thrust con barra', 'Glúteo', '8–12', 'Espalda apoyada en un banco'),
  ('Patada de glúteo con liga', 'Glúteo', '12–15', 'Sin arquear la espalda'),
  ('Abducción con liga', 'Glúteo', '12–20', 'Liga sobre las rodillas'),
  ('Buenos días con barra', 'Glúteo', '10–12', 'Poco peso, espalda neutra'),
  ('Elevación de talones de pie', 'Gemelos', '12–20', 'Sube lento, baja lento'),
  ('Elevación de talones con mancuernas', 'Gemelos', '12–15', 'Punta del pie en un escalón'),
  ('Elevación de talones sentado', 'Gemelos', '12–20', 'Mancuerna sobre las rodillas'),
  ('Elevación de talones a una pierna', 'Gemelos', '10–15', 'Apóyate para el equilibrio'),
];