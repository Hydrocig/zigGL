const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;

pub const Vertex = extern struct { position: [3]f32 };
pub const Face = struct { face: [3]usize };

pub const ObjectStruct = struct {
    vbo: std.ArrayList(Vertex),
    ebo: std.ArrayList(Face),
    name: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ObjectStruct) void {
        self.vbo.deinit();
        self.ebo.deinit();
        self.name.deinit();
    }
};

pub fn load(objPath: []const u8, allocator: std.mem.Allocator) !ObjectStruct {
    var obj = ObjectStruct{
        .vbo = std.ArrayList(Vertex).init(allocator),
        .ebo = std.ArrayList(Face).init(allocator),
        .name = std.ArrayList(u8).init(allocator),
        .allocator = allocator,
    };

    try parseObjFile(objPath, &obj);
    return obj;
}

fn parseObjFile(path: []const u8, obj: *ObjectStruct) !void {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();

    var buf_reader = io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var line_buf: [1024]u8 = undefined;

    while (try in_stream.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        try processLine(line, obj);
    }
}

fn processLine(line: []const u8, obj: *ObjectStruct) !void {
    if (line.len == 0) return;

    const prefix = line[0..2];
    const content = if (line.len > 1) line[2..] else "";

    if (mem.eql(u8, prefix, "o ")) {
        try handleObjectName(content, obj);
    } else if (mem.eql(u8, prefix, "v ")) {
        try handleVertex(content, obj);
    } else if (mem.eql(u8, prefix, "f ")) {
        try handleFace(content, obj);
    }
}

fn handleObjectName(content: []const u8, obj: *ObjectStruct) !void {
    obj.name.clearRetainingCapacity();
    try obj.name.appendSlice(content);
}

fn handleVertex(content: []const u8, obj: *ObjectStruct) !void {
    var components = mem.split(u8, content, " ");

    const x_str = components.next() orelse return error.InvalidVertex;
    const y_str = components.next() orelse return error.InvalidVertex;
    const z_str = components.next() orelse return error.InvalidVertex;

    const vertex = Vertex{ .position = .{
        try std.fmt.parseFloat(f32, x_str),
        try std.fmt.parseFloat(f32, y_str),
        try std.fmt.parseFloat(f32, z_str),
    } };

    std.log.debug("VERTEX: {s} {s} {s}", .{ x_str, y_str, z_str });

    try obj.vbo.append(vertex);
}

fn handleFace(content: []const u8, obj: *ObjectStruct) !void {
    var indices: [3]usize = undefined;
    var components = mem.split(u8, content, " ");

    for (&indices) |*index| {
        const component = components.next() orelse return error.InvalidFace;
        var iter = mem.split(u8, component, "/");

        const idx_str = iter.next() orelse return error.InvalidFace;
        index.* = (try std.fmt.parseInt(usize, idx_str, 10)) - 1; // 0-based

        // Skip texture and normal indices
    }

    try obj.ebo.append(Face{ .face = indices });
}
