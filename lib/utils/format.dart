String fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();


String shortDate(String d) => d.length > 16 ? d.substring(0, 16) : d;

String fmtMins(int s) => s >= 60 ? '${s ~/ 60} min ${s % 60} s' : '$s s';