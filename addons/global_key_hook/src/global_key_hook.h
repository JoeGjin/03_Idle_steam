#ifndef GLOBAL_KEY_HOOK_H
#define GLOBAL_KEY_HOOK_H

#include <godot_cpp/classes/node.hpp>
#include <atomic>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

using namespace godot;

// 最小 Node：后台全局键盘按下 -> 主线程 emit_signal("any_key_pressed")
class GlobalKeyHook : public Node {
	GDCLASS(GlobalKeyHook, Node);

private:
	static HHOOK s_hook;
	static std::atomic<bool> s_any_key_pressed;

	static LRESULT CALLBACK _keyboard_proc(int nCode, WPARAM wParam, LPARAM lParam);

protected:
	static void _bind_methods();

public:
	GlobalKeyHook();
	~GlobalKeyHook() override;

	void _process(double delta) override;
};

#endif // GLOBAL_KEY_HOOK_H
