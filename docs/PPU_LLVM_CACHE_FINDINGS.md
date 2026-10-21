# Hallazgo confirmado: caché PPU LLVM y viabilidad de precompilar fuera de PS5

Fecha: 2026-10-20. Auditoría estática de `lavavex/rpcs3` rama `ps5`, no compilación ni prueba de consola.

## Código verificado

1. `rpcs3/Emu/System.cpp`, `Emulator::ConfigurePPUCache()` (~4403–4418): calcula directorio con `rpcs3::utils::get_cache_dir(_main.path)` y agrega `ppu-<base57 SHA1>-<basename>/`. Crea la carpeta y registra la ruta.
2. `rpcs3/Emu/Cell/PPUThread.cpp`, `ppu_initialize()` (~4890): si el decoder PPU **no** es LLVM sigue otra ruta, por lo que esta optimización depende de seleccionar LLVM.
3. `PPUThread.cpp` (~5530–5610): construye nombre de archivo objeto `v8-kusa-<hash>-<settings>-<cpu>.obj`; `settings` incorpora flags que afectan generación de código (p. ej., exactitud de punto flotante, comportamiento de líneas de caché, reservas, DAZ/FTZ), además de bit de plataforma y resolución de símbolos. Existe un comentario TODO para poblar más ajustes que afectan codegen.
4. `PPUThread.cpp` (~5600): `jit_compiler::check(cache_path + obj_name)` comprueba objeto existente. Si pasa, evita generar una nueva unidad de compilación para ese objeto. En modo `check_only`, si falta objeto válido, reporta necesidad de compilación.
5. `PPUThread.cpp`, `ppu_initialize2()` (~5980): construye módulo LLVM, establece `TargetTriple` y `DataLayout` del compilador y genera funciones traducidas por `PPUTranslator`. Esto muestra que el código objeto está ligado a arquitectura/ABI del destino; **no** asumir compatibilidad directa de un objeto generado para PC con PS5.

## Conclusiones

- Existe caché PPU LLVM de **archivos objeto**, distinta de la caché SPU de programas/instrucciones ya identificada.
- Es factible **investigar** generación adelantada de objetos PPU para **el mismo objetivo de compilación PS5**, siempre que la identidad, configuraciones, toolchain y símbolos sean compatibles; ello requiere validación. No se ha demostrado que un archivo compilado en RPCS3 Windows/Linux normal pueda transferirse.
- Una precompilación en el PC usando *toolchain cruzado de PS5* es hipótesis mucho más adecuada que copiar cachés x86-64 generadas por RPCS3 desktop.
- El marcador `v8-kusa` y ajustes influyen en invalidación. El TODO de ajustes de codegen implica riesgo de reutilización con claves incompletas; no alterar formato ni nombre sin inventario completo.
- Faltan: definición exacta de `jit_compiler::check`, detalles de enlace/carga de objetos, registro de cache hit/miss, y prueba reproducible en 13.42.

## Próximo cambio de código propuesto (aún sin realizar)

Instrumentación optativa para registrar en log, por módulo PPU: identidad/nombre objeto, `cache_hit`, `cache_miss`, tiempo de traducción, tamaño del objeto, CPU/target y causa del rechazo. Cero cambios en semántica de cachés por defecto. Ubicar primero definiciones `jit_compiler::check` y enlace. Después evaluar precompilador *host* que use exactamente el objetivo PS5, no binarios del host.

## Referencias

- `https://github.com/lavavex/rpcs3/blob/ps5/rpcs3/Emu/System.cpp`
- `https://github.com/lavavex/rpcs3/blob/ps5/rpcs3/Emu/Cell/PPUThread.cpp`
- `https://github.com/lavavex/rpcs3/blob/ps5/rpcs3/Emu/Cell/SPUCommonRecompiler.cpp`
