# Investigación PPU/SPU — precompilación para PS5 estándar 13.42

Fecha: 2026-10-20. Rama: `feature/ps5-13.42-rpcs3`.

## Evidencia comprobada

La rama `ps5` de `lavavex/rpcs3` contiene en `rpcs3/Emu/Cell/` los componentes:
- PPU: `PPUAnalyser.cpp`, `PPUModule.cpp`, `PPUTranslator.cpp`, `PPUThread.cpp`, además de cabeceras y desensambladores.
- SPU: `SPUAnalyser.cpp`, `SPULLVMRecompiler.cpp`, `SPUASMJITRecompiler.cpp`, `SPUCommonRecompiler.cpp`, `SPUThread.cpp`, `SPURecompiler.h`.
- El script `tools/build-rpcs3.sh` del proyecto PS5 activa `WITH_LLVM=ON`, `STATIC_LINK_LLVM=ON` y enlaza LLVM construido para PS5.

Estos nombres y opciones demuestran que existen componentes de análisis y recompilación; **no** demuestran que el port ya admita exportar de forma independiente código PPU/SPU precompilado ni que se pueda convertir un juego completo en un ejecutable nativo.

## Hipótesis de optimización (pendientes de pruebas)

1. Medir cuánto tiempo de arranque se destina a compilación PPU, SPU y shaders. Los resultados deben salir del log de RPCS3 y mediciones reproducibles, no de suposiciones.
2. Estudiar los mecanismos actuales de caché y persistencia en el submódulo antes de agregar un modo propio de precompilación.
3. Evaluar una utilidad de **precalentamiento de caché**, con identidades verificables de juego/versión, opciones de recompilación, revisión del emulador y arquitectura de destino. No mezclar cachés entre revisiones sin validación.
4. Distinguir precompilación PPU de recompilación SPU dinámica: las SPU pueden cargar programas en ejecución, por lo que no se debe prometer cobertura completa previa.
5. Mantener esta optimización separada de la capa Vulkan/RSX, memoria directa/JIT y compatibilidad del firmware.

## Plan de ingeniería

### P0. Reproducibilidad
- Compilar sin modificaciones el port y recopilar el primer error, si existe.
- Arrancar el menú en PS5 estándar 13.42 sin juegos y guardar `/data/rpcs3/cache/RPCS3.log`.
- No cambiar offsets de firmware ni parámetros del JIT sin un fallo documentado.

### P1. Inventario del compilador/cachés
- Revisar `PPUTranslator.cpp`, `PPUAnalyser.cpp`, `SPULLVMRecompiler.cpp`, `SPUASMJITRecompiler.cpp` y las rutas que guardan/cargan caché.
- Documentar claves, ubicación, formato, invalidación y llamadas actuales al compilador.
- Formular pruebas unitarias/host sin consola cuando sea posible.

### P2. Medición de referencia
- Realizar 3 lanzamientos idénticos: primera ejecución sin cachés, segundo arranque con cachés y arranque posterior.
- Guardar tiempos PPU/SPU, shader, memoria, errores y tiempo hasta menú/juego. Sin borrar respaldos existentes.
- Elegir una demo o homebrew legítimo y pequeño para empezar, no God of War: Ascension.

### P3. Prototipo no invasivo
- Primero proponer una opción de diagnóstico que registre *cache hit/miss* PPU/SPU; por defecto desactivada.
- Si existen formatos de caché reutilizables, probar un proceso separado de preparación de caché para un único binario de prueba.
- Activar la utilidad solo si identifica completamente versión, arquitectura y opciones; validar equivalencia funcional contra el camino actual.

### P4. PS5 13.42
- Comparar compilación original vs prototipo con la misma entrada y los mismos ajustes.
- Registrar cierres, regresiones, latencias y posible mejora real de tiempos. Si empeora o afecta integridad, revertir.

## Guardarraíles

- No distribuir firmware, claves, juegos ni binarios combinados cuando sus licencias lo impidan.
- No afirmar que precalentar una caché convierte un juego PS3 en aplicación PS5 nativa.
- No modificar el submódulo `src/rpcs3` directamente sin crear primero una rama/versionado en su propio repositorio o sustituir explícitamente su referencia.
- Los cambios deben basarse en logs o pruebas reproducibles, con commit y ruta de reversión.

## Siguiente tarea concreta

Inspeccionar las funciones y estructuras de caché en los archivos PPU/SPU del submódulo, y producir una matriz de compatibilidad (formato, identidad, invalidación, arquitectura y dependencias) antes de escribir código.
