const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const meta = std.meta;
const testing = std.testing;
const assert = std.debug.assert;

pub const TSVSchemaItem = struct {
    field_name: []const u8 = "",
    parse_to: type = usize,
    parse_fn: @TypeOf(_dummy_parse),
    optional: bool = false,
    default_val: anytype = undefined, // Only applicable if schema.optional == true

    fn _dummy_parse(comptime T: type, _: *T, _: []const u8, _: mem.Allocator) bool {
        return false;
    }
};

// TODO: move to separate file (utils.zig?)
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        Ok: T,
        Err: E,

        const Self = @This();

        pub fn is_ok(self: Self) bool {
            return switch (self) {
                .Ok => true,
                .Err => false,
            };
        }

        pub fn unwrap(self: Self) T {
            return switch (self) {
                .Ok => |o| o,
                .Err => @panic("Attempted to unwrap error"),
            };
        }
    };
}

pub const TSVParseError = struct {
    type: ErrorType,
    context: Context,

    pub const Context = struct {
        lineno: usize,
        field: usize,
    };

    pub const ErrorType = enum {
        MissingField,
        ErrorParsingField,
        OutOfMemory,
    };
};

pub fn parseCharacter(comptime T: type, result: *T, input: []const u8, _: mem.Allocator) bool {
    switch (@typeInfo(T)) {
        .Int => {},
        else => @compileError("Expected int for parsing result type, found '" ++ @typeName(T) ++ "'"),
    }

    if (input[0] != '\'') {
        return false; // ERROR: Invalid character literal
    }

    var found_char = false;
    var utf8 = (std.unicode.Utf8View.init(input) catch {
        return false; // ERROR: Invalid unicode dumbass
    }).iterator();
    _ = utf8.nextCodepointSlice(); // skip beginning quote

    while (utf8.nextCodepointSlice()) |encoded_codepoint| {
        const codepoint = std.unicode.utf8Decode(encoded_codepoint) catch {
            return false; // ERROR: Invalid unicode dumbass
        };
        switch (codepoint) {
            '\'' => {
                if (!found_char) {
                    return false; // ERROR: empty literal
                }

                if (utf8.nextCodepointSlice()) |_| {
                    return false; // ERROR: trailing characters
                }

                return true;
            },
            '\\' => {
                if (found_char) {
                    return false; // ERROR: too many characters
                }

                const encoded_next = utf8.nextCodepointSlice() orelse {
                    return false; // ERROR: incomplete escape sequence
                };
                const next = std.unicode.utf8Decode(encoded_next) catch {
                    return false; // ERROR: Invalid unicode dumbass
                };

                // TODO: \xXX, \uXXXX, \UXXXXXXXX
                const esc: u8 = switch (next) {
                    '\'' => '\'',
                    '\\' => '\\',
                    'n' => '\n',
                    'r' => '\r',
                    'a' => '\x07',
                    '0' => '\x00',
                    't' => '\t',
                    else => return false, // ERROR: invalid escape sequence
                };

                result.* = esc;
                found_char = true;
            },
            else => {
                if (found_char) {
                    return false; // ERROR: too many characters
                }

                result.* = codepoint;
                found_char = true;
            },
        }
    }

    return false; // ERROR: unterminated literal
}

pub fn parseUtf8String(comptime T: type, result: *T, input: []const u8, alloc: mem.Allocator) bool {
    if (T != []u8) {
        @compileError("Expected []u8, found '" ++ @typeName(T) ++ "'");
    }

    if (input[0] != '"') {
        return false; // ERROR: Invalid string
    }

    var tmpbuf = alloc.alloc(u8, input.len) catch return false; // ERROR: OOM
    var buf_i: usize = 0;
    var i: usize = 1; // skip beginning quote

    while (i < input.len) : (i += 1) {
        switch (input[i]) {
            '"' => {
                if (i != (input.len - 1)) {
                    return false; // ERROR: trailing characters
                }

                result.* = alloc.alloc(u8, buf_i) catch return false; // ERROR: OOM
                mem.copy(u8, result.*, tmpbuf[0..buf_i]);
                alloc.free(tmpbuf);

                return true;
            },
            '\\' => {
                i += 1;
                if (i == input.len) {
                    return false; // ERROR: incomplete escape sequence
                }

                // TODO: \xXX, \uXXXX, \UXXXXXXXX
                const esc: u8 = switch (input[i]) {
                    '"' => '"',
                    '\\' => '\\',
                    'n' => '\n',
                    'r' => '\r',
                    'a' => '\x07',
                    '0' => '\x00',
                    't' => '\t',
                    else => return false, // ERROR: invalid escape sequence
                };

                tmpbuf[buf_i] = esc;
                buf_i += 1;
            },
            else => {
                tmpbuf[buf_i] = input[i];
                buf_i += 1;
            },
        }
    }

    return false; // ERROR: unterminated string
}

