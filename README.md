# VoxGamer 🎮

**El Nexo del Jugador.**

VoxGamer es una aplicación Flutter de alto rendimiento diseñada para explorar un catálogo masivo de videojuegos de **Steam y RAWG**. Construida con una arquitectura *Offline-First* robusta y una estética "Digital Arcade Dark", ofrece una experiencia de navegación fluida, instantánea y visualmente inmersiva, capaz de manejar decenas de miles de registros sin conexión.

---

## ✨ Características Principales

### 🚀 Arquitectura y Rendimiento
*   **Offline-First Real:** Descarga, comprime y almacena localmente todo el catálogo. Una vez sincronizado, no necesitas internet para buscar o filtrar.
*   **Sincronización en Segundo Plano:** Utiliza `flutter_background_service` para gestionar la descarga y procesamiento masivo de datos sin interrupciones, incluso si minimizas la app. Mantiene al usuario informado mediante notificaciones de progreso.
*   **Recuperación Inteligente:** Si la sincronización inicial se interrumpe (ej. cierre forzoso), la app detecta el estado incompleto y es capaz de reanudar el procesamiento utilizando el archivo comprimido ya descargado, ahorrando datos y tiempo.
*   **Compresión GZIP & Isolates:** El catálogo se descarga comprimido (`.json.gz`) y se procesa en hilos secundarios (Isolates) para evitar congelamientos en la UI.
*   **Base de Datos Híbrida:**
    *   **Móvil (Android/iOS):** Motor SQLite (`sqflite`) altamente optimizado con inserción por lotes (chunks), índices estratégicos y modo turbo para manejar +75k registros.
    *   **Web:** Sistema de caché en memoria RAM optimizado para un filtrado instantáneo en navegadores.

### 🔍 Exploración Avanzada
*   **Buscador Inteligente:** Búsqueda instantánea por título con normalización de caracteres y "debounce" para optimizar consultas.
*   **Filtrado Profundo:**
    *   **Idiomas:** Distingue entre **Voces** y **Textos** disponibles.
    *   **Plataformas:** Identifica juegos compatibles con Windows, Mac, Linux, y más.
    *   **Metadatos:** Filtra por Año de lanzamiento y Género.
*   **Gestión Rápida de Filtros:** Visualización de filtros activos mediante *Chips* eliminables directamente desde la lista, permitiendo refinar la búsqueda rápidamente sin reabrir el panel de configuración.
*   **Ordenación:** Ordena los resultados por **Fecha de Lanzamiento** o **Puntuación Metacritic**.
*   **Categorización:** Pestañas dedicadas para **Juegos** y **DLCs**.

### 🎨 Diseño "Digital Arcade Dark"
*   **Identidad Visual:** Tema oscuro profundo (`#0A0E14`) con acentos Neón Violeta (`#7C4DFF`) y Cian (`#03DAC6`).
*   **UX Premium:**
    *   Tipografía **Outfit** para máxima legibilidad.
    *   Animaciones **Shimmer** durante la carga.
    *   Indicadores visuales de calidad (código de colores para notas de Metacritic).
    *   Interfaz adaptable con soporte multilenguaje (Español/Inglés).

---

## 🛠️ Stack Tecnológico (App)

*   **Framework:** Flutter & Dart (SDK >= 3.5.0)
*   **Base de Datos:** `sqflite` (SQLite) con gestión de transacciones y versiones (`voxgamer_v6.db`).
*   **Servicios Background:** `flutter_background_service`, `flutter_local_notifications`.
*   **Gestión de Datos:** `http`, `archive` (GZIP), `shared_preferences`.
*   **Utilidades:** `wakelock_plus` (evita suspensión durante sync), `url_launcher`.
*   **UI:** `google_fonts`, `shimmer`, Material 3.

---

## ⚙️ Backend: Steam & RAWG Data Scraper

VoxGamer se alimenta de una suite de herramientas en Java diseñada para recolectar, procesar y unificar metadatos. Su objetivo es generar la base de datos masiva y limpia (JSON) que consume la app.

### 🏗️ Arquitectura del Pipeline
El sistema funciona mediante una "tubería" de tres etapas: **Recolección (Raw)** -> **Enriquecimiento (Detail)** -> **Exportación (Scraper)**.

#### 1. Recolección (Collectors)
Descargan los datos crudos de las APIs y los almacenan en bases de datos SQLite locales.

