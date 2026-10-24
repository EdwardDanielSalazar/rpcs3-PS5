#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$root/src/rpcs3" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])/'rpcs3/Emu/RSX/Overlays/HomeMenu'
h=root/'overlay_home_menu_settings.h'
c=root/'overlay_home_menu_settings.cpp'
hs=h.read_text(); cs=c.read_text()
marker='PS5_EXTENDED_SETTINGS_V1'
if marker in hs and marker in cs:
    print('Extended PS5 settings already patched');sys.exit(0)
if 'PS5_BOOT_SETTINGS_V1' not in hs or 'PS5_BOOT_SETTINGS_V1' not in cs:
    raise SystemExit('Requires first-stage boot settings patch')
old='\t\tstruct home_menu_settings_audio : public home_menu_settings_page'
if hs.count(old)!=1:raise SystemExit('header anchor not unique')
hs=hs.replace(old,'''\t\t// PS5_EXTENDED_SETTINGS_V1: additional cold-start controls.
		struct home_menu_settings_ps5_extended_0 : public home_menu_settings_page
		{
			home_menu_settings_ps5_extended_0(s16 x, s16 y, u16 width, u16 height, bool use_separators, home_menu_page* parent);
		};

		struct home_menu_settings_ps5_extended_1 : public home_menu_settings_page
		{
			home_menu_settings_ps5_extended_1(s16 x, s16 y, u16 width, u16 height, bool use_separators, home_menu_page* parent);
		};

		struct home_menu_settings_ps5_extended_2 : public home_menu_settings_page
		{
			home_menu_settings_ps5_extended_2(s16 x, s16 y, u16 width, u16 height, bool use_separators, home_menu_page* parent);
		};

		struct home_menu_settings_ps5_extended_3 : public home_menu_settings_page
		{
			home_menu_settings_ps5_extended_3(s16 x, s16 y, u16 width, u16 height, bool use_separators, home_menu_page* parent);
		};

'''+old)
old='\t\thome_menu_settings_audio::home_menu_settings_audio('
if cs.count(old)!=1:raise SystemExit('source ctor anchor not unique')
cs=cs.replace(old,'''// PS5_EXTENDED_SETTINGS_V1
		home_menu_settings_ps5_extended_0::home_menu_settings_ps5_extended_0(s16 x, s16 y, u16 width, u16 height, bool use_separators, home_menu_page* parent)
			: home_menu_settings_page(x, y, width, height, use_separators, parent, "CPU / PPU (restart game)")
		{
			add_dropdown(&g_cfg.core.ppu_decoder, "PPU Decoder");
			add_dropdown(&g_cfg.core.thread_scheduler, "Thread Scheduler Mode");
			add_checkbox(&g_cfg.core.llvm_precompilation, "LLVM Precompilation");
			add_checkbox(&g_cfg.core.set_daz_and_ftz, "Set DAZ and FTZ");
			add_checkbox(&g_cfg.core.ppu_fix_vnan, "PPU Vector NaN Handling");
			add_checkbox(&g_cfg.core.use_accurate_dfma, "Use Accurate DFMA");
			add_checkbox(&g_cfg.core.ppu_set_sat_bit, "PPU Set Saturation Bit");
			add_checkbox(&g_cfg.core.ppu_use_nj_bit, "PPU Accurate Non-Java Mode");
			add_checkbox(&g_cfg.core.ppu_set_vnan, "PPU Accurate Vector NaN Values");
			add_checkbox(&g_cfg.core.ppu_set_fpcc, "PPU Set FPCC Bits");
			add_checkbox(&g_cfg.core.ppu_reservation_priority_over_spu, "PPU Reservation Priority Over SPUs");
			add_checkbox(&g_cfg.core.hle_lwmutex, "HLE lwmutex");
			add_checkbox(&g_cfg.core.allow_rsx_cpu_preempt, "Allow RSX CPU Preemptions");
			add_dropdown(&g_cfg.core.sleep_timers_accuracy, "Sleep Timers Accuracy");
			apply_layout();
		}

		home_menu_settings_ps5_extended_1::home_menu_settings_ps5_extended_1(s16 x, s16 y, u16 width, u16 height, bool use_separators, home_menu_page* parent)
			: home_menu_settings_page(x, y, width, height, use_separators, parent, "SPU / Sync (restart game)")
		{
			add_dropdown(&g_cfg.core.spu_decoder, "SPU Decoder");
			add_dropdown(&g_cfg.core.spu_block_size, "SPU Block Size");
			add_checkbox(&g_cfg.core.spu_loop_detection, "SPU loop detection");
			add_checkbox(&g_cfg.core.spu_accurate_dma, "Accurate SPU DMA");
			add_checkbox(&g_cfg.core.spu_accurate_reservations, "Accurate SPU Reservations");
			add_checkbox(&g_cfg.core.accurate_cache_line_stores, "Accurate Cache Line Stores");
			add_checkbox(&g_cfg.core.spu_verification, "SPU Verification");
			add_checkbox(&g_cfg.core.precise_spu_verification, "Precise SPU Verification");
			add_checkbox(&g_cfg.core.spu_cache, "SPU Cache");
			add_checkbox(&g_cfg.core.spu_reservation_busy_waiting_enabled, "SPU Reservation Busy Waiting Enabled");
			add_checkbox(&g_cfg.core.spu_getllar_spin_optimization_disabled, "Disable SPU GETLLAR Spin Optimization");
			add_checkbox(&g_cfg.core.mfc_shuffling_in_steps, "MFC Shuffling In Steps");
			add_dropdown(&g_cfg.core.spu_xfloat_accuracy, "SPU XFloat Accuracy");
			add_dropdown(&g_cfg.core.rsx_fifo_accuracy, "RSX FIFO Fetch Accuracy");
			add_checkbox(&g_cfg.core.rsx_accurate_res_access, "Accurate RSX reservation access");
			apply_layout();
		}

		home_menu_settings_ps5_extended_2::home_menu_settings_ps5_extended_2(s16 x, s16 y, u16 width, u16 height, bool use_separators, home_menu_page* parent)
			: home_menu_settings_page(x, y, width, height, use_separators, parent, "GPU / RSX (restart game)")
		{
			add_dropdown(&g_cfg.video.antialiasing_level, "MSAA");
			add_dropdown(&g_cfg.video.shadermode, "Shader Mode");
			add_dropdown(&g_cfg.video.shader_precision, "Shader Precision");
			add_dropdown(&g_cfg.video.fb_aliasing_bias, "Framebuffer Aliasing Heuristic Bias");
			add_checkbox(&g_cfg.video.write_color_buffers, "Write Color Buffers");
			add_checkbox(&g_cfg.video.write_depth_buffer, "Write Depth Buffer");
			add_checkbox(&g_cfg.video.read_color_buffers, "Read Color Buffers");
			add_checkbox(&g_cfg.video.read_depth_buffer, "Read Depth Buffer");
			add_checkbox(&g_cfg.video.force_high_precision_z_buffer, "Force High Precision Z buffer");
			add_checkbox(&g_cfg.video.strict_rendering_mode, "Strict Rendering Mode");
			add_checkbox(&g_cfg.video.disable_zcull_queries, "Disable ZCull Occlusion Queries");
			add_checkbox(&g_cfg.video.disable_vertex_cache, "Disable Vertex Cache");
			add_checkbox(&g_cfg.video.disable_FIFO_reordering, "Disable FIFO Reordering");
			add_checkbox(&g_cfg.video.emulate_depth_compare, "Emulate Special Depth Comparison");
			add_checkbox(&g_cfg.video.strict_texture_flushing, "Strict Texture Flushing");
			add_checkbox(&g_cfg.video.multithreaded_rsx, "Multithreaded RSX");
			add_checkbox(&g_cfg.video.relaxed_zcull_sync, "Relaxed ZCULL Sync");
			add_checkbox(&g_cfg.video.precise_zpass_count, "Accurate ZCULL stats");
			add_checkbox(&g_cfg.video.host_label_synchronization, "Allow Host GPU Labels");
			add_checkbox(&g_cfg.video.disable_on_disk_shader_cache, "Disable On-Disk Shader Cache");
			add_checkbox(&g_cfg.video.disable_vulkan_mem_allocator, "Disable Vulkan Memory Allocator");
			add_checkbox(&g_cfg.video.disable_async_host_memory_manager, "Disable Asynchronous Memory Manager");
			add_checkbox(&g_cfg.video.force_hw_MSAA_resolve, "Force Hardware MSAA Resolve");
			add_checkbox(&g_cfg.video.use_gpu_texture_scaling, "Use GPU texture scaling");
			add_checkbox(&g_cfg.video.disable_hardware_blending, "Disable Hardware Blending");
			add_checkbox(&g_cfg.video.disable_hardware_texel_remapping, "Disable Hardware ColorSpace Remapping");
			apply_layout();
		}

		home_menu_settings_ps5_extended_3::home_menu_settings_ps5_extended_3(s16 x, s16 y, u16 width, u16 height, bool use_separators, home_menu_page* parent)
			: home_menu_settings_page(x, y, width, height, use_separators, parent, "Vulkan / I-O (restart game)")
		{
			add_checkbox(&g_cfg.video.vk.asynchronous_texture_streaming, "Asynchronous Texture Streaming");
			add_dropdown(&g_cfg.video.vk.asynchronous_scheduler, "Asynchronous Queue Scheduler");
			add_checkbox(&g_cfg.video.vk.use_rebar_upload_heap, "Use Re-BAR for GPU uploads");
			add_checkbox(&g_cfg.vfs.emulate_hdd_speed, "Emulate HDD Read Speed");
			add_checkbox(&g_cfg.vfs.emulate_bdvd_speed, "Emulate BD-ROM Read Speed");
			add_checkbox(&g_cfg.vfs.limit_cache_size, "Limit disk cache size");
			add_checkbox(&g_cfg.vfs.empty_hdd0_tmp, "Empty dev_hdd0/tmp");
			add_checkbox(&g_cfg.vfs.init_dirs, "Initialize Directories");
			add_checkbox(&g_cfg.video.log_programs, "Log shader programs");
			add_checkbox(&g_cfg.video.debug_output, "Debug output");
			add_checkbox(&g_cfg.video.debug_program_analyser, "Debug Program Analyser");
			add_checkbox(&g_cfg.video.renderdoc_compatiblity, "Renderdoc Compatibility Mode");
			add_checkbox(&g_cfg.core.spu_debug, "SPU Debug");
			add_checkbox(&g_cfg.core.ppu_debug, "PPU Debug");
			add_checkbox(&g_cfg.core.mfc_debug, "MFC Debug");
			add_checkbox(&g_cfg.core.ppu_call_history, "PPU Calling History");
			add_checkbox(&g_cfg.core.llvm_logs, "Save LLVM logs");
			add_checkbox(&g_cfg.core.spu_prof, "SPU Profiler");
			add_checkbox(&g_cfg.core.ppu_prof, "PPU Profiler");
			add_checkbox(&g_cfg.core.perf_report, "Enable Performance Report");
			apply_layout();
		}


'''+old)
old='''\t\t\t\tadd_page(home_menu::fa_icon::settings, std::make_shared<home_menu_settings_ps5_boot>(x, y, width, height, use_separators, nullptr));'''
if cs.count(old)!=1:raise SystemExit('boot page anchor not unique')
cs=cs.replace(old,old+'''
				add_page(home_menu::fa_icon::settings, std::make_shared<home_menu_settings_ps5_extended_0>(x, y, width, height, use_separators, nullptr));
				add_page(home_menu::fa_icon::settings, std::make_shared<home_menu_settings_ps5_extended_1>(x, y, width, height, use_separators, nullptr));
				add_page(home_menu::fa_icon::settings, std::make_shared<home_menu_settings_ps5_extended_2>(x, y, width, height, use_separators, nullptr));
				add_page(home_menu::fa_icon::settings, std::make_shared<home_menu_settings_ps5_extended_3>(x, y, width, height, use_separators, nullptr));''')
h.write_text(hs);c.write_text(cs)
print('Extended PS5 preboot: 75 additional settings in 4 tabs')
PY
