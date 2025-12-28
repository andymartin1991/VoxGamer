# VoxGamer 🎮

**El Nexo del Jugador.**

VoxGamer es una aplicación Flutter de vanguardia diseñada para ser la enciclopedia definitiva de videojuegos en tu bolsillo. Combina la potencia de **Steam y RAWG** en una experiencia **Offline-First** ultrarrápida. Con una estética "Digital Arcade Dark", VoxGamer permite explorar, filtrar y descubrir decenas de miles de títulos sin necesidad de una conexión permanente a internet.

<p align="center">
  <img src="assets/icon/app_logo.png" width="120" alt="VoxGamer Logo">
</p>

---

## ✨ Características Principales

### 🧠 Arquitectura Offline-First & High Performance
*   **Base de Datos Local Masiva:** Descarga y almacena localmente metadatos de miles de juegos utilizando **SQLite** (`sqflite`).
*   **Caché de Imágenes Inteligente:** 
    *   Integración de `cached_network_image` y `flutter_cache_manager`.
    *   Las carátulas y capturas se guardan en el dispositivo para una navegación offline fluida.
    *   Optimización de memoria RAM (`memCacheWidth`) para listados infinitos sin caídas de rendimiento.
*   **Sincronización Inteligente en Segundo Plano:**
    *   Utiliza `flutter_background_service` para procesar archivos masivos (`.json.gz`) sin bloquear la interfaz.
    *   **Turbo Mode:** Motor de inserción optimizado con transacciones por lotes (chunks) y gestión dinámica de índices.
*   **Versión de DB v9:** Estructura optimizada que incluye soporte para Videos, Desarrolladores y Editores.

### 🎬 Experiencia Multimedia Inmersiva
*   **Reproductor de Video Nativo (In-App):** 
    *   Integración de `video_player` y `chewie` para ver trailers directamente en la ficha del juego sin salir de la aplicación.
    *   Galería híbrida ("Media Strip") que combina videos e imágenes fluidamente.
*   **Sección de Créditos Interactiva:**
    *   Descubre juegos por **Desarrollador** o **Editor** pulsando en los chips dedicados.

### 🔍 Exploración y Descubrimiento Profundo
*   **Búsqueda Instantánea:** Buscador con *debounce* y normalización de texto.
*   **Sistema de Filtrado Avanzado:**
    *   **Plataformas:** PC, PlayStation, Xbox, Nintendo, SEGA, etc.
    *   **Idiomas:** Filtra específicamente por idioma de **Voces** y **Textos**.
    *   **Metadatos:** Año de lanzamiento, Género y Puntuación.
*   **Ordenación Flexible:** Organiza por Fecha o Metascore.
*   **Paginación Eficiente:** Listas infinitas optimizadas con paginación de 50 elementos para un scroll continuo.

### 🎨 Experiencia de Usuario "Premium" (UX/UI)
*   **Diseño Digital Arcade Dark:** Tema oscuro profundo con acentos neón (Violeta/Cian).
*   **Glassmorphism:** Efectos de desenfoque (*blur*) en tiempo real.
*   **Internacionalización (i18n):** Soporte nativo para **Español** e **Inglés**.

### 🔗 Integración y Utilidades
*   **Deep Linking:** Comparte y abre juegos mediante `voxgamer://game/<slug>`.
*   **Minijuego de Espera:** Ameniza la sincronización inicial con un *Runner* integrado.
*   **Traducción en Tiempo Real:** Traduce descripciones al vuelo con un toque.
*   **Gestión de Almacenamiento:** Herramientas para limpiar la caché de imágenes desde la app.

---

## 🛠️ Stack Tecnológico

El proyecto está construido sobre **Flutter** (Dart SDK >= 3.5.0) y utiliza un conjunto robusto de librerías:

| Categoría | Librerías Clave |
| :--- | :--- |
| **Core & UI** | `flutter`, `google_fonts`, `shimmer`, `animations` |
| **Multimedia** | `video_player`, `chewie`, `cached_network_image`, `flutter_cache_manager` |
| **Persistencia** | `sqflite`, `shared_preferences`, `path_provider` |
| **Datos & Red** | `http`, `archive` (GZIP), `html` |
| **Servicios** | `flutter_background_service`, `flutter_local_notifications`, `wakelock_plus` |
| **Integración** | `app_links`, `url_launcher`, `translator`, `share_plus` |

---

## 🏗️ Estructura de Datos (Backend Pipeline)

VoxGamer consume datos generados por una suite de herramientas externa que unifica fuentes de Steam y RAWG.

**Tablas Principales (SQLite v9):**
*   `games`: Catálogo principal (Slug, Título, Descripción, Metacritic, Videos, Desarrolladores, Editores, etc.).
*   `upcoming_games`: Tabla ligera para lanzamientos futuros.
*   `meta_filters`: Índices optimizados para los filtros de la UI.

---

## 🚀 Guía de Instalación

### Requisitos
*   Flutter SDK instalado (Canal estable).
*   Android Studio / VS Code.
*   Dispositivo Android (min SDK 21).

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

3.  **Ejecutar:**
    ```bash
    flutter run
    ```

---

## 📱 Deep Links

La aplicación soporta navegación directa a fichas de juegos.

*   **Esquema Custom:** `voxgamer://game/{slug}?year={year}`
*   **Web Link (GitHub Pages):** `https://andymartin1991.github.io/VoxGamer/game/{slug}`

---
*Developed with ❤️ by VoxGamer Team.*
