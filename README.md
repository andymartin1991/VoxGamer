# VoxGamer 🎮

**El Nexo del Jugador.**

VoxGamer es una aplicación Flutter de alto rendimiento diseñada para explorar un catálogo masivo de videojuegos de **Steam y RAWG**. Construida con una arquitectura *Offline-First* robusta y una estética "Digital Arcade Dark", ofrece una experiencia de navegación fluida, instantánea y visualmente inmersiva, capaz de manejar decenas de miles de registros sin conexión.

---

## ✨ Características Principales

### 🚀 Arquitectura y Rendimiento
*   **Offline-First Real:** Descarga, comprime y almacena localmente todo el catálogo. Una vez sincronizado, no necesitas internet para buscar o filtrar.
*   **Sincronización en Segundo Plano:** Utiliza `flutter_background_service` para gestionar la descarga y procesamiento masivo de datos sin interrupciones, incluso si minimizas la app. Mantiene al usuario informado mediante notificaciones de progreso.
*   **Estabilidad Mejorada:** Mecanismos de seguridad en el inicio para evitar congelamientos en dispositivos lentos durante la carga inicial de servicios.
*   **Recuperación Inteligente:** Si la sincronización inicial se interrumpe, la app es capaz de reanudar el procesamiento utilizando el archivo comprimido ya descargado, ahorrando datos y tiempo.
*   **Compresión GZIP & Isolates:** El catálogo se descarga comprimido (`.json.gz`) y se procesa en hilos secundarios para evitar bloqueos en la UI.
*   **Base de Datos Híbrida:**
    *   **Móvil (Android/iOS):** Motor SQLite (`sqflite`) altamente optimizado con inserción por lotes (chunks) y modo turbo.
    *   **Web:** Sistema de caché en memoria RAM optimizado para un filtrado instantáneo.

### 🎮 Minijuego de Espera (Interactive Sync)
Ameniza la espera durante la primera descarga masiva con un minijuego integrado tipo *Runner*:
*   **Mecánicas:** Salto clásico y **Doble Salto** con acrobacia.
*   **Físicas Refinadas:** Gravedad y colisiones ajustadas para una jugabilidad justa y fluida.
*   **Feedback Háptico:** Vibración inmersiva al saltar, aterrizar, colisionar y superar hitos de puntuación.
*   **Persistencia:** Guarda tu **High Score** (Récord) localmente para intentar superarlo en futuras actualizaciones.

### 🔍 Exploración Avanzada
*   **Buscador Inteligente:** Búsqueda instantánea por título con normalización y "debounce".
*   **Filtrado Profundo:**
    *   **Idiomas:** Voces y Textos.
    *   **Plataformas:** Windows, Mac, Linux, etc.
    *   **Metadatos:** Año, Género y Puntuación.
*   **Gestión Rápida de Filtros:** Visualización de filtros activos mediante *Chips* eliminables directamente desde la lista.
*   **Ordenación:** Por Fecha de Lanzamiento o Puntuación Metacritic.
*   **Categorización:** Pestañas para **Juegos**, **DLCs** y **Próximos Lanzamientos**.

### 🎨 Diseño "Digital Arcade Dark" (Premium UX)
*   **Identidad Visual:** Tema oscuro profundo con acentos Neón Violeta y Cian.
*   **Glassmorphism:** Efectos de desenfoque (blur) en la barra de navegación superior para una estética moderna y limpia.
*   **Tarjetas Premium:** Diseño de tarjetas con gradientes sutiles, bordes refinados y sombras suaves.
*   **UX Táctil:** Tipografía **Outfit**, animaciones **Shimmer** y respuesta háptica en interacciones clave.
*   **Interfaz Adaptable:** Soporte multilenguaje (Español/Inglés) y diseño responsivo.

---

## 🛠️ Stack Tecnológico (App)

*   **Framework:** Flutter & Dart (SDK >= 3.5.0)
*   **Base de Datos:** `sqflite` (SQLite) con gestión de transacciones y versiones.
*   **Servicios Background:** `flutter_background_service`, `flutter_local_notifications`.
*   **Gestión de Datos:** `http`, `archive` (GZIP), `shared_preferences`.
*   **Utilidades:** `wakelock_plus`, `url_launcher`, `translator` (traducción en tiempo real).
*   **UI:** `google_fonts`, `shimmer`, Material 3, `animations`.

---

## ⚙️ Backend: Steam & RAWG Data Scraper

VoxGamer se alimenta de una suite de herramientas en Java diseñada para recolectar, procesar y unificar metadatos. Su objetivo es generar la base de datos masiva y limpia (JSON) que consume la app.

### 🏗️ Arquitectura del Pipeline
El sistema funciona mediante una "tubería" de tres etapas: **Recolección (Raw)** -> **Enriquecimiento (Detail)** -> **Exportación (Scraper)**.

#### 1. Recolección (Collectors)
Descargan los datos crudos de las APIs y los almacenan en bases de datos SQLite locales.

*   **SteamRawCollector:** Descarga el catálogo completo de Steam (~180k apps).
*   **RAWGRawCollector:** Barrido inteligente e histórico de RAWG (~900k juegos) con rotación de API Keys.

#### 2. Enriquecimiento (Detail Collectors)
*   **RAWGDetailCollector:** Escanea y completa juegos con descripciones y metadatos profundos.

#### 3. Exportación y Fusión (Union)
*   **SteamScraper & RAWGScraper:** Limpieza y normalización de datos.
*   **GlobalUnion:** Fusión final eliminando duplicados y generando el maestro **`global_games.json.gz`**.

---

## 🚀 Instalación y Despliegue (App)

### Requisitos
*   Flutter SDK instalado.
*   Entorno configurado para Android (Android Studio) o Web.

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
    *   **Android:** `flutter run`
    *   **Web:** `flutter run -d chrome --web-renderer html`

---

## 📱 Guía de Uso

1.  **Sincronización Inicial:**
    Al abrir la app por primera vez, se iniciará el servicio de descarga.
    *   **Minijuego:** Mientras esperas, puedes jugar al "Bug Runner" tocando la pantalla. ¡Intenta superar tu récord!
    *   **Background:** Puedes salir de la app; la descarga continuará en segundo plano (notificación persistente).

2.  **Navegación:**
    *   Explora las pestañas **JUEGOS**, **DLCs** y **PRÓXIMOS**.
    *   Usa el buscador superior para encontrar títulos específicos.

3.  **Filtros:**
    *   Toca el icono de **Ajustes** para filtrar por Plataforma, Género, Año, Idioma, etc.
    *   Los filtros activos aparecen sobre la lista y se pueden eliminar tocando la "X".

4.  **Detalles:**
    *   Toca una tarjeta para ver la ficha completa.
    *   Usa el botón de **Traducción** para leer la descripción en tu idioma.

---

## ⚠️ Solución de Problemas

*   **La sincronización se detiene:**
    Gracias a `flutter_background_service`, esto es inusual. Si sucede por gestión agresiva de batería, vuelve a abrir la app; el sistema intentará recuperar el archivo descargado.
*   **Base de datos corrupta:**
    Si experimentas cierres inesperados, borra los datos de la app desde los ajustes de Android. La app se reiniciará limpia en la próxima ejecución.

---
*VoxGamer - The Gamer Nexus.*
