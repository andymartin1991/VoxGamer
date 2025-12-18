# VoxGamer 🎮

**El Nexo del Jugador.**

VoxGamer es una aplicación Flutter de alto rendimiento diseñada para explorar un catálogo masivo de más de **75,000 videojuegos de Steam**. Construida con una arquitectura *Offline-First* y una estética "Digital Arcade Dark", ofrece una experiencia de navegación fluida, instantánea y visualmente inmersiva.

---

## ✨ Características Principales

### 🚀 Rendimiento y Arquitectura
*   **Catálogo Masivo Offline:** Descarga, comprime y almacena localmente +75k títulos. Funciona perfectamente sin conexión tras la primera sincronización.
*   **Compresión GZIP:** El sistema descarga datos comprimidos (`.json.gz`) y los procesa en tiempo real mediante *Isolates* (hilos secundarios) para minimizar el uso de datos y evitar bloqueos en la interfaz.
*   **Persistencia Híbrida:**
    *   **Android:** Motor SQLite (`sqflite`) optimizado con inserción por lotes (chunks) para manejar miles de registros sin saturar la memoria.
    *   **Web:** Sistema de caché en memoria RAM con indexación rápida.

### 🔍 Filtros Dinámicos Inteligentes
Olvídate de filtros vacíos. VoxGamer analiza tu catálogo local y genera opciones basadas únicamente en los datos reales existentes:
*   **Idiomas:** Filtra por **Voces** y **Textos** (Subtítulos/Interfaz) disponibles.
*   **Años:** Selector de años generado dinámicamente según el historial de lanzamientos.
*   **Géneros:** Categorías extraídas automáticamente de los metadatos de Steam.
*   **Búsqueda Inteligente:** Los menús desplegables permiten escribir para buscar opciones rápidamente (ej: escribe "Esp" para saltar a Español).

### 🎨 Diseño "Digital Arcade Dark"
*   **Identidad Visual:** Tema oscuro profundo (`#0A0E14`) con acentos Neón Violeta (`#7C4DFF`) y Cian (`#03DAC6`).
*   **UX Premium:**
    *   Tipografía moderna **Outfit** para máxima legibilidad.
    *   Tarjetas de juego con efecto "Glow" y esquinas suavizadas.
    *   Carga progresiva con animaciones **Shimmer** (esqueletos de carga).
    *   Iconografía personalizada e integración nativa en Android/iOS.

---

## 🛠️ Stack Tecnológico

*   **Framework:** Flutter & Dart (SDK >= 3.5.0)
*   **Base de Datos:** `sqflite` (SQLite) con estrategia de desnormalización JSON para alto rendimiento en lectura.
*   **Red & Datos:** `http`, `archive` (descompresión GZIP), `flutter_launcher_icons`.
*   **UI & Diseño:** `google_fonts`, `shimmer`, Material 3.

---

## 🚀 Instalación y Despliegue

### Requisitos
*   Flutter SDK instalado.
*   Android Studio / VS Code.

### Pasos
1.  **Clonar el repositorio:**
    ```bash
    git clone https://github.com/tu-usuario/voxgamer.git
    cd voxgamer
    ```

2.  **Instalar dependencias:**
    ```bash
    flutter pub get
    ```

3.  **Ejecutar la aplicación:**
    *   **Android:**
        ```bash
        flutter run
        ```
    *   **Web:**
        ```bash
        flutter run -d chrome --web-renderer html
        ```

---

## 📱 Guía de Uso

1.  **Primera Carga:** Al abrir la app, verás una barra de estado indicando la descarga y descompresión del catálogo. Esto ocurre solo una vez.
2.  **Filtrado:** Toca el icono de ajustes en la barra superior.
    *   Selecciona filtros combinados (ej: "Voces: Español" + "Género: RPG" + "Año: 2023").
    *   Usa el buscador dentro del desplegable para encontrar idiomas raros rápidamente.
    *   Pulsa la 'X' en el campo para limpiar un filtro individual.
3.  **Gestión de Datos:** Si deseas actualizar el catálogo manualmente, usa el menú de tres puntos (esquina superior derecha) y selecciona **"Sincronizar Rápido"** o **"Restablecer Todo"** (para una instalación limpia).

---

## ⚠️ Solución de Problemas

*   **Pantalla negra en Emulador Android:** Si detienes la app durante la inserción masiva de la base de datos (primera carga), los datos pueden corromperse.
    *   *Solución:* Desinstala la app del emulador o borra los datos de almacenamiento de la app y vuelve a ejecutar.
*   **Errores de compilación:** Si ves errores de `google_fonts` o `shimmer` no encontrados, asegúrate de ejecutar `flutter pub get` tras actualizar el código.

---
*VoxGamer - The Gamer Nexus.*
