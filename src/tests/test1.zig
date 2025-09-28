const std = @import("std");
const zsdlgpu = @import("zsdlgpu");
const c = zsdlgpu.c;

pub fn main() !void {
    var running: bool = true;
    const allocator = std.heap.page_allocator;

    var ptr = try zsdlgpu.Context.initPtr(allocator, "vulkan", "hahahah", 1024, 1024, .{ .resizable = true }, .{});
    defer ptr.deinitPtr();

    const cwd = std.fs.cwd();
    const path = try cwd.realpathAlloc(allocator, ".");
    defer allocator.free(path);
    const vpath = try std.fmt.allocPrintSentinel(allocator, "{s}/shaders/triangle/vert.spv", .{path}, 0);
    defer allocator.free(vpath);
    const fpath = try std.fmt.allocPrintSentinel(allocator, "{s}/shaders/triangle/frag.spv", .{path}, 0);
    defer allocator.free(fpath);

    const vshader = try ptr.loadShader(.Vert, vpath, 0, 0, 0, 0);
    const fshader = try ptr.loadShader(.Frag, fpath, 0, 0, 0, 0);

    const pipeline = try ptr.createGPipeline("triangle", vshader, fshader);

    while (running) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    running = false;
                    break;
                },
                else => break,
            }
        }

        try ptr.acquireCmd();
        try ptr.acquireSwapchain();
        try ptr.beginRenderPass();
        ptr.bindGPipelineByPipeline(pipeline);
        try ptr.setViewport();
        ptr.drawPrimitives();
        ptr.endRenderPass();
        ptr.submitCmd();
    }
}
