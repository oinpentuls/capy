const std = @import("std");
const backend = @import("backend");
const Widget = @import("widget.zig").Widget;

const Stack_Impl = struct {
    peer: backend.Stack,
    childrens: std.ArrayList(Widget),

    pub fn init(childrens: std.ArrayList(Widget)) !Stack_Impl {
        const peer = try backend.Stack.create();
        for (childrens.items) |widget| {
            peer.add(widget.peer);
        }
        return Stack_Impl {
            .peer = peer,
            .childrens = childrens
        };
    }

    pub fn add(self: *Stack_Impl, widget: anytype) !void {
        // self.peer.put(widget.peer, 
        //     try std.math.cast(c_int, x),
        //     try std.math.cast(c_int, y)
        // );
    }
};

const Row_Impl = struct {
    peer: ?backend.Row,
    childrens: std.ArrayList(Widget),
    expand: bool,

    pub fn init(childrens: std.ArrayList(Widget), config: GridConfig) !Row_Impl {
        return Row_Impl {
            .peer = null,
            .childrens = childrens,
            .expand = config.expand == .Fill
        };
    }

    pub fn show(self: *Row_Impl) !void {
        if (self.peer == null) {
            var peer = try backend.Row.create();
            peer.expand = self.expand;
            for (self.childrens.items) |widget| {
                // TODO: use comptime vtable to show widgets
                peer.add(widget.peer, widget.container_expanded);
            }
            self.peer = peer;
        }
    }

    pub fn add(self: *Row_Impl, widget: anytype) !void {
        const allocator = self.childrens.allocator;
        const genericWidget = genericWidgetFrom(widget);

        if (self.peer) |*peer| {
            peer.add(genericWidget.peer, genericWidget.container_expanded);
        }

        try self.childrens.append(genericWidget);
    }
};

const Column_Impl = struct {
    peer: ?backend.Column,
    childrens: std.ArrayList(Widget),
    expand: bool,

    pub fn init(childrens: std.ArrayList(Widget), config: GridConfig) !Column_Impl {
        return Column_Impl {
            .peer = null,
            .childrens = childrens,
            .expand = config.expand == .Fill
        };
    }

    pub fn show(self: *Column_Impl) !void {
        if (self.peer == null) {
            var peer = try backend.Column.create();
            peer.expand = self.expand;
            for (self.childrens.items) |widget| {
                // TODO: use comptime vtable to show widgets
                peer.add(widget.peer, widget.container_expanded);
            }
            self.peer = peer;
        }
    }

    pub fn add(self: *Column_Impl, widget: anytype) !void {
        const allocator = self.childrens.allocator;
        const genericWidget = genericWidgetFrom(widget);

        if (self.peer) |*peer| {
            peer.add(genericWidget.peer, genericWidget.container_expanded);
        }

        try self.childrens.append(genericWidget);
    }
};

/// Create a generic Widget struct from the given component.
fn genericWidgetFrom(component: anytype) !Widget {
    const allocator = std.heap.page_allocator; // TODO: custom global allocator for this
    const componentType = @TypeOf(component);
    if (componentType == Widget) return component;

    var cp = if (comptime std.meta.trait.isSingleItemPtr(componentType)) component else blk: {
        var copy = try allocator.create(componentType);
        copy.* = component;
        break :blk copy;
    };
    try cp.show();

    return Widget { .data = @ptrToInt(cp), .peer = cp.peer.?.peer };
}

fn abstractContainerConstructor(comptime T: type, childrens: anytype, config: anytype) !T {
    const allocator = std.heap.page_allocator; // TODO: custom global allocator for this
    const fields = std.meta.fields(@TypeOf(childrens));
    var list = std.ArrayList(Widget).init(allocator);

    inline for (fields) |field| {
        const child = @field(childrens, field.name);
        const widget = try genericWidgetFrom(child);
        try list.append(widget);
    }

    return try T.init(list, config);
} 

const Expand = enum {
    /// The grid should take the minimal size that its childrens want
    No,
    /// The grid should expand to its maximum size by padding non-expanded childrens
    Fill,
};
const GridConfig = struct {
    expand: Expand = .No,
};

/// Set the style of the child to expanded by creating and showing the widget early.
pub fn Expanded(child: anytype) callconv(.Inline) !Widget {
    var widget = try genericWidgetFrom(child);
    widget.container_expanded = true;
    return widget;
}

pub fn Stack(childrens: anytype) callconv(.Inline) !Stack_Impl {
    return try abstractContainerConstructor(Stack_Impl, childrens, .{});
}

pub fn Row(config: GridConfig, childrens: anytype) callconv(.Inline) !Row_Impl {
    return try abstractContainerConstructor(Row_Impl, childrens, config);
}

pub fn Column(config: GridConfig, childrens: anytype) callconv(.Inline) !Column_Impl {
    return try abstractContainerConstructor(Column_Impl, childrens, config);
}