# AccNized

**Cuentas digitales y notas vinculadas, organizadas en tu dispositivo.**

Aplicación Flutter para clasificar cuentas, asociar notas y servicios, usar etiquetas y personalizar la interfaz. Guarda los datos en SQLite local.

**[Descargar la distribución publicada](https://github.com/JuanEstebanHerreraH/AccNized/releases/tag/Accnized)**

El archivo disponible es `EjecutableAccNized.zip`. El código incluye objetivos Windows y Android; la versión publicada no adjunta un APK independiente.

**Decisión de implementación:** cuentas y notas se relacionan en una base SQLite para consultar sus vínculos sin un servidor.

**Límite de seguridad:** las contraseñas se guardan en texto plano en la base local. La ocultación de una cuenta o nota en la interfaz no equivale a cifrado; no debe usarse como un gestor de contraseñas seguro.

<details>
<summary><strong>Funciones, requisitos y documentación técnica</strong></summary>

## 🔍 ¿Qué es AccNized?

**AccNized** es una aplicación de escritorio y móvil para organizar tus cuentas digitales de forma segura y completamente **offline**. Sin servidores, sin suscripciones, sin que tus datos salgan de tu dispositivo.

Organiza correos, redes sociales y servicios, añade notas privadas vinculadas a cada cuenta, protege lo sensible con contraseña, y personaliza todo a tu gusto.

---

## ✨ Características principales

| Ícono | Función | Descripción |
|:---:|---|---|
| 🔐 | **Cuentas protegidas** | Contraseña opcional por cuenta. El contenido queda oculto hasta autenticarte |
| 🏷️ | **Etiquetas** | Sistema de etiquetas con colores para clasificar y filtrar cuentas y notas |
| 🔗 | **Usos vinculados** | Registra en qué servicios se usa cada cuenta |
| 🎨 | **Icono personalizado** | Elige entre 30+ iconos para identificar visualmente cada cuenta |
| 📝 | **Notas con estilo** | Editor de notas con color de fondo, color de título, color de contenido y tamaño de fuente |
| 🔒 | **Notas privadas** | Una nota privada solo se ve al entrar a la cuenta vinculada, nunca en la lista pública |
| 🔗 | **Notas ↔ Cuentas** | Vincula notas a una o varias cuentas. Aparecen en el detalle de cada una |
| 🌗 | **Tema claro/oscuro** | Se adapta automáticamente al sistema operativo |
| 💾 | **100% offline** | Base de datos SQLite local. Tus datos nunca salen del dispositivo |

---

## 🗄️ Base de datos (SQLite local)

```
accounts          → Cuentas (identificador, tipo, icono, contraseña)
  │
  ├── usages      → Usos de cada cuenta (Discord, Twitter, etc.)
  │
  └── account_labels ──┐
                        ├── labels → Etiquetas compartidas (cuentas y notas)
  ┌── note_labels ──────┘
  │
notes             → Notas (fondo, título, contenido, privacidad)
  │
  └── account_notes → Vínculos nota ↔ cuenta (muchos a muchos)
```

---

## 🚀 Instalación

### Requisitos

- Flutter SDK ≥ 3.22 → [flutter.dev](https://flutter.dev/docs/get-started/install)
- **Windows:** Visual Studio 2022/2026 con workload **"Desarrollo para escritorio con C++"**
- **Android:** Android Studio + SDK o dispositivo físico con USB debug

### Pasos

**1. Clonar el repositorio**
```bash
git clone https://github.com/JuanEstebanHerreraH/AccNized.git
cd accnized
```

**2. Instalar dependencias**
```bash
flutter pub get
```

**3. Ejecutar en Windows**
```bash
flutter run -d windows
```

**4. Ejecutar en Android**
```bash
flutter run -d android
```

---

## 📦 Compilar para distribución

**APK para Android**
```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

**Ejecutable Windows**
```bash
flutter build windows --release
# → build/windows/x64/runner/Release/accnized.exe
```

---

## 📁 Estructura del proyecto

```
accnized/
│
├── 📁 lib/
│   ├── main.dart                        # Entrada, tema M3, navegación
│   │
│   ├── 📁 models/
│   │   ├── account.dart                 # Cuenta con icono y contraseña
│   │   ├── usage.dart                   # Uso vinculado a cuenta
│   │   ├── label.dart                   # Etiqueta con color
│   │   └── note.dart                    # Nota con colores y privacidad
│   │
│   ├── 📁 database/
│   │   └── database_helper.dart         # CRUD SQLite + migraciones
│   │
│   ├── 📁 screens/
│   │   ├── home_screen.dart             # Lista de cuentas + filtros
│   │   ├── account_detail_screen.dart   # Detalle + gate de contraseña
│   │   ├── account_form_screen.dart     # Crear / editar cuenta
│   │   ├── labels_screen.dart           # Gestión de etiquetas
│   │   ├── notes_screen.dart            # Grid de notas públicas
│   │   └── note_editor_screen.dart      # Editor completo de notas
│   │
│   ├── 📁 widgets/
│   │   ├── account_card.dart            # Tarjeta de cuenta
│   │   ├── label_chip.dart              # Chip de etiqueta
│   │   └── icon_picker_dialog.dart      # Selector de icono
│   │
│   └── 📁 utils/
│       └── account_icons.dart           # Mapa de 30+ iconos
│
├── pubspec.yaml
├── .gitignore
└── README.md
```

---

## 🔒 Privacidad y seguridad

- **Sin internet:** AccNized no hace ninguna petición de red. Todo es local.
- **Contraseña por cuenta:** Al entrar a una cuenta protegida se pide la clave. El contenido queda invisible en la lista principal.
- **Notas privadas:** Marcando una nota como privada, desaparece de la pantalla "Notas" y solo es visible dentro de la cuenta vinculada (que puede tener su propia contraseña).
- **Sin analytics:** No hay telemetría, rastreo ni recolección de datos de ningún tipo.

> ⚠️ Las contraseñas se guardan en texto plano en la base de datos local. Para mayor seguridad, cifra el disco de tu dispositivo.

---

## 🧩 Dependencias

| Paquete | Versión | Uso |
|---|---|---|
| `sqflite` | ^2.3.3 | Base de datos SQLite (Android) |
| `sqflite_common_ffi` | ^2.3.4 | SQLite para Windows/Linux |
| `path_provider` | ^2.1.3 | Ruta de la base de datos |
| `path` | ^1.9.0 | Manejo de rutas de archivos |
| `intl` | ^0.19.0 | Formato de fechas |
| `uuid` | ^4.4.2 | Identificadores únicos |

## Distribución

Descarga el ZIP disponible en [Releases](https://github.com/JuanEstebanHerreraH/AccNized/releases/tag/Accnized), extrae su contenido y conserva sus archivos juntos. Para Android, consulta las instrucciones de compilación anteriores.

</details>