*   **SteamRawCollector:**
    *   Descarga el catálogo completo de Steam (~180k apps).
    *   Estrategia: Barrido secuencial de IDs guardado en `steam_raw.sqlite`.
*   **RAWGRawCollector:**
    *   **Modo Dual Inteligente:** Activa "Llenado Masivo" (barrido histórico) o "Mantenimiento" (últimas actualizaciones) según el estado de la DB local.
    *   **Estrategia de Barrido Decenal:** Divide cada mes en 3 bloques para evitar límites de paginación de la API, garantizando el 100% del catálogo (~900k juegos).
    *   **Resiliencia:** Progreso persistente reanudable y rotación automática de API Keys para evitar errores 401/429.

#### 2. Enriquecimiento (Detail Collectors)
*   **RAWGDetailCollector:** Escanea `rawg_raw.sqlite` buscando juegos incompletos y descarga detalles profundos (descripciones, tiendas). Implementa "cooldown" de 3 días para reintentos inteligentes.

#### 3. Exportación y Fusión (Union)
*   **SteamScraper & RAWGScraper:** Limpian textos, extraen requisitos e imágenes, y generan archivos `.json.gz` intermedios.
*   **GlobalUnion:** El paso final. Fusiona ambos catálogos eliminando duplicados (priorizando Steam para PC) y genera el archivo maestro **`global_games.json.gz`**.

### ▶️ Ejecución del Pipeline (Java)

```bash
# 1. Recolección
./gradlew SteamRawCollector.main()
./gradlew RAWGRawCollector.main()   # Reanudable

# 2. Enriquecimiento (Background)
./gradlew RAWGDetailCollector.main()

# 3. Generación y Fusión
./gradlew SteamScraper.main()
./gradlew RAWGScraper.main()
./gradlew GlobalUnion.main()
```

### 📂 Estructura de Datos
El archivo resultante `global_games.json.gz` sigue este contrato:

```json
{
  "slug": "half-life-2",
  "titulo": "Half-Life 2",
  "tipo": "game",
  "descripcion_corta": "The Seven Hour War is lost...",
  "fecha_lanzamiento": "2004-11-16",
  "storage": "6500 MB",
  "generos": ["Shooter", "Action"],
  "plataformas": ["PC", "Xbox 360", "PlayStation 3"],
  "img_principal": "https://...",
  "galeria": ["url1", "url2"],
  "idiomas": {
    "voces": ["English"],
    "textos": ["English", "Spanish"]
  },
  "metacritic": 96,
  "tiendas": [
    {
      "tienda": "Steam", 
      "url": "https://store.steampowered.com/app/220"
    }
  ]
}
```

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
    Al abrir la app por primera vez, se iniciará el servicio de descarga. Una notificación persistente te mantendrá informado del progreso ("Procesando: 45%").
    *Nota: Puedes salir de la app mientras esto ocurre; el servicio en segundo plano terminará el trabajo.*

2.  **Navegación:**
    *   Usa las pestañas superiores para alternar entre **JUEGOS** base y contenido descargable (**DLCs**).
    *   Toca una tarjeta para ver detalles como descripción, tiendas y galería.

3.  **Filtros:**
    Toca el botón de ajustes (icono de ecualizador) para abrir el panel de filtros.
    *   Combina múltiples criterios (ej: "RPG" + "Español (Voces)" + "Mejor Valorados").
    *   Usa los buscadores internos de los desplegables para encontrar opciones rápidamente.
    *   **Tip:** Los filtros activos aparecerán como etiquetas (chips) sobre la lista. Puedes tocarlos para eliminarlos individualmente.

4.  **Actualización:**
    Si deseas refrescar el catálogo manualmente, usa el menú de tres puntos en la esquina superior derecha y selecciona la opción de actualizar.

---

## ⚠️ Solución de Problemas

*   **La sincronización se detiene:**
    Gracias a `flutter_background_service` y `wakelock_plus`, esto es inusual. Sin embargo, en algunos fabricantes de Android con gestión de batería agresiva, asegúrate de no "matar" la app desde la multitarea durante la *primera* instalación masiva. Si sucede, vuelve a abrir la app; el sistema intentará recuperar el archivo descargado para no empezar de cero.
*   **Base de datos corrupta:**
    Si experimentas cierres inesperados tras una actualización fallida, ve a *Ajustes de Android > Aplicaciones > VoxGamer > Almacenamiento* y borra los datos. La app se reiniciará limpia.

---
*VoxGamer - The Gamer Nexus.*
