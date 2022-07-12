const std = @import("std");
const net = std.net;
const mem = std.mem;
const fs = std.fs;
const io = std.io;
const print = std.debug.print;


const FILE = 0x01;
const DONE = 0x02;
const LEGACY_MD5_WITH_FILE = 0x03;
const FILE_WITH_MD5 = 0x04;
const PROTOCOL_ERROR = 0xFF;

const server = true;
const port = 3214;
const prefix = "sfn__";
const detect_external_ip = true;
const use_zenity = false;
const send_check_integrity = true;

const FILENAME_LIMIT = 255;
const BUFFER_SIZE = 1 * 1024 * 1024;


fn read_byte(stream: net.Stream) !u8 {
    var buf: [1]u8 = undefined;
    var len = try stream.read(buf[0..1]);
    if (len == 0) std.debug.panic("len = 0", .{});
    return buf[0];
}


fn read_line(stream: net.Stream) ![FILENAME_LIMIT:0]u8 {
    var buf: [FILENAME_LIMIT:0]u8 = undefined;
    var pointer: u64 = 0;

    while(true) {
        var byte = try read_byte(stream);
        if (byte == '\n') {
            buf[pointer] = 0x00;
            // return .{buf, pointer};
            return buf;
        } else {
            buf[pointer] = byte;
            pointer += 1;
        }
    }
}


fn read_buf(stream: net.Stream, buf: []u8) !u64 {
    var len = try stream.read(buf);
    // if (len < buf.len) std.debug.panic("too few bytes\n", .{});
    return len;
}


pub fn use_connection(conn: net.StreamServer.Connection) !void {
    print("// Sending files: not implemented\n", .{});
    var to_send: [1]u8 = .{DONE};
    _ = try conn.stream.write(&to_send);
    print("Local done.\n", .{});

    // TODO: proper cleanup
    defer conn.stream.close();

    while(true) {
        var ftype = try read_byte(conn.stream);
        switch(ftype) {
            DONE => {
                print("Remote done.\n", .{});
                return;
            },
            FILE => {
                var filename = try read_line(conn.stream);
                print("filename = {s}\n", .{&filename});

                var cwd = fs.cwd();
                var f = try cwd.createFileZ(&filename, fs.File.CreateFlags{});
                var fw = f.writer();

                var buf: [8]u8 = undefined;
                _ = try read_buf(conn.stream, &buf);
                print("sizebuf = {any}\n", .{buf});

                var fsize: u64 = @bitCast(u64, buf);
                print("fsize = {}\n", .{fsize});

                // var i: u64 = 0;
                // // print("-----\n", .{});
                // while (i < fsize) : (i += 1) {
                //     var b = try read_byte(conn.stream);
                //     // print("{c}", .{b});
                //     try fw.writeByte(b);
                // }
                // // print("-----\n", .{});

                var transferred: u64 = 0;
                var buffer: [BUFFER_SIZE]u8 = undefined;
                while (transferred < fsize) {
                    var left = fsize - transferred;
                    if (left > BUFFER_SIZE) left = BUFFER_SIZE;

                    var buffer_slice = buffer[0..left];

                    var len = try read_buf(conn.stream, buffer_slice);
                    _ = try fw.write(buffer[0..len]);
                    transferred += len;
                }
            },
            else => {
                print("Unknown ftype: {}\n", .{ftype});
                return;
            },
        }
    }
}


pub fn main() !void {
    print("===============\n", .{});
    print("sfn-zig (alpha)\n", .{});
    print("===============\n", .{});

    if (server) {
        print("Waiting for connection, port {}\n", .{port});

        // const self_addr = try net.Address.resolveIp("127.0.0.1", port);  // TODO: 0.0.0.0
        const self_addr = try net.Address.resolveIp("0.0.0.0", port);  // TODO: 0.0.0.0
        var listener = net.StreamServer.init(.{});
        try (&listener).listen(self_addr);
        defer listener.close();

        // while ((&listener).accept()) |conn| {
        //     std.log.info("Accepted Connection from: {}", .{conn.address});
        //
        //     serveFile(&conn.stream, dir) catch |err| {
        //         if (@errorReturnTrace()) |bt| {
        //             std.log.err("Failed to serve client: {}: {}", .{err, bt});
        //         } else {
        //             std.log.err("Failed to serve client: {}", .{err});
        //         }
        //     };
        //
        //     conn.stream.close();
        // } else |err| {
        //     return err;
        // }

        var conn = try (&listener).accept();
        try use_connection(conn);
    } else {
        print("Running in client mode\n", .{});
        print("Not implemented\n", .{});
    }
}
