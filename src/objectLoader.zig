const std = @import("std");
const fs = @import("std").fs;
const io = @import("std").io;
const slicedStr = @import("slicedString.zig");

const Vertex = extern struct { position: [3]f32 };
const Faces = extern struct { face: [4]i32 };

var objectName: slicedStr.slicedString = undefined;

pub const objectStruct = extern struct { VBO: [*]Vertex, EBO: [*]Faces, vboSize: i32, eboSize: i32, slicedName: slicedStr.slicedString };

pub fn load() !objectStruct {
    const objectPath: []const u8 = "objects/cube.obj";

    const listAllocator = std.heap.page_allocator;
    var vbo = std.ArrayList(Vertex).init(listAllocator);
    var ebo = std.ArrayList(Faces).init(listAllocator);
    defer vbo.deinit();
    defer ebo.deinit();

    // get file content
    try getFileContent(objectPath, &vbo, &ebo);

    // return vbo and ebo
    const returnObject: objectStruct = .{ .VBO = vbo.items.ptr, .EBO = ebo.items.ptr, .vboSize = @intCast(vbo.items.len), .eboSize = @intCast(ebo.items.len), .slicedName = objectName };

    return returnObject;
}

fn getFileContent(objectPath: []const u8, vboList: *std.ArrayList(Vertex), eboList: *std.ArrayList(Faces)) !void {
    var file = try fs.cwd().openFile(objectPath, .{});
    defer file.close();

    var bufReader = io.bufferedReader(file.reader());
    var inStream = bufReader.reader();

    var buf: [1024]u8 = undefined;

    while (inStream.readUntilDelimiterOrEof(&buf, '\n')) |maybeContent| {
        if (maybeContent) |content| {
            try parseFile(content, vboList, eboList);
        } else break;
    } else |err| {
        std.log.err("Read error: {}\n", .{err});
    }
}

fn parseFile(line: []u8, vboList: *std.ArrayList(Vertex), eboList: *std.ArrayList(Faces)) !void {
    // get first letter of line
    const firstLetter: []u8 = line[0..1];
    const lineWithoutLetter: []u8 = line[2..];

    var it = std.mem.split(u8, lineWithoutLetter, " ");

    // ugly if else comparison
    if (std.mem.eql(u8, firstLetter, "#") == true) {
        // # Comment -> ignore
        return;
    } else if (std.mem.eql(u8, firstLetter, "o") == true) {
        // o Object Name
        const objectNameBuffer = try std.heap.page_allocator.alloc(u8, lineWithoutLetter.len);
        std.mem.copyBackwards(u8, objectNameBuffer, lineWithoutLetter);
        objectName.data_ptr = objectNameBuffer.ptr;
        objectName.data_len = lineWithoutLetter.len;
        std.log.info("Loaded Object {s}", .{lineWithoutLetter});
    } else if (std.mem.eql(u8, firstLetter, "v") == true) {
        // v Vertex
        // Split into coordinates
        const xCoordStr: []const u8 = it.next() orelse "";
        const yCoordStr: []const u8 = it.next() orelse "";
        const zCoordStr: []const u8 = it.next() orelse "";

        const xCoord: f32 = try std.fmt.parseFloat(f32, xCoordStr);
        const yCoord: f32 = try std.fmt.parseFloat(f32, yCoordStr);
        const zCoord: f32 = try std.fmt.parseFloat(f32, zCoordStr);

        const newVertex: Vertex = .{ .position = .{ xCoord, yCoord, zCoord } };
        try vboList.append(newVertex);
    } else if (std.mem.eql(u8, firstLetter, "s") == true) {
        // s Smoothing group
        // Ignore for now
        return;
    } else if (std.mem.eql(u8, firstLetter, "f") == true) {
        // f face vertex indices
        // Split into numbers
        const firstStr: []const u8 = it.next() orelse "";
        const secondStr: []const u8 = it.next() orelse "";
        const thirdStr: []const u8 = it.next() orelse "";
        const fourthStr: []const u8 = it.next() orelse "";

        const first: i32 = try std.fmt.parseInt(i32, firstStr, 10);
        const second: i32 = try std.fmt.parseInt(i32, secondStr, 10);
        const third: i32 = try std.fmt.parseInt(i32, thirdStr, 10);
        const fourth: i32 = try std.fmt.parseInt(i32, fourthStr, 10);

        const newFace: Faces = .{ .face = .{ first, second, third, fourth } };
        try eboList.append(newFace);
    } else {
        std.log.err("Malformatted .obj File!", .{});
    }
}
