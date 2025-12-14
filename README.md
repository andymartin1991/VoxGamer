# VoxGamer - Multiplatform Steam Catalog

**VoxGamer** es el cliente oficial del ecosistema "Steam Data Scraper". Es una aplicación moderna desarrollada en **Flutter** que permite consultar, filtrar y explorar el catálogo de juegos de Steam generado por nuestra herramienta de backend.

El proyecto es totalmente **Multiplataforma**, funcionando de manera nativa en **Android**, **iOS** y **Web**.

## 📱 Descripción del Proyecto

Esta aplicación actúa como el frontend para la base de datos de juegos. Mientras que la herramienta de backend (Java) descarga los metadatos y los optimiza en formatos JSON alojados en GitHub, **VoxGamer** consume estos datos para ofrecer una interfaz rápida, offline-first y potente.

### Ecosistema
1.  **Backend (Java):** [Steam Data Scraper](https://github.com/andymartin1991/SteamDataScraper) - Descarga datos de Steam y actualiza el JSON en GitHub.
2.  **Frontend (Flutter):** **VoxGamer** (Este repositorio) - Visualiza los datos en móviles y web.

## ✨ Características Principales

- **Búsqueda Inteligente:** Algoritmo de búsqueda normalizado que ignora tildes, símbolos y mayúsculas (ej: buscar "pokemon" encuentra "Pokémon").
- **Filtros Avanzados:** Capacidad de filtrar juegos por idioma de voces (Dubbing).
- **Orden Cronológico:** Los lanzamientos se ordenan automáticamente por fecha, mostrando primero lo más nuevo.
- **Detalle Rico:** Fichas de juego con carátulas, fechas, tamaños y desglose detallado de idiomas (Texto vs Audio).
- **Enlace a Tienda:** Apertura directa de la ficha de Steam en el navegador o app oficial.
- **Offline-First (Móvil):** En Android/iOS, descarga la base de datos completa a SQLite local para consultas instantáneas sin internet.
- **Web-Ready:** En navegadores, utiliza un sistema de caché en memoria RAM para una experiencia fluida sin necesidad de instalación.

## 🛠️ Stack Tecnológico

- **Framework:** Flutter (Dart)
- **Base de Datos (Móvil):** SQLite (`sqflite`)
- **Base de Datos (Web):** In-Memory Cache
- **Red:** `http` (Consumo de JSON raw desde GitHub)
- **Utilidades:** `url_launcher` (Navegación externa)

## 🚀 Cómo Ejecutar

### Prerrequisitos
- Flutter SDK instalado.
- Android Studio o VS Code.

### Pasos

1.  **Clonar el repositorio:**
    ```bash
    git clone https://github.com/andymartin1991/VoxGamer.git
    ```

2.  **Obtener dependencias:**
    ```bash
    flutter pub get
    ```

3.  **Ejecutar:**
    *   **Android:** Selecciona un emulador o dispositivo y pulsa Run.
    *   **Web:** Selecciona Chrome/Edge y pulsa Run.

## 🔄 Sincronización de Datos

La aplicación descarga automáticamente el catálogo la primera vez que se abre.
Si el backend actualiza el JSON, puedes:
1.  Usar la opción **"Sincronizar Rápido"** en el menú de la app.
2.  Si hay cambios estructurales graves, usar **"Restablecer Todo"** para borrar la base de datos local y descargar una copia limpia.

## 🤝 Contribución

Si deseas mejorar el scraper de datos, visita el repositorio del backend. Para mejoras en la interfaz o nuevos filtros, ¡los Pull Requests son bienvenidos aquí!
