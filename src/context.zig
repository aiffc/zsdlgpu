const std = @import("std");
const Allocator = std.mem.Allocator;
pub const c = @import("c.zig").c;

pub const WindowFlags = struct {
    fullscreen: bool = false,
    opengl: bool = false,
    occluded: bool = false,
    hidden: bool = false,
    borderless : bool = false,
    resizable: bool = false,
    minimized: bool = false,
    maximized: bool = false,
    mousegrabbed: bool = false,
    inputfocus: bool = false,
    mousefocus: bool = false,
    external: bool = false,
    modal: bool = false,
    highpixeldensity: bool = false,
    mousecapture: bool = false,
    mouserelativemode: bool = false,
    alwaysontop: bool = false,
    utility: bool = false,
    tooltip: bool = false,
    popupmenu: bool = false,
    keyboardgrabbed: bool = false,
    vulkan: bool = false,
    metal: bool = false,
    transparent: bool = false,
    notfocusable: bool = false,

    pub fn calc(self: @This()) u64 {
        var ret: u64 = 0;

        if ( self.fullscreen) {ret |= 0x1;}
        if ( self.opengl) {ret |= 0x2;}
        if ( self.occluded) {ret |= 0x4;}
        if ( self.hidden) {ret |= 0x8;}
        if ( self.borderless ) {ret |= 0x10;}
        if ( self.resizable) {ret |= 0x20;}
        if ( self.minimized) {ret |= 0x40;}
        if ( self.maximized) {ret |= 0x80;}
        if ( self.mousegrabbed) {ret |= 0x100;}
        if ( self.inputfocus) {ret |= 0x200;}
        if ( self.mousefocus) {ret |= 0x400;}
        if ( self.external) {ret |= 0x800;}
        if ( self.modal) {ret |= 0x1000;}
        if ( self.highpixeldensity) {ret |= 0x2000;}
        if ( self.mousecapture) {ret |= 0x4000;}
        if ( self.mouserelativemode) {ret |= 0x8000;}
        if ( self.alwaysontop) {ret |= 0x10000;}
        if ( self.utility) {ret |= 0x20000;}
        if ( self.tooltip) {ret |= 0x40000;}
        if ( self.popupmenu) {ret |= 0x80000;}
        if ( self.keyboardgrabbed) {ret |= 0x100000;}
        if ( self.vulkan) {ret |= 0x10000000;}
        if ( self.metal) {ret |= 0x20000000;}
        if ( self.transparent) {ret |= 0x40000000;}
        if ( self.notfocusable) {ret |= 0x80000000;}

        return ret;
    }
};

pub const ShaderFormat = struct {
    invalid: bool = false,
    private: bool = false,
    spirv: bool = true,
    dxbc: bool = false,
    dxil: bool = false,
    msl: bool = false,
    metallib: bool = false,

    pub fn calc(self: @This()) u32 {
        var ret: u32 = 0;

        if ( self.invalid) {ret |= 0x0;}
        if ( self.private) {ret |= 0x1;}
        if ( self.spirv) {ret |= 0x2;}
        if ( self.dxbc) {ret |= 0x4;}
        if ( self.dxil ) {ret |= 0x8;}
        if ( self.msl) {ret |= 0x10;}
        if ( self.metallib) {ret |= 0x20;}

        return ret;
    }

    pub fn getFormat(self: @This()) !c.SDL_GPUShaderFormat {
        if ( self.invalid) { return error.InvalidShaderFormat;}
        if ( self.private) {return error.UnSupport;}
        if ( self.spirv) { return c.SDL_GPU_SHADERFORMAT_SPIRV;}
        if ( self.dxbc) { return error.UnSupport;}
        if ( self.dxil ) { return c.SDL_GPU_SHADERFORMAT_DXIL;}
        if ( self.msl) { return c.SDL_GPU_SHADERFORMAT_MSL;}
        if ( self.metallib) { return error.UnSupport;}
        return error.InvalidShaderFormat;
    }
};

