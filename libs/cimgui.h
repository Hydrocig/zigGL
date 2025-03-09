// libs/cimgui.h
#pragma once
#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h> // For bool type

    // Expose IMGUI_CHECKVERSION
    void ImGuiCheckVersion();

    // Expose ImGui implementation functions
    void ImGuiImplOpenGL3_NewFrame();
    void ImGuiImplGlfw_NewFrame();
    void ImGuiNewFrame();
    void ImGuiRender();
    void ImGuiImplOpenGL3_RenderDrawData();

    // Other functions
    void InitImgui(void* window);
    void Shutdown();

    bool Button(const char* label);
    bool SliderFloat(const char* label, float* v, float v_min, float v_max);

#ifdef __cplusplus
}
#endif