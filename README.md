# VoxGamer 🎮

**El Nexo del Jugador: Tu Enciclopedia de Videojuegos Offline.**

VoxGamer es una aplicación móvil de vanguardia desarrollada en Flutter, diseñada para ofrecer acceso instantáneo y offline a una base de datos masiva de videojuegos (Steam/RAWG). Gracias a su arquitectura **Offline-First** y optimizaciones de bajo nivel, permite explorar, filtrar y descubrir decenas de miles de títulos con una fluidez extrema.

<p align="center">
  <img src="assets/icon/app_logo.png" width="120" alt="VoxGamer Logo">
</p>

---

## ✨ Características Principales

### 🚀 Rendimiento Extremo (Arquitectura FastMode)
*   **Listados Ultrarrápidos:** Implementación de un modo de proyección de columnas SQL (`FastMode`) que permite un scroll infinito fluido reduciendo drásticamente el uso de memoria RAM y CPU.
*   **Carga Diferida de Detalles (Lazy Loading):** Las fichas de los juegos cargan información instantánea y completan datos pesados (descripciones largas, galerías, créditos) en segundo plano de forma transparente.
*   **Gestión Inteligente de Memoria:** Uso de `memCacheWidth` en el motor de renderizado de imágenes para evitar saturación de memoria en listas largas.

### 📚 Catálogo Masivo & Organizado
*   **Ecosistema Completo:** Navegación por pestañas dedicadas para **Juegos**, **DLCs** y **Próximos Lanzamientos**.
*   **Sincronización Background:** Motor ETL (Extract, Transform, Load) integrado mediante `flutter_background_service` que descarga, descomprime (GZIP) y procesa bases de datos masivas sin congelar la interfaz.
*   **Base de Datos Unificada:** Búsqueda transversal inteligente que localiza juegos tanto en el catálogo histórico como en futuros lanzamientos.

### 🔍 Sistema de Filtrado "Power User"
*   **Filtros Granulares e Inteligentes:**
    *   **Lógica de Selección:** Selección múltiple con lógica **AND** (intersección) para Géneros, Plataformas e Idiomas (ej. "Acción" + "RPG" busca juegos que sean *ambos*).
    *   **Idiomas:** Filtra específicamente por idioma de **Voces** y **Textos**.
    *   **Plataformas:** PC, PlayStation, Xbox, Nintendo, Android/iOS, etc.
    *   **Metadatos:** Género, Año de lanzamiento (lógica **OR**) y Puntuación.
*   **Control de Contenido (+18):** Sistema de seguridad opcional que filtra palabras clave y contenido adulto, con verificación de edad integrada.
*   **Ordenación Flexible:** Clasificación por Fecha de Lanzamiento (cronológica) o Metascore (calidad).

### 🎬 Experiencia Multimedia Inmersiva
*   **Reproductor Nativo:** Visualización de tráilers integrada (`video_player` + `chewie`) directamente en la cabecera del juego.
*   **Galería Híbrida:** Slider interactivo que combina videos y capturas de pantalla de alta resolución.
*   **Traducción Neural:** Integración con Google Translate para traducir descripciones de juegos a tu idioma local al instante.

### 🎨 UX/UI "Digital Arcade"
*   **Diseño Dark Premium:** Estética oscura con acentos neón, glassmorphism y transiciones suaves.
*   **Minijuego de Espera:** Un "Runner" infinito integrado ameniza los tiempos de carga durante la primera sincronización.
*   **Deep Linking:** Comparte juegos específicos mediante enlaces universales (`voxgamer://` o web links).

---

## 🛠️ Stack Tecnológico

El proyecto utiliza las últimas capacidades de Flutter (Dart 3.5+) y un conjunto robusto de librerías:

| Área | Tecnología | Función |
| :--- | :--- | :--- |
| **Persistencia** | `sqflite` | Base de datos SQL local optimizada (Schema v10). |
| **Procesamiento** | `flutter_background_service` | Tareas de sincronización en segundo plano. |
| **Imágenes** | `cached_network_image` | Caché persistente y optimización de memoria. |
| **Multimedia** | `video_player`, `chewie` | Reproducción de video nativa. |
| **Red & Datos** | `http`, `archive` | Descarga y descompresión de streams GZIP. |
| **UI** | `shimmer`, `google_fonts` | Efectos de carga esqueleto y tipografía. |
| **Utilidades** | `translator`, `app_links` | Traducción y Deep Links. |

---

## 🏗️ Estructura de Datos Interna

La aplicación gestiona un ciclo de vida de datos complejo para garantizar la disponibilidad offline:

1.  **Fetch:** Descarga de `json.gz` desde CDN.
2.  **Compute:** Descompresión y parsing en un *Isolate* separado para no bloquear la UI.
3.  **Batch Insert:** Inserción transaccional en SQLite (`games` y `upcoming_games`).
4.  **Indexing:** Generación de índices SQL para búsquedas instantáneas por título y fecha.
5.  **Query Projection:** Las listas solicitan solo 7 campos clave; el detalle solicita el registro completo (`SELECT *`).

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
    flutter run
    ```

> **Nota:** La primera ejecución activará la sincronización masiva. Asegúrate de tener conexión a internet. Posteriormente, la app es 100% funcional offline.

---
*Desarrollado con ❤️ por el equipo de VoxGamer.*
