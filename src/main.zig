const std = @import("std");
const zap = @import("zap");
const c = @cImport(@cInclude("libpq-fe.h"));

var conn: ?*c.PGconn = null;
var routes: std.StringHashMap(zap.HttpRequestFn) = undefined;

fn on_request_check(r: zap.Request) void {
    if (conn == null or c.PQstatus(conn.?) != c.CONNECTION_OK) {
        r.sendBody("Database unavailable") catch return;
        return;
    }

    const res = c.PQexec(conn.?, "SELECT version();");
    defer c.PQclear(res);

    if (c.PQresultStatus(res) != c.PGRES_TUPLES_OK) {
        r.sendBody("Query failed") catch return;
        return;
    }

    r.sendBody(std.mem.span(c.PQgetvalue(res, 0, 0))) catch return;
}

fn dispatch_routes(r: zap.Request) void {
    if (r.path) |the_path| {
        if (routes.get(the_path)) |handler| {
            handler(r);
            return;
        }
    }
    r.sendBody("404 Not Found") catch return;
}

fn setup_routes() !void {
    try routes.put("/check", on_request_check);
}

pub fn main() !void {
    conn = c.PQconnectdb("host=localhost port=54322 user=postgres password=postgres dbname=origami");
    if (conn == null or c.PQstatus(conn.?) != c.CONNECTION_OK) {
        std.debug.print("Database connection failed\n", .{});
        conn = null;
    }

    const allocator = std.heap.page_allocator;
    routes = std.StringHashMap(zap.HttpRequestFn).init(allocator);
    try setup_routes();

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = dispatch_routes,
        .log = true,
    });
    try listener.listen();

    zap.start(.{ .threads = 2, .workers = 2 });

    routes.deinit();
    if (conn) |db_conn| c.PQfinish(db_conn);
}
