class Ex{
  final String name, reps,tip, unit;
  const Ex(this.name,this.reps,this.tip,{this.unit = 'reps'});
}

const baseSets = 2;

const routines = <String, List<Ex>>{
  'A': [
    Ex('Sentadilla con barra', '8–12', 'Muy ligero, prioriza técnica'),
    Ex('Press de pecho con mancuernas', '8–12', 'Puede ser en el suelo'),
    Ex('Remo con barra', '8–12', 'Barra hacia el abdomen'),
    Ex('Peso muerto rumano', '8–12', 'Espalda estable'),
    Ex('Press de hombros', '8–12', 'De pie o sentado'),
    Ex('Curl de bíceps', '10–15', 'Movimiento controlado'),
    Ex('Extensión de tríceps con liga', '10–15', 'Sin balancear el cuerpo'),
    Ex('Plancha', '15–30 s', 'Abdomen y glúteos activos', unit: 'seg'),
  ],
  'B':[
    Ex('Sentadilla goblet', '10–15', 'Mancuerna frente al pecho'),
    Ex('Press de pecho', '8–12', 'Mancuernas o barra, con seguridad'),
    Ex('Remo con mancuerna (por lado)', '10–12', 'Controla el descenso'),
    Ex('Peso muerto con barra', '8–10', 'Peso que controles bien'),
    Ex('Elevaciones laterales', '12–15', 'Poco peso, sin balanceo'),
    Ex('Curl martillo', '10–15', 'Muñecas neutras'),
    Ex('Face pull con liga', '12–15', 'Espalda alta y hombros'),
    Ex('Dead bug (por lado)', '8–10', 'Lento y controlado'),
  ],
};