#include "cimgui.h"
#include "imgui.h"
#include "backends/imgui_impl_glfw.h"
#include "backends/imgui_impl_opengl3.h"

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