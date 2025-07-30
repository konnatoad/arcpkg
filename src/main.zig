const std = @import("std");

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    var stdout = std.io.getStdOut().writer();

    // Try to get $HOME so we know where to put config
    const home_dir = std.process.getEnvVarOwned(gpa, "$HOME") catch |err| {
        try stdout.print("Failed to read HOME env var: {s}\n", .{@errorName(err)});
        return err;
    };
    errdefer gpa.free(home_dir);

    // Build ~/.config/arcpkg path
    const config_dir = std.fs.path.join(gpa, &.{ home_dir, ".config", "arcpkg" }) catch |err| {
        try stdout.print("Could now build config directory path: {s}\n", .{@errorName(err)});
        return err;
    };
    errdefer gpa.free(config_dir);

    // Make sure that the directory exists
    std.fs.cwd().makePath(config_dir) catch |err| {
        try stdout.print("Could not create config dir: {s}\n", .{@errorName(err)});
        return err;
    };

    // Full path to config.json
    const config_file = std.fs.path.join(gpa, &.{ config_dir, "config.json" }) catch |err| {
        try stdout.print("Could not build config file path: {s}\n", .{@errorName(err)});
        return err;
    };
    errdefer gpa.free(config_file);

    // Try opening config.json - if it doesn't exist, create it fresh
    var file = std.fs.cwd().openFile(config_file, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => blk: {
            var new_file = std.fs.cwd().createFile(config_file, .{}) catch |cerr| {
                try stdout.print("Could not create config.json: {s}\n", .{@errorName(cerr)});
                return cerr;
            };
            errdefer new_file.close();

            // Write starter JSON
            new_file.writeAll(" { \"packages\": [] }\n") catch |werr| {
                try stdout.print("Could not write starter JSON: {s}\n", .{@errorName(werr)});
                return werr;
            };

            break :blk new_file;
        },
        else => {
            try stdout.print("Could not open config.json: {s}\n", .{@errorName(err)});
            return err;
        },
    };
    defer file.close();

    try stdout.print("Welcome to arcpkg! \nYour config lives at: {s}\n", .{config_file});
}
