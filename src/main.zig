const std = @import("std");

// zig day 5000: still missing rust, still getting bullied by spacetime.
// goal: find a config dir without ripping a hole in the space fabric.
// if $XDG_CONFIG_HOME exists: we use it.
// else: we crawl into $HOME/.config like a feral otter and hope nobody notices.

pub fn main() !void {
    const gpa = std.heap.page_allocator; // allocator from the void. it does not judge. much.
    var stdout = std.io.getStdOut().writer(); // where we yell when neutron fuckers strike

    // Try to get $HOME so we know where to put config
    // Try XDG_CONFIG_HOME first
    // (because "standards" exist, allegedly, in this cosmic soup)
    const config_root = std.process.getEnvVarOwned(gpa, "XDG_CONFIG_HOME") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => blk: {
            // XDG_CONFIG_HOME is missing. spacetime shrugs.
            // fallback to HOME/.config, like every linux goblin ever.

            const home_dir = std.process.getEnvVarOwned(gpa, "HOME") catch |h_err| {
                // no HOME either? congratulations, you live in a void pocket dimension.
                try stdout.print("Neither XDG_CONFIG_HOME nor HOME set. Cannot locate config directory.\n", .{});
                return h_err;
            };
            errdefer gpa.free(home_dir); // we borrowed home_dir from the void, so we pay the void back

            // stitch together "$HOME/.config" with cosmic duct tape
            const joined = try std.fs.path.join(gpa, &.{ home_dir, ".config" });
            break :blk joined;
        },
        else => return err, // some other env var horror: propagate the scream
    };
    errdefer gpa.free(config_root); // config_root is owned memory; don't leak it into the galunga realm

    // Build ~/.config/arcpkg path
    // aka: where we put our little neutron nest of JSON
    const config_dir = std.fs.path.join(gpa, &.{ config_root, "arcpkg" }) catch |err| {
        // "Could now build" is a mood. path join failed, fabric of space is tearing.
        try stdout.print("Could now build config directory path: {s}\n", .{@errorName(err)});
        return err;
    };
    errdefer gpa.free(config_dir); // more owned strings, more chances for spacetime to steal our lunch money

    // Make sure that the directory exists
    // (create the noodle bowl before you pour the noodles)
    std.fs.cwd().makePath(config_dir) catch |err| {
        // if this fails, usually perms or we’re writing into a forbidden dimension
        try stdout.print("Could not create config dir: {s}\n", .{@errorName(err)});
        return err;
    };

    // Full path to config.json
    // this is the sacred scroll where packages live and argue with each other
    const config_file = std.fs.path.join(gpa, &.{ config_dir, "config.json" }) catch |err| {
        try stdout.print("Could not build config file path: {s}\n", .{@errorName(err)});
        return err;
    };
    errdefer gpa.free(config_file);

    // Try opening config.json - if it doesn't exist, create it fresh
    // if it does exist, we politely knock instead of kicking the door in (for now)
    var file = std.fs.cwd().openFile(config_file, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => blk: {
            // file doesn't exist, so we birth it into existence via atomic bullshittery

            var new_file = std.fs.cwd().createFile(config_file, .{}) catch |cerr| {
                try stdout.print("Could not create config.json: {s}\n", .{@errorName(cerr)});
                return cerr;
            };
            errdefer new_file.close(); // if anything explodes after this, close the portal

            // Write starter JSON
            // minimal offering so future code has something to chew on
            var buf = std.ArrayList(u8).init(gpa);
            defer buf.deinit(); // buffer is temporary soup container
            const writer = buf.writer();

            // json writer stream: the least offensive way to summon a JSON blob
            var jw = std.json.writeStream(writer, .{});
            try jw.beginObject();
            try jw.objectField("packages");
            try jw.beginArray();
            try jw.endArray();
            try jw.endObject();

            // pour the newborn JSON into the file like it’s holy water
            try new_file.writeAll(buf.items);

            break :blk new_file; // return the file handle to the timeline
        },
        else => {
            // some other failure: permissions, directory missing, filesystem possessed, etc.
            try stdout.print("Could not open config.json: {s}\n", .{@errorName(err)});
            return err;
        },
    };
    defer file.close(); // no matter what happens, shut the hatch behind us

    // friendly greeting so users don't think the otters ate their config
    try stdout.print("Welcome to arcpkg! \nYour config lives at: {s}\n", .{config_file});
}
