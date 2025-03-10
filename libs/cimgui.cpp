#include "cimgui.h"
#include "imgui.h"
#include "backends/imgui_impl_glfw.h"
#include "backends/imgui_impl_opengl3.h"

struct GLFWwindow;

void InitImgui(void* window) {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui_ImplGlfw_InitForOpenGL((GLFWwindow*)window, true);
    ImGui_ImplOpenGL3_Init("#version 130");
}

void NewFrame() {
    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplGlfw_NewFrame();
    ImGui::NewFrame();
}

void Render() {
    ImGui::Render();
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
}

void Shutdown() {
    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();
}

bool Button(const char* label) {
    return ImGui::Button(label);
}

bool SliderFloat(const char* label, float* v, float v_min, float v_max) {
    return ImGui::SliderFloat(label, v, v_min, v_max);
}

void ImGuiCheckVersion() {
    IMGUI_CHECKVERSION();
}

// Implement ImGui implementation functions
void ImGuiImplOpenGL3_NewFrame() {
    ImGui_ImplOpenGL3_NewFrame();
}

void ImGuiImplGlfw_NewFrame() {
    ImGui_ImplGlfw_NewFrame();
}

void ImGuiNewFrame() {
    ImGui::NewFrame();
}

void ImGuiRender() {
    ImGui::Render();
}

void ImGuiImplOpenGL3_RenderDrawData() {
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
}

void ImGui_MouseButtonCallback(GLFWwindow* window, int button, int action, int mods) {
    ImGui_ImplGlfw_MouseButtonCallback(window, button, action, mods);
}

void ImGui_CursorPosCallback(GLFWwindow* window, double x, double y) {
    ImGui_ImplGlfw_CursorPosCallback(window, x, y);
}

void ImGui_KeyCallback(GLFWwindow* window, int key, int scancode, int action, int mods) {
    ImGui_ImplGlfw_KeyCallback(window, key, scancode, action, mods);
}

void ImGui_ScrollCallback(GLFWwindow* window, double xoffset, double yoffset){
    ImGui_ImplGlfw_ScrollCallback(window, xoffset, yoffset);
}
