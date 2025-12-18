# VoxGamer 🎮

VoxGamer es una aplicación Flutter moderna para explorar un catálogo masivo de juegos de Steam (más de 75,000 títulos). Permite filtrar por idiomas de voces y textos, géneros y año de lanzamiento de manera rápida y eficiente.

## ✨ Características Principales

*   **Catálogo Masivo Offline:** Descarga y almacena localmente una base de datos de +75k juegos.
*   **Filtros Dinámicos Inteligentes:**
    *   Los filtros (Idiomas, Géneros, Años) se generan automáticamente basándose en los datos reales del catálogo.
    *   Búsqueda instantánea dentro de los desplegables de filtro.
*   **Optimización de Rendimiento:**
    *   **Android:** Uso de SQLite con inserción por lotes (chunks) para manejar grandes volúmenes de datos sin bloquear la UI.
    *   **Web:** Caché en memoria RAM con ordenamiento optimizado.
    *   **Red:** Descarga de datos comprimidos (`.json.gz`) para reducir el consumo de datos y tiempo de carga.
*   **Interfaz Moderna (Material 3):** Diseño limpio con soporte para imágenes cacheadas y modo oscuro/claro automático.

## 🛠️ Tecnologías Utilizadas

*   **Flutter & Dart** (SDK >= 3.5.0)
*   **SQLite (`sqflite`):** Persistencia de datos local en Android/iOS.
*   **GZIP (`archive`):** Descompresión de datos en tiempo real.
*   **HTTP (`http`):** Descarga de datos remotos.
*   **Isolates (`compute`):** Procesamiento de datos pesados en segundo plano para no congelar la interfaz.

## 🚀 Instalación y Ejecución

### Requisitos Previos
*   Flutter SDK instalado.
*   Android Studio o VS Code configurado.
*   Dispositivo Android (físico o emulador) o navegador Chrome.

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
        flutter run -d chrome
        ```

## 📱 Uso de la Aplicación

1.  **Primera Carga:** Al abrir la app por primera vez, descargará y procesará el catálogo comprimido. Esto puede tomar unos segundos dependiendo de tu conexión y dispositivo.
2.  **Filtrado:** Toca el icono de filtro en la barra superior.
    *   Selecciona **Idioma de Voces** o **Texto**.
    *   Filtra por **Género** o **Año**.
    *   Puedes escribir dentro de los desplegables para buscar opciones rápidamente.
3.  **Búsqueda:** Usa la barra superior para buscar juegos por título.
4.  **Reset:** Si necesitas recargar los datos, usa el menú de tres puntos -> "Restablecer Todo".

## 📂 Estructura del Proyecto

*   `lib/main.dart`: Punto de entrada y lógica de la interfaz principal.
*   `lib/models/`: Modelos de datos (`SteamGame`).
*   `lib/services/`:
    *   `data_service.dart`: Gestión de descarga, descompresión y lógica de negocio.
    *   `database_helper.dart`: Gestión de SQLite y consultas optimizadas.
*   `lib/screens/`: Pantallas secundarias como el detalle del juego.

## ⚠️ Solución de Problemas Comunes

*   **Pantalla negra en Android:** Si la base de datos se corrompe por una interrupción, desinstala la app del emulador y vuelve a ejecutarla.
*   **Error de Gradle:** Ejecuta `flutter clean` y luego `flutter pub get` si cambias de rama o dependencias.

---
Desarrollado con ❤️ usando Flutter.
