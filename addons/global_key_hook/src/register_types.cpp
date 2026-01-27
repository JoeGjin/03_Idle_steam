#include "register_types.h"
#include "global_key_hook.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

// godot-cpp 带的 C 接口头（你的 SConstruct 已经把 gdextension 目录加到 include path 了）
#include <gdextension_interface.h>

using namespace godot;

void initialize_global_key_hook_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	ClassDB::register_class<GlobalKeyHook>();
}

void uninitialize_global_key_hook_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {

	GDExtensionBool GDE_EXPORT global_key_hook_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization* r_initialization
	) {
		godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

		init_obj.register_initializer(initialize_global_key_hook_module);
		init_obj.register_terminator(uninitialize_global_key_hook_module);
		init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

		return init_obj.init();
	}

} // extern "C"