pub fn parsePrimitive(comptime T: type, result: *T, input: []const u8, alloc: mem.Allocator) bool {
    switch (@typeInfo(T)) {
        .Int => {
            var inp_start: usize = 0;
            var base: u8 = 0;

            if (input.len >= 3) {
                if (mem.eql(u8, input[0..2], "0x")) {
                    base = 16;
                    inp_start = 2;
                } else if (mem.eql(u8, input[0..2], "0o")) {
                    base = 8;
                    inp_start = 2;
                } else if (mem.eql(u8, input[0..2], "0b")) {
                    base = 2;
                    inp_start = 2;
                } else if (mem.eql(u8, input[0..2], "0s")) { // ???
                    base = 12;
                    inp_start = 2;
                }
            }

            result.* = std.fmt.parseInt(T, input[inp_start..], base) catch return false;
        },
        .Float => result.* = std.fmt.parseFloat(T, input) catch return false,
        .Bool => {
            if (mem.eql(u8, input, "yea")) {
                result.* = true;
            } else if (mem.eql(u8, input, "nay")) {
                result.* = false;
            } else return false;
        },
        .Optional => |optional| {
            if (mem.eql(u8, input, "nil")) {
                result.* = null;
            } else {
                var result_buf: optional.child = undefined;
                const r = parsePrimitive(optional.child, &result_buf, input, alloc);
                result.* = result_buf;
                return r;
            }
        },
        .Enum => |enum_info| {
            if (input[0] != '.') return false;

            var found = false;
            inline for (enum_info.fields) |enum_field| {
                if (mem.eql(u8, enum_field.name, input[1..])) {
                    result.* = @intToEnum(T, enum_field.value);
                    found = true;
                    //break; // FIXME: Wait for that bug to be fixed, then uncomment
                }
            }

            if (!found) return false;
        },
        .Union => |union_info| {
            if (union_info.tag_type) |_| {
                var input_split = mem.split(u8, input, "=");
                const input_field1 = input_split.next() orelse return false;
                const input_field2 = input_split.next() orelse return false;

                if (input_field1[0] != '.') return false;

                var found = false;
                inline for (union_info.fields) |union_field| {
                    if (mem.eql(u8, union_field.name, input_field1[1..])) {
                        var value: union_field.field_type = undefined;
                        if (!parsePrimitive(union_field.field_type, &value, input_field2, alloc))
                            return false;
                        result.* = @unionInit(T, union_field.name, value);
                        found = true;
                        //break; // FIXME: Wait for that bug to be fixed, then uncomment
                    }
                }

                if (!found) return false;
            } else {
                @compileError("Cannot parse untagged union type '" ++ @typeName(T) ++ "'");
            }
        },
        else => @compileError("Cannot parse type '" ++ @typeName(T) ++ "'"),
    }

    return true;
}

pub fn parse(
    comptime T: type,
    comptime schema: []const TSVSchemaItem,
    comptime start_val: T,
    input: []const u8,
    alloc: mem.Allocator,
) Result(std.ArrayList(T), TSVParseError) {
    const S = struct {
        pub fn _err(
            errort: TSVParseError.ErrorType,
            lineno: usize,
            field: usize,
        ) Result(std.ArrayList(T), TSVParseError) {
            return .{
                .Err = .{ .type = errort, .context = .{ .lineno = lineno, .field = field } },
            };
        }
    };

    switch (@typeInfo(T)) {
        .Struct => {},
        else => @compileError("Expected struct for parsing result type, found '" ++ @typeName(T) ++ "'"),
    }

    var results = std.ArrayList(T).init(alloc);

    var lines = mem.split(u8, input, "\n");
    var lineno: usize = 0;

    while (lines.next()) |line| {
        lineno += 1;

        var result: T = start_val;

        // ignore blank/comment lines
        if (line.len == 0 or line[0] == '#') {
            continue;
        }

        var input_fields = mem.split(u8, line, "\t");

        inline for (schema) |schema_item, i| {
            var input_field = mem.trim(u8, input_fields.next() orelse "", " ");

            // Handle empty fields
            if (input_field.len == 0 or input_field[0] == '-') {
                if (schema_item.optional) {
                    @field(result, schema_item.field_name) = schema_item.default_val;
                } else {
                    return S._err(.MissingField, lineno, i);
                }
            } else {
                const r = schema_item.parse_fn(
                    schema_item.parse_to,
                    &@field(result, schema_item.field_name),
                    input_field,
                    alloc,
                );
                if (!r) {
                    return S._err(.ErrorParsingField, lineno, i);
                }
            }
        }

        results.append(result) catch return S._err(.OutOfMemory, lineno, 0);
    }

    return .{ .Ok = results };
}
