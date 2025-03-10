// libs/cimgui.h
#pragma once
#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

    struct GLFWwindow;

    void ImGuiCheckVersion();

    // Expose ImGui implementation functions
    void ImGuiImplOpenGL3_NewFrame();
    void ImGuiImplGlfw_NewFrame();
    void ImGuiNewFrame();
    void ImGuiRender();
    void ImGuiImplOpenGL3_RenderDrawData();

    // Callbacks
    void ImGui_MouseButtonCallback(struct GLFWwindow* window, int button, int action, int mods);
    void ImGui_CursorPosCallback(struct GLFWwindow* window, double x, double y);
    void ImGui_KeyCallback(struct GLFWwindow* window, int key, int scancode, int action, int mods);
    void ImGui_ScrollCallback(struct GLFWwindow* window, double xoffset, double yoffset);

    // Other functions
    void InitImgui(void* window);
    void Shutdown();

    bool Button(const char* label);
    bool SliderFloat(const char* label, float* v, float v_min, float v_max);

#ifdef __cplusplus
}
#endif