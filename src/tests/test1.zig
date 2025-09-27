const std = @import("std");
const zsdlgpu = @import("zsdlgpu");
const c = zsdlgpu.c;

pub fn main() !void {
    var running: bool = true;
    const allocator = std.heap.page_allocator;

    var ptr = try zsdlgpu.Context.initPtr(allocator, "vulkan", "hahahah", 1024, 1024, .{.resizable = true}, .{});
    defer ptr.deinitPtr();

    const vshader = try ptr.loadShader(.Vert, "/home/aif/code/zsdlgpu/shaders/triangle/vert.spv", 0, 0, 0, 0);
    const fshader = try ptr.loadShader(.Frag, "/home/aif/code/zsdlgpu/shaders/triangle/frag.spv", 0, 0, 0, 0);
    
    const pipeline  = try ptr.createGPipeline(vshader, fshader);
    defer ptr.destroyGpipeline(pipeline);

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

        const cmd = try ptr.acquireCmd();
        const swapchain_texture = try ptr.acquireSwapchain(cmd);
        const render_pass = try ptr.beginRenderPass(cmd, swapchain_texture);
        ptr.bindGPipeline(render_pass, pipeline);
        ptr.setViewport(render_pass);
        ptr.drawPrimitives(render_pass);
        ptr.endRenderPass(render_pass);
        ptr.submitCmd(cmd);
    }
}