pub const Context = struct {
    const Self = @This();

    shaderFormat: ShaderFormat,
    allocator: Allocator,
    window: *c.SDL_Window,
    gpu: *c.SDL_GPUDevice,

    pub fn initPtr(
        allocator: Allocator,
        api: ?[:0]const u8,
        title: [:0] const u8,
        width: u32,
        height: u32,
        flags: WindowFlags,
        shader_format: ShaderFormat
    ) !*Self {
        var ret = try allocator.create(Self);
        ret.allocator = allocator;
        ret.shaderFormat = shader_format;

        if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS)) {
            std.log.err("{s}", .{c.SDL_GetError()});
            return error.FailedInitSDL;
        }
        const a: WindowFlags = .{};
        _ = a.calc();
        var found: bool = false;
        if (api) |an| {
            const gpu_number: usize = @intCast(c.SDL_GetNumGPUDrivers());
            for (0..gpu_number) |i| {
                const api_name = std.mem.span(c.SDL_GetGPUDriver(@intCast(i)));
                if (std.mem.eql(u8, an, api_name)) {
                    found = true;
                    break;
                }
            }
        }

        const gpup = c.SDL_CreateGPUDevice(@intCast(shader_format.calc()),
		                                       true,
		                                       if(found) api.? else null,);
        if (gpup) |gpu| {
            ret.gpu = gpu;
        } else {
            std.log.err("{s}", .{c.SDL_GetError()});
            return error.FailedToCreateGPU;
        }

        const windowp = c.SDL_CreateWindow(title, @intCast(width), @intCast(height), @intCast(flags.calc()));
        if (windowp) |window| {
            ret.window = window;
        } else {
            std.log.err("{s}", .{c.SDL_GetError()});
            return error.FailedToCreateWindow;
        }

        if (!c.SDL_ClaimWindowForGPUDevice(ret.gpu, ret.window)) {
            std.log.err("{s}", .{c.SDL_GetError()});
            return error.FailedToClaimWindowForGPU;
        }
        return ret;
    }

    pub fn deinitPtr(self: *Self) void {
        c.SDL_ReleaseWindowFromGPUDevice(self.gpu, self.window);
        c.SDL_DestroyGPUDevice(self.gpu);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
        self.allocator.destroy(self);
    }

    pub fn destroyGpipeline(
        self: *Self,
        p: *c.SDL_GPUGraphicsPipeline
    ) void {
        c.SDL_ReleaseGPUGraphicsPipeline(self.gpu, p);
    }

    pub fn createGPipeline(
        self: *Self,
        vshader: *c.SDL_GPUShader,
        fshader: *c.SDL_GPUShader,
    ) !*c.SDL_GPUGraphicsPipeline {
        const desc: c.SDL_GPUColorTargetDescription = .{
            .blend_state = .{
                .alpha_blend_op = c.SDL_GPU_BLENDOP_ADD,
                .color_blend_op = c.SDL_GPU_BLENDOP_ADD,
                .color_write_mask = c.SDL_GPU_COLORCOMPONENT_A | c.SDL_GPU_COLORCOMPONENT_R |
                    c.SDL_GPU_COLORCOMPONENT_G | c.SDL_GPU_COLORCOMPONENT_B,
                .src_alpha_blendfactor = c.SDL_GPU_BLENDFACTOR_ONE,
                .src_color_blendfactor = c.SDL_GPU_BLENDFACTOR_ONE,
                .dst_alpha_blendfactor = c.SDL_GPU_BLENDFACTOR_ZERO,
                .dst_color_blendfactor = c.SDL_GPU_BLENDFACTOR_ZERO,
                .enable_blend = true,
                .enable_color_write_mask = false,
            },
            .format = c.SDL_GetGPUSwapchainTextureFormat(self.gpu, self.window),
        };
        const create_info: c.SDL_GPUGraphicsPipelineCreateInfo = .{
            .vertex_input_state = .{
                .num_vertex_attributes = 0,
                .num_vertex_buffers = 0,
            },
            .primitive_type = c.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .vertex_shader = vshader,
            .fragment_shader = fshader,
            .rasterizer_state = .{
                .cull_mode = c.SDL_GPU_CULLMODE_NONE,
                .fill_mode = c.SDL_GPU_FILLMODE_FILL,
            },
            .multisample_state = .{
                .enable_mask = false,
                .sample_count = c.SDL_GPU_SAMPLECOUNT_1,
            },
            .target_info = .{
                .num_color_targets = 1,
                .has_depth_stencil_target = false,
                .color_target_descriptions = &desc,
            },
        };
        const ppipeline = c.SDL_CreateGPUGraphicsPipeline(self.gpu, &create_info);
        if (ppipeline) |pipeline| {
            self.unloadShader(vshader);
            self.unloadShader(fshader);
            return pipeline;
        } else {
            std.log.err("{s}", .{c.SDL_GetError()});
            return error.FailedToCreateGraphicsPipeline;
        }
    }

    fn unloadShader(
        self: *Self,
        shader: *c.SDL_GPUShader,
    ) void {
        c.SDL_ReleaseGPUShader(self.gpu, shader);
    }

    pub fn loadShader(
        self: *Self,
        shader_stage: enum{Vert, Frag},
        path: [:0]const u8,
        sample_count: u32,
        ubuffer_count: u32,
        storage_buffer_count: u32,
        storage_texture_count: u32,
    ) !*c.SDL_GPUShader{
        const format = try self.shaderFormat.getFormat();

        var code_size: usize = undefined;
        const pcode: ?*anyopaque = c.SDL_LoadFile(path, @ptrCast(&code_size));

        if (pcode) |code| {
            defer c.SDL_free(code);
            const shader_info: c.SDL_GPUShaderCreateInfo = .{
                .code = @as([*]const u8, @ptrCast(code))[0..code_size:0],
                .code_size = @intCast(code_size),
		            .entrypoint = "main",
		            .format = format,
		            .stage = switch (shader_stage) {
                    .Vert => c.SDL_GPU_SHADERSTAGE_VERTEX,
                    .Frag => c.SDL_GPU_SHADERSTAGE_FRAGMENT,
                },
		            .num_samplers = @intCast(sample_count),
		            .num_uniform_buffers = @intCast(ubuffer_count),
		            .num_storage_buffers = @intCast(storage_buffer_count),
		            .num_storage_textures = @intCast(storage_texture_count)
            };
            const pshader = c.SDL_CreateGPUShader(self.gpu, &shader_info);
            if (pshader) |shader| {
                return shader;
            } else {
                std.log.err("{s}", .{c.SDL_GetError()});
                return error.FailedToCreateShader;
            }
        } else {
            std.log.err("{s}", .{c.SDL_GetError()});
            return error.FailedToLoadShader;
        }
    }

    pub fn acquireCmd(self: *Self) !*c.SDL_GPUCommandBuffer {
        const pcmd = c.SDL_AcquireGPUCommandBuffer(self.gpu);
        if (pcmd) |cmd| {
            return cmd;
        } else {
            std.log.err("{s}", .{c.SDL_GetError()});
            return error.FailedToRequireCmd;
        }
    }

    pub fn acquireSwapchain(
        self: *Self,
        cmd: *c.SDL_GPUCommandBuffer,
    ) !*c.SDL_GPUTexture {
        var swapchain: *c.SDL_GPUTexture = undefined;
        var w: u32 = undefined;
        var h: u32 = undefined;
        if (c.SDL_WaitAndAcquireGPUSwapchainTexture(cmd, self.window, @ptrCast(&swapchain), @ptrCast(&w), @ptrCast(&h))) {
            return swapchain;
        } else {
            std.log.err("{s}", .{c.SDL_GetError()});
            return error.FailedToGetSwapchain;
        }
    }

    pub fn beginRenderPass(
        self: *Self,
        cmd: *c.SDL_GPUCommandBuffer,
        texture: *c.SDL_GPUTexture,
    ) !*c.SDL_GPURenderPass {
        _ = self;
        const target_info: c.SDL_GPUColorTargetInfo = .{
            .clear_color = .{
                .r = 0.1,
                .g = 0.1,
                .b = 0.1,
                .a = 0.1,
            },
            .load_op = c.SDL_GPU_LOADOP_CLEAR,
            .mip_level = 0,
            .store_op = c.SDL_GPU_STOREOP_STORE,
            .texture = texture,
            .cycle = true,
            .layer_or_depth_plane = 0,
            .cycle_resolve_texture = false,
        };
        const prender_pass = c.SDL_BeginGPURenderPass(cmd, &target_info, 1, null);
        if (prender_pass) |render_pass| {
            return render_pass;
        } else {
            std.log.err("{s}", .{c.SDL_GetError()});
            return error.FailedToGetRenderPass;
        }
    }

    pub fn endRenderPass (
        self: *Self,
        rp: *c.SDL_GPURenderPass
    ) void {
        _ = self;
        c.SDL_EndGPURenderPass(rp);
    }

    pub fn bindGPipeline(
        self: *Self,
        rp: *c.SDL_GPURenderPass,
        pipeline: *c.SDL_GPUGraphicsPipeline,
    ) void {
        _ = self;
        c.SDL_BindGPUGraphicsPipeline(rp, pipeline);
    }

    pub fn setViewport(
        self: *Self,
        rp: *c.SDL_GPURenderPass,
    ) void {
        _ = self;
        const vp: c.SDL_GPUViewport = .{
            .x = 0,
            .y = 0,
            .w = 1024,
            .h = 1024,
            .min_depth = 0,
            .max_depth = 1,
        };
        c.SDL_SetGPUViewport(rp, &vp);
    }

    pub fn drawPrimitives(
        self: *Self,
        rp: *c.SDL_GPURenderPass,
    ) void {
        _ = self;
        c.SDL_DrawGPUPrimitives(rp, 3, 1, 0, 0);
    }

    pub fn submitCmd(
        self: *Self,
        cmd: *c.SDL_GPUCommandBuffer,
    ) void {
        _ = self;
        if (!c.SDL_SubmitGPUCommandBuffer(cmd)) {
            std.log.warn("failed to submit cmd", .{});
        }
    }
};
