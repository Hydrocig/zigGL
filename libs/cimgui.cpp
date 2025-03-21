#include <iostream>
#include "cimgui.h"
#include "imgui.h"
#include "backends/imgui_impl_glfw.h"
#include "backends/imgui_impl_opengl3.h"

struct GLFWwindow;
struct ImVec2;

const ImVec4 RED = ImVec4(1.0f, 0.0f, 0.0f, 1.0f);
const ImVec4 GREEN = ImVec4(0.0f, 1.0f, 0.0f, 1.0f);

const ImVec2 OUTER_SIZE = ImVec2(0.0f, 0.0f);
const float INNER_WIDTH = 0.0f;

int ImGuiInputTextFlagsEnterReturnsTrue = ImGuiInputTextFlags_::ImGuiInputTextFlags_EnterReturnsTrue;
int ImGuiTableFlagsNone = ImGuiTableFlags_::ImGuiTableFlags_None;

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

void ImGuiBeginGroup() {
    ImGui::BeginGroup();
}

void ImGuiEndGroup() {
    ImGui::EndGroup();
}

bool CollapsingHeader(const char* label, bool* p_visible, ImGuiTreeNodeFlags flags) {
  return ImGui::CollapsingHeader(label, p_visible, flags);
}

bool CollapsingHeaderStatic(const char* label, ImGuiTreeNodeFlags flags) {
  return ImGui::CollapsingHeader(label, flags);
}

bool RadioButton(const char* label, bool active) {
    return ImGui::RadioButton(label, active);
}

bool Checkbox(const char* label, bool* v) {
  return ImGui::Checkbox(label, v);
}

/*
bool ProgressBar(float fraction, const ImVec2& size_arg, const char* overlay){
    ImGui::ProgressBar(fraction, size_arg, overlay);
}
 */

bool InputTextWithHint(const char* label, const char* hint, char* buf, std::size_t buf_size, ImGuiInputTextFlags flags, ImGuiInputTextCallback callback, void* user_data) {
    return ImGui::InputTextWithHint(label, hint, buf, buf_size, flags, callback, user_data);
}

bool InputText(const char* label, char* buf, size_t buf_size, ImGuiInputTextFlags flags, ImGuiInputTextCallback callback, void* user_data) {
    return ImGui::InputText(label, buf, buf_size, flags, callback, user_data);
}

void BulletText(const char* fmt, ...) {
  ImGui::BulletText(fmt);
}

void SameLine(float offset_from_start_x, float spacing) {
  ImGui::SameLine(offset_from_start_x, spacing);
}

void Text(const char* fmt, ...) {
  ImGui::Text(fmt);
}

void TextColoredRGBA(float r, float g, float b, float a, const char* fmt, ...) {
  ImVec4 col = ImVec4(r, g, b, a);
  ImGui::TextColored(col, fmt);
}

bool DragFloat(const char* label, float* v, float v_speed, float v_min, float v_max, const char* format, ImGuiSliderFlags flags){
  return ImGui::DragFloat(label, v, v_speed, v_min, v_max, format, flags);
}

void NewLine() {
  ImGui::NewLine();
}

void Separator(){
  ImGui::Separator();
}

bool BeginTable(const char* str_id, int columns, ImGuiTableFlags flags, const ImVec2* outer_size, float inner_width) {
    return ImGui::BeginTable(str_id, columns, flags, *outer_size, inner_width);
}

bool BeginTable2(const char* str_id, int columns, ImGuiTableFlags flags) {
    return ImGui::BeginTable(str_id, columns, flags, OUTER_SIZE, INNER_WIDTH);
}

void EndTable() {
    ImGui::EndTable();
}

void TableNextRow(ImGuiTableRowFlags row_flags, float min_row_height) {
    ImGui::TableNextRow(row_flags, min_row_height);
}

bool TableNextColumn() {
    return ImGui::TableNextColumn();
}
