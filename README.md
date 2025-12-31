# VoxGamer 🎮

**El Nexo del Jugador: Tu Enciclopedia de Videojuegos Offline.**

VoxGamer es una aplicación multiplataforma (Móvil y Web) desarrollada en Flutter, diseñada para ofrecer acceso instantáneo a una base de datos masiva de videojuegos. Gracias a su arquitectura **Offline-First** (en móviles) y optimizaciones de bajo nivel, permite explorar, filtrar y descubrir miles de títulos con una fluidez extrema.

<p align="center">
  <img src="assets/icon/app_logo.png" width="120" alt="VoxGamer Logo">
</p>

---

## ✨ Características Principales

### 🚀 Rendimiento Extremo (Arquitectura FastMode)
*   **Listados Ultrarrápidos:** Implementación de un modo de proyección de columnas SQL (`FastMode`) que permite un scroll infinito fluido reduciendo drásticamente el uso de memoria RAM y CPU.
*   **Carga Diferida de Detalles (Lazy Loading):** Las fichas de los juegos cargan información instantánea y completan datos pesados (descripciones largas, galerías, créditos) en segundo plano.
*   **Soporte Web:** Versión optimizada para navegadores utilizando caché en memoria para una experiencia ágil sin base de datos local persistente.

### 📚 Catálogo Masivo & Organizado
*   **Ecosistema Completo:** Navegación por pestañas dedicadas para **Juegos**, **DLCs** y **Próximos Lanzamientos**.
*   **Sincronización Background:** Motor ETL integrado (Native) mediante `flutter_background_service` que descarga y procesa bases de datos masivas sin congelar la interfaz, utilizando `wakelock_plus` para asegurar la integridad del proceso.
*   **Fuente de Datos:** Datos obtenidos gracias al proyecto [SteamDataScraper](https://github.com/andymartin1991/SteamDataScraper).

### 🔍 Sistema de Filtrado "Power User"
*   **Filtros Granulares:** Selección múltiple con lógica **AND** para Géneros, Plataformas e Idiomas.
*   **Idiomas:** Filtra específicamente por idioma de **Voces** y **Textos**.
*   **Control de Contenido (+18):** Switch de seguridad integrado en el panel de ajustes para filtrar contenido adulto al instante.
*   **Ordenación Flexible:** Clasificación por Fecha de Lanzamiento o Metascore.

### 🎬 Experiencia Multimedia & Social
*   **Reproductor Nativo:** Visualización de tráilers integrada (`video_player` + `chewie`).
*   **Deep Linking:** Comparte juegos específicos mediante enlaces universales (`voxgamer://` o enlaces web compatibles).
*   **Traducción Neural:** Integración para traducir descripciones al instante.
*   **Localización:** Soporte nativo para Español 🇪🇸 e Inglés 🇺🇸.

### 🎨 UX/UI "Digital Arcade"
*   **Diseño Dark Premium:** Estética oscura con acentos neón.
*   **Panel de Ajustes Glassmorphic:** Nuevo menú de configuración modal con efectos de desenfoque ("frosted glass"), interruptores animados y feedback háptico para una experiencia táctil superior.
*   **Minijuego de Espera:** Un "Runner" infinito ameniza los tiempos de carga durante la sincronización inicial.

---

## 🛠️ Stack Tecnológico

El proyecto utiliza las últimas capacidades de Flutter (Dart 3.5+) y un conjunto robusto de librerías:

| Área | Tecnología | Función |
| :--- | :--- | :--- |
| **Persistencia** | `sqflite` | Base de datos SQL local optimizada (Native). |
| **Background** | `flutter_background_service` | Tareas de sincronización en segundo plano. |
| **Energía** | `wakelock_plus` | Mantiene la pantalla activa durante procesos críticos. |
| **Notificaciones** | `flutter_local_notifications` | Permisos y alertas de sistema. |
| **Imágenes** | `cached_network_image` | Caché persistente y optimización de memoria. |
| **Multimedia** | `video_player`, `chewie` | Reproducción de video nativa. |
| **Red & Datos** | `http`, `archive` | Descarga y descompresión de streams GZIP. |
| **Navegación** | `app_links` | Gestión de Deep Links universales. |
| **UI** | `shimmer`, `google_fonts` | Efectos de carga y tipografía. |
| **Utilidades** | `translator`, `share_plus` | Traducción y compartir contenido. |

---

## 🏗️ Estructura de Datos Interna

La aplicación gestiona un ciclo de vida de datos complejo:

1.  **Fetch:** Descarga de `json.gz` desde CDN (GitHub Raw).
2.  **Compute:** Descompresión y parsing en un *Isolate* separado.
3.  **Batch Insert:** Inserción transaccional en SQLite (Native) o Web Cache (Web).
4.  **Indexing:** Índices SQL para búsquedas instantáneas por título y fecha.

---

## 🚀 Instalación y Despliegue

1.  **Clonar repositorio:**
    ```bash
    git clone https://github.com/tu-usuario/voxgamer.git
    ```
2.  **Instalar dependencias:**
    ```bash
    flutter pub get
    ```
3.  **Ejecutar:**
    ```bash
    # Para Móvil (Android/iOS)
    flutter run

    # Para Web
    flutter run -d chrome
    ```

> **Nota:** La primera ejecución activará la sincronización masiva. Asegúrate de tener conexión a internet.

---
*Desarrollado con ❤️ por el equipo de VoxGamer.*
