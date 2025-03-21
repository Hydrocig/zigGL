// libs/cimgui.h
#pragma once
#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <float.h>

    extern int ImGuiInputTextFlagsEnterReturnsTrue;
    extern int ImGuiTableFlagsNone;

    struct GLFWwindow;
    struct ImVec2;
    struct ImVec4;
    struct ImGuiInputTextCallbackData;

    typedef int ImGuiTreeNodeFlags;
    typedef int ImGuiInputTextFlags;
    typedef int ImGuiSliderFlags;
    typedef int ImGuiTableRowFlags;
    typedef int ImGuiTableFlags;
    typedef int (*ImGuiInputTextCallback)(struct ImGuiInputTextCallbackData* data);

    void ImGuiCheckVersion();

    // Expose ImGui implementation functions
    void ImGuiImplOpenGL3_NewFrame();
    void ImGuiImplGlfw_NewFrame();
    void ImGuiNewFrame();
    void ImGuiRender();
    void ImGuiImplOpenGL3_RenderDrawData();

    // Layout
    void ImGuiBeginGroup();
    void ImGuiEndGroup();
    bool CollapsingHeader(const char* label, bool* p_visible, ImGuiTreeNodeFlags flags);
    bool CollapsingHeaderStatic(const char* label, ImGuiTreeNodeFlags flags);
    void SameLine(float offset_from_start_x, float spacing);
    void NewLine();
    void Separator();

    // Components
    bool Button(const char* label);
    bool SliderFloat(const char* label, float* v, float v_min, float v_max);
    bool RadioButton(const char* label, bool active);
    bool Checkbox(const char* label, bool* v);
    //bool ProgressBar(float fraction, const struct ImVec2& size_arg = ImVec2(-FLT_MIN, 0), const char* overlay = NULL);
    bool InputTextWithHint(const char* label, const char* hint, char* buf, size_t buf_size, ImGuiInputTextFlags flags, ImGuiInputTextCallback callback, void* user_data);
    bool InputText(const char* label, char* buf, size_t buf_size, ImGuiInputTextFlags flags, ImGuiInputTextCallback callback, void* user_data);
    void BulletText(const char* fmt, ...);
    void Text(const char* fmt, ...);
    void TextColoredRGBA(float r, float g, float b, float a, const char* fmt, ...);
    bool DragFloat(const char* label, float* v, float v_speed, float v_min, float v_max, const char* format, ImGuiSliderFlags flags);
    bool BeginTable(const char* str_id, int columns, ImGuiTableFlags flags, const struct ImVec2* outer_size, float inner_width);
    bool BeginTable2(const char* str_id, int columns, ImGuiTableFlags flags);
    void EndTable();
    void TableNextRow(ImGuiTableRowFlags row_flags, float min_row_height);
    bool TableNextColumn();

    // Callbacks
    void ImGui_MouseButtonCallback(struct GLFWwindow* window, int button, int action, int mods);
    void ImGui_CursorPosCallback(struct GLFWwindow* window, double x, double y);
    void ImGui_KeyCallback(struct GLFWwindow* window, int key, int scancode, int action, int mods);
    void ImGui_ScrollCallback(struct GLFWwindow* window, double xoffset, double yoffset);

    // Other functions
    void InitImgui(void* window);
    void Shutdown();

#ifdef __cplusplus
}
#endif