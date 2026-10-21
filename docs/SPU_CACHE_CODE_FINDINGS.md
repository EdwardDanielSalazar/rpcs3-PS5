# Hallazgo confirmado — caché y precompilación SPU

Fecha: 2026-10-20. Rama: `feature/ps5-13.42-rpcs3`.

## Evidencia del código fuente

Inspección de `lavavex/rpcs3` rama `ps5`:

- `rpcs3/Emu/Cell/SPURecompiler.h` (líneas 15–50) declara `spu_cache`, sus métodos `get()`, `add()`, `initialize(bool build_existing_cache = true)`, y `precompile_funcs`.
- `rpcs3/Emu/Cell/SPUCommonRecompiler.cpp` (líneas 750–837) implementa lectura/escritura de registros de programas SPU y validación CRC16; el registro almacena tamaño, dirección y palabras de instrucciones, **no código máquina x86-64 ya compilado**.
- El método `spu_cache::initialize` (a partir de línea 839) construye el nombre `spu-<block_size>-v1-tane.dat` relativo al directorio de caché PPU proporcionado por `rpcs3::cache::get_ppu_cache()`. Existe un override DEBUG opcional.
- Tras leer el archivo, consume `precompile_funcs` y habilita precompilación cuando `func_list.empty() && g_cfg.core.spu_cache && g_cfg.core.llvm_precompilation` (línea ~896). Puede crear varios workers para compilar.
- `rpcs3/Emu/Cell/SPULLVMRecompiler.cpp` (~1694, ~3915–4043) añade bloques compilados a la caché a través de `cache.add(func)`.
- `rpcs3/Emu/cache_utils.cpp` implementa `get_ppu_cache()` y limitación de tamaño de cachés.

## Implicaciones verificadas

1. **Ya hay una ruta real de precompilación SPU**; cualquier mejora debe estudiarla antes de implementar otra.
2. El archivo `spu-...dat` contiene instrucciones/programas con CRC; leerlo no evita necesariamente compilación nativa en un arranque nuevo.
3. La decisión de precompilar depende de la configuración y de si la caché de programas SPU está vacía. No presupone que todos los bloques SPU se conocen por adelantado.
4. No se ha demostrado que las cachés existentes puedan generarse en otro equipo y reutilizarse sin cambios en PS5 13.42.
5. **Pendiente:** ubicar y estudiar la ruta completa de generación/carga/invalidez de cachés PPU y el comportamiento de los workers SPU al terminar.

## Siguiente experimento propuesto (no ejecutado)

- Baseline: compilar port original, arrancar sin juegos en PS5 estándar 13.42, recoger log.
- Confirmar cómo el menú PS5 expone `llvm_precompilation`, `spu_cache` y `spu_decoder`.
- Registrar por título `SPU cache entries read`, `precompile candidates`, `blocks compiled`, `compile duration`, sin modificar el formato persistido.
- Comparar tres arranques controlados, preservando una copia de `/data/rpcs3/`.
- Solo después estudiar un generador externo de caché en formato compatible, con pruebas de integridad y versionado.

## Alcance

Auditoría estática de código, **no** compilación, port ni mejora de rendimiento demostrada. La ruta del archivo es relativa a la caché del título y no debe interpretarse como una ruta absoluta fija de PS5.
