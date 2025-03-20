const std = @import("std");
const c = @cImport(@cInclude("libpq-fe.h"));

pub fn main() !void {
    const conninfo = "host=localhost port=54322 user=postgres password=postgres dbname=origami";

    const conn = c.PQconnectdb(conninfo);
    defer c.PQfinish(conn);

    if (c.PQstatus(conn) != c.CONNECTION_OK) {
        std.debug.print("Connection failed: {s}\n", .{c.PQerrorMessage(conn)});
        return error.ConnectionFailed;
    }
    std.debug.print("Connected to PostgreSQL.\n", .{});

    const res = c.PQexec(conn, "SELECT version();");
    defer c.PQclear(res);

    if (c.PQresultStatus(res) != c.PGRES_TUPLES_OK) {
        std.debug.print("Query failed: {s}\n", .{c.PQerrorMessage(conn)});
        return error.QueryFailed;
    }

    std.debug.print("PostgreSQL Version: {s}\n", .{c.PQgetvalue(res, 0, 0)});
}
