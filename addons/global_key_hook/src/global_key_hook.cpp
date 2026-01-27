#include "global_key_hook.h"

#include <godot_cpp/core/class_db.hpp>

HHOOK GlobalKeyHook::s_hook = nullptr;
std::atomic<bool> GlobalKeyHook::s_any_key_pressed(false);

GlobalKeyHook::GlobalKeyHook() {
	if (!s_hook) {
		s_hook = SetWindowsHookExW(
			WH_KEYBOARD_LL,
			_keyboard_proc,
			GetModuleHandleW(nullptr),
			0
		);
	}
	set_process(true);
}

GlobalKeyHook::~GlobalKeyHook() {
	if (s_hook) {
		UnhookWindowsHookEx(s_hook);
		s_hook = nullptr;
	}
}

LRESULT CALLBACK GlobalKeyHook::_keyboard_proc(int nCode, WPARAM wParam, LPARAM lParam) {
	if (nCode == HC_ACTION) {
		if (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN) {
			s_any_key_pressed.store(true, std::memory_order_relaxed);
		}
	}
	return CallNextHookEx(nullptr, nCode, wParam, lParam);
}

void GlobalKeyHook::_process(double /*delta*/) {
	if (s_any_key_pressed.exchange(false, std::memory_order_relaxed)) {
		emit_signal("any_key_pressed");
	}
}

void GlobalKeyHook::_bind_methods() {
	ADD_SIGNAL(MethodInfo("any_key_pressed"));
}
